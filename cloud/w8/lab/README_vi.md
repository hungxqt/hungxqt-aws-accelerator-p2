# Demo Terraform AWS kind ALB

[English](README.md)

## Tổng Quan

Repository này dùng Terraform để tạo một demo Kubernetes nhỏ trên AWS:

- `infra/` tạo hạ tầng AWS: VPC, public subnets, EC2, IAM role, security groups, Application Load Balancer, listener, target group và target attachment.
- EC2 được bootstrap bằng `user_data` để cài Docker, kind và kubectl, sau đó tạo một single-node kind cluster local trên EC2.
- EC2 ghi kubeconfig của kind cluster vào AWS Systems Manager Parameter Store dưới dạng `SecureString`.
- `app/` đọc kubeconfig đó và dùng Kubernetes provider để deploy một ứng dụng nhỏ vào kind cluster.
- AWS ALB forward traffic từ Internet vào NodePort trên EC2; Kubernetes Service route traffic đến Pod.

Luồng request:

```text
Internet
  -> AWS Application Load Balancer :80
  -> EC2 public instance :node_port
  -> kind NodePort Service
  -> Pod demo app
```

Đây là demo stack, không phải kiến trúc Kubernetes production.

## Vì Sao Stack Có Hai Phase

Terraform provider configuration phải có giá trị trước khi provider có thể plan hoặc apply resource. Kubernetes provider cần `kubeconfig`, nhưng kubeconfig chỉ tồn tại sau khi EC2 được tạo và cloud-init tạo xong kind cluster.

Vì vậy project dùng hai Terraform root:

- `infra/`: tạo hạ tầng AWS và bootstrap kind.
- `app/`: dùng Kubernetes provider để deploy workload sau khi kubeconfig sẵn sàng.

Wrapper `scripts/deploy.ps1` gom cả hai phase thành một lệnh deploy end-to-end.

## Cấu Trúc Repository

```text
.
|-- infra/
|   |-- main.tf                 # VPC, EC2 kind host, ALB, target group
|   |-- security.tf             # ALB SG và EC2 SG rules
|   |-- iam.tf                  # IAM policy cho EC2 ghi kubeconfig vào SSM
|   |-- templates/
|   |   `-- kind-user-data.sh.tftpl
|   `-- terraform.tfvars.example
|-- app/
|   |-- main.tf                 # Namespace, Deployment, NodePort Service
|   `-- terraform.tfvars.example
|-- scripts/
|   |-- deploy.ps1              # Một lệnh deploy tất cả
|   `-- destroy.ps1             # Destroy app trước, infra sau
|-- generated/                  # Kubeconfig local, git-ignored
`-- modules/
    |-- vpc/                    # Local wrapper module
    |-- ec2-instance/           # Local wrapper module
    `-- alb/                    # Local wrapper module
```

## Providers

- `infra/`
  - `hashicorp/aws`: tạo AWS resources.
  - `hashicorp/http`: detect public IPv4 của operator khi `allowed_kubernetes_api_cidr = null`.
- `app/`
  - `hashicorp/kubernetes`: deploy Kubernetes resources vào kind cluster.

## Yêu Cầu Trước Khi Chạy

Các tool sau cần có trên PATH:

- Terraform
- AWS CLI, đã authenticate vào AWS account đích
- kubectl
- PowerShell

Kiểm tra nhanh:

```powershell
terraform version
aws sts get-caller-identity
kubectl version --client=true
```

## Cấu Hình Tùy Chọn

Copy file example nếu muốn tùy biến:

```powershell
Copy-Item infra\terraform.tfvars.example infra\terraform.tfvars
Copy-Item app\terraform.tfvars.example app\terraform.tfvars
```

Các giá trị thường dùng trong `infra/terraform.tfvars`:

```hcl
aws_region  = "ap-southeast-1"
name_prefix = "hungqt-tf-kind"

# Nên giới hạn về IP của bạn. Nếu null, Terraform tự detect public IPv4 hiện tại.
allowed_kubernetes_api_cidr = null

allowed_http_cidr = "0.0.0.0/0"
instance_type     = "t3.medium"
node_port         = 30080

tags = {
  Environment = "demo"
  Owner       = "hungqt"
}
```

Các giá trị thường dùng trong `app/terraform.tfvars`:

```hcl
namespace       = "demo"
app_name        = "demo-app"
replicas        = 1
container_image = "nginxinc/nginx-unprivileged:1.29-alpine"
```

Không cần set `node_port` trong `app/terraform.tfvars` khi dùng deploy script; script sẽ đọc `node_port` từ output của `infra/` và truyền vào phase `app/`.

## Deploy Tất Cả Bằng Một Lệnh

```powershell
.\scripts\deploy.ps1
```

Script sẽ làm các việc sau:

1. Chạy `terraform -chdir=infra init`.
2. Chạy `terraform -chdir=infra apply -auto-approve`.
3. Đợi EC2 cloud-init tạo kind cluster và publish kubeconfig lên SSM Parameter Store.
4. Đọc SSM `SecureString` và ghi ra `generated/kubeconfig.yaml`.
5. Đợi Kubernetes API reachable.
6. Chạy `terraform -chdir=app init`.
7. Chạy `terraform -chdir=app apply -auto-approve`.
8. Đợi Kubernetes Deployment rollout xong.
9. In ra ALB URL.

Dùng var file cụ thể:

```powershell
.\scripts\deploy.ps1 `
  -InfraVarFile="terraform.tfvars" `
  -AppVarFile="terraform.tfvars"
```

Bỏ qua init sau lần init đầu tiên:

```powershell
.\scripts\deploy.ps1 -SkipInit
```

## Chạy Từng Phase Độc Lập

### Phase 1: Infra

```powershell
terraform -chdir=infra init
terraform -chdir=infra fmt -check
terraform -chdir=infra validate
terraform -chdir=infra plan -out=infra.tfplan
terraform -chdir=infra apply infra.tfplan
```

Đọc output cần cho phase `app/`:

```powershell
$Region = terraform -chdir=infra output -raw aws_region
$Param = terraform -chdir=infra output -raw kubeconfig_ssm_parameter_name
$NodePort = terraform -chdir=infra output -raw node_port
```

Đợi EC2 tạo kubeconfig, sau đó download về local:

```powershell
New-Item -ItemType Directory -Force generated | Out-Null

$Kubeconfig = aws ssm get-parameter `
  --region $Region `
  --name $Param `
  --with-decryption `
  --query "Parameter.Value" `
  --output json | ConvertFrom-Json

[System.IO.File]::WriteAllText(
  (Join-Path (Get-Location) "generated\kubeconfig.yaml"),
  $Kubeconfig,
  [System.Text.UTF8Encoding]::new($false)
)

kubectl --kubeconfig generated\kubeconfig.yaml get nodes
```

### Phase 2: App

```powershell
terraform -chdir=app init
terraform -chdir=app fmt -check
terraform -chdir=app validate

terraform -chdir=app plan -out=app.tfplan `
  -var="kubeconfig_path=../generated/kubeconfig.yaml" `
  -var="node_port=$NodePort"

terraform -chdir=app apply app.tfplan
```

Kiểm tra app:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n demo get pods,svc
kubectl --kubeconfig generated\kubeconfig.yaml -n demo rollout status deployment/demo-app --timeout=5m
terraform -chdir=infra output -raw app_url
```

## Destroy

Dùng script:

```powershell
.\scripts\destroy.ps1
```

Destroy thủ công theo từng phase:

```powershell
$Region = terraform -chdir=infra output -raw aws_region
$Param = terraform -chdir=infra output -raw kubeconfig_ssm_parameter_name
$NodePort = terraform -chdir=infra output -raw node_port

terraform -chdir=app destroy `
  -var="kubeconfig_path=../generated/kubeconfig.yaml" `
  -var="node_port=$NodePort"

aws ssm delete-parameter --region $Region --name $Param
terraform -chdir=infra destroy
```

Thứ tự destroy quan trọng: xóa Kubernetes resources trước, sau đó mới xóa EC2/ALB/VPC.

## Vì Sao Service Là NodePort, Không Phải LoadBalancer

Cluster này là kind chạy bên trong một EC2 instance. Nó không phải EKS và không có AWS cloud controller hoặc AWS Load Balancer Controller. Nếu đổi Kubernetes Service thành `type = "LoadBalancer"`, Kubernetes thường sẽ để `EXTERNAL-IP` ở trạng thái `<pending>`.

Với kind trên EC2, pattern đúng là:

```text
ALB -> EC2 NodePort -> Kubernetes Service -> Pod
```

Nếu cần hành vi `Service type = LoadBalancer` đúng nghĩa, hãy dùng EKS hoặc cài controller phù hợp và thiết kế lại IAM/networking.

## Troubleshooting

Không thấy SSM parameter:

```powershell
$Region = terraform -chdir=infra output -raw aws_region
$Param = terraform -chdir=infra output -raw kubeconfig_ssm_parameter_name
aws ssm get-parameter --region $Region --name $Param --with-decryption
```

Trong AWS Console, hãy chắc chắn bạn đang ở đúng region. Parameter path có dấu slash ở đầu, ví dụ:

```text
/hungqt-tf-kind/kind/kubeconfig
```

Kiểm tra EC2 và SSM Agent:

```powershell
$InstanceId = terraform -chdir=infra output -raw kind_host_instance_id
aws ssm describe-instance-information --region $Region --filters "Key=InstanceIds,Values=$InstanceId"
```

Lấy bootstrap log qua SSM:

```powershell
aws ssm send-command `
  --region $Region `
  --instance-ids $InstanceId `
  --document-name AWS-RunShellScript `
  --parameters 'commands=["cloud-init status --long","tail -n 240 /var/log/kind-bootstrap.log"]'
```

ALB target unhealthy:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n demo get pods,svc
kubectl --kubeconfig generated\kubeconfig.yaml -n demo describe svc demo-app
```

Kiểm tra `node_port` từ `infra/` và `app/` phải trùng nhau.

## Ghi Chú Bảo Mật

- EC2 không mở SSH ingress mặc định.
- ALB cho phép HTTP theo `allowed_http_cidr`.
- EC2 chỉ cho NodePort traffic từ ALB security group.
- Kubernetes API nên được giới hạn về IP operator. Dùng `allowed_kubernetes_api_cidr` để kiểm soát.
- Kubeconfig được lưu trong SSM dưới dạng `SecureString`, và file local `generated/kubeconfig.yaml` đã được git-ignore.
- Không commit `terraform.tfstate`, `.terraform/`, `*.tfplan`, hoặc `generated/kubeconfig.yaml`.
