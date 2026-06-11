# Terraform AWS Minikube Sandbox

[English](README.md)

## Tổng Quan

Repository này tạo một Kubernetes sandbox cá nhân chi phí thấp trên AWS:

- `infra/` tạo một public VPC subnet, một EC2 instance, IAM, và security group rules.
- EC2 instance chạy Docker và minikube.
- EC2 publish kubeconfig đã tạo lên AWS Systems Manager Parameter Store dưới dạng `SecureString`.
- `argocd/` cài Argo CD và chứa app manifests để Argo CD sync.
- Demo app được expose trực tiếp qua public IP của EC2 và Kubernetes NodePort.

Luồng request:

```text
Internet hoặc allowed CIDR
  -> EC2 public IPv4 :node_port
  -> minikube NodePort Service
  -> demo app Pod
```

Terraform chỉ quản lý AWS infrastructure và minikube bootstrap. Argo CD quản lý Kubernetes application delivery.

## Chi Phí

Stack hiện tại tránh các resource thường tạo chi phí lặp lại cao trong một sandbox nhỏ:

- Không NAT Gateway.
- Không Application Load Balancer.
- Không Elastic IP.
- EC2 mặc định là `t4g.small` với CPU credits đặt là `standard`.

Instance và public IPv4 của nó vẫn phát sinh chi phí khi instance đang chạy. Stop instance thủ công hoặc chạy destroy khi không dùng nữa.

## Cấu Trúc Repository

```text
.
|-- infra/
|   |-- main.tf                  # VPC và EC2 minikube host
|   |-- security.tf              # EC2 ingress và egress rules
|   |-- iam.tf                   # IAM policy để publish kubeconfig
|   |-- templates/
|   |   `-- minikube-user-data.sh.tftpl
|   `-- terraform.tfvars.example
|-- argocd/
|   |-- install/                 # Argo CD install overlay và NodePort Service
|   |-- bootstrap/               # Tài nguyên bootstrap Argo CD ApplicationSet
|   |-- apps/                    # Wrappers & ứng dụng được đồng bộ bởi Argo CD
|   |   |-- frontend/            # Frontend Web UI (Rollout canary)
|   |   |-- backend/             # Go REST API backend (Rollout + AnalysisTemplate)
|   |   |-- database/            # Cơ sở dữ liệu Redis
|   |   |-- argo-rollout/        # Argo Rollouts controller wrapper chart
|   |   `-- prometheus/          # Prometheus monitoring wrapper chart
|   |-- install.ps1
|   `-- uninstall.ps1
|-- scripts/
|   |-- deploy.ps1               # Infra bootstrap và kubeconfig fetch
|   |-- destroy.ps1
|   `-- fetch-kube-config.ps1
|-- generated/                   # Local kubeconfig, đã git-ignore
|`-- modules/
    |-- vpc/                     # Local wrapper module
    `-- ec2-instance/            # Local wrapper module
```

## Yêu Cầu

Các công cụ sau cần có trên `PATH`:

- Terraform
- AWS CLI đã xác thực vào AWS account mục tiêu
- kubectl
- PowerShell

Kiểm tra nhanh:

```powershell
terraform version
aws sts get-caller-identity
kubectl version --client=true
```

## Cấu Hình Tùy Chọn

Sao chép file ví dụ của infra nếu bạn muốn tùy chỉnh giá trị:

```powershell
Copy-Item infra\terraform.tfvars.example infra\terraform.tfvars
```

Các giá trị phổ biến trong `infra/terraform.tfvars`:

```hcl
aws_region  = "us-east-1"
name_prefix = "tf-minikube-demo"

# Khi null, Terraform phát hiện public IPv4 hiện tại của bạn và chỉ cho phép /32 đó
# truy cập Kubernetes API. Không dùng 0.0.0.0/0 cho truy cập API.
allowed_kubernetes_api_cidr = null

# Khi null, truy cập app dùng cùng CIDR của operator đã phát hiện.
allowed_app_cidr = null

# Khi null, truy cập Argo CD UI/API dùng CIDR của operator đã phát hiện.
allowed_argocd_cidr = null

instance_type         = "t4g.small"
node_port             = 30080
development_node_port = 30081
argocd_node_port      = 30443

tags = {
  Environment = "demo"
}
```

## Triển Khai Hạ Tầng

```powershell
.\scripts\deploy.ps1
```

Script này:

1. Chạy `terraform -chdir=infra init`.
2. Chạy `terraform -chdir=infra apply -auto-approve`.
3. Đợi EC2 tạo minikube và publish kubeconfig lên SSM.
4. Tải SSM `SecureString` về `generated/kubeconfig.yaml`.
5. Đợi Kubernetes API sẵn sàng.
6. In app URL, Argo CD URL, và kubeconfig path.

Dùng infra var file rõ ràng:

```powershell
.\scripts\deploy.ps1 -InfraVarFile="terraform.tfvars"
```

Bỏ qua init sau lần init thành công đầu tiên:

```powershell
.\scripts\deploy.ps1 -SkipInit
```

## Cài Argo CD Và Sync App

Push repository này lên Git, sau đó cài Argo CD vào minikube và tạo Argo CD `Application`:

```powershell
.\argocd\install.ps1 `
  -RepoUrl "https://github.com/YOUR_ORG/YOUR_REPO.git" `
  -TargetRevision "main"
```

Argo CD đồng bộ các ứng dụng trong stack từ:

```text
argocd/apps/frontend/overlays/production    # Frontend UI (Rollout canary, NodePort 30080)
argocd/apps/backend/overlays/production     # Go Backend (Rollout canary + AnalysisTemplate)
argocd/apps/database/overlays/production    # Redis DB (StatefulSet)
argocd/apps/prometheus/overlays/production  # Prometheus server (NodePort 39090)
argocd/apps/argo-rollout/overlays/production# Argo Rollouts controller
```

Kiểm tra Argo CD và app:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get pods,svc
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get pods,svc,rollouts
terraform -chdir=infra output -raw argocd_url
terraform -chdir=infra output -raw production_app_url
```

Gỡ chỉ Argo CD khỏi remote minikube cluster (giữ lại resources của demo app):

```powershell
.\argocd\uninstall.ps1
```

Chỉ xóa resources của demo app đã sync (giữ lại Argo CD):

```powershell
.\argocd\uninstall.ps1 -DeleteApps
```

## Chạy Infra Thủ Công

```powershell
terraform -chdir=infra init
terraform -chdir=infra fmt -check
terraform -chdir=infra validate
terraform -chdir=infra plan -out=infra.tfplan
terraform -chdir=infra apply infra.tfplan
```

Tải kubeconfig:

```powershell
.\scripts\fetch-kube-config.ps1
kubectl --kubeconfig generated\kubeconfig.yaml get nodes
```

## Thay Đổi Public IP

Stack này không cấp Elastic IP. Nếu bạn stop rồi start EC2 instance, AWS có thể gán public IPv4 khác.

`minikube-bootstrap.service` chạy mỗi lần boot. Nếu service phát hiện public IP mới, nó tạo lại minikube profile để API certificate hợp lệ với địa chỉ mới, rồi publish lại kubeconfig lên SSM. Chạy lại lệnh sau để tải kubeconfig mới:

```powershell
.\scripts\deploy.ps1 -SkipInit
```

Sau khi cluster truy cập được, Argo CD sẽ reconcile app.

## Xóa Hạ Tầng

```powershell
.\scripts\destroy.ps1
```

Xóa thủ công:

```powershell
$Region = terraform -chdir=infra output -raw aws_region
$Param = terraform -chdir=infra output -raw kubeconfig_ssm_parameter_name

aws ssm delete-parameter --region $Region --name $Param
terraform -chdir=infra destroy
```

Destroy infra sẽ xóa EC2 minikube cluster, nên Argo CD và app bên trong cluster cũng bị xóa.

## Xử Lý Sự Cố

Kiểm tra EC2 bootstrap logs qua SSM:

```powershell
$InstanceId = terraform -chdir=infra output -raw instance_id
$Region = terraform -chdir=infra output -raw aws_region

aws ssm send-command `
  --region $Region `
  --instance-ids $InstanceId `
  --document-name AWS-RunShellScript `
  --parameters 'commands=["systemctl status minikube-bootstrap --no-pager","tail -n 240 /var/log/minikube-bootstrap.log"]'
```

Ghi chú bảo mật:

- Kubeconfig được lưu trong SSM dưới dạng `SecureString`.
- `generated/kubeconfig.yaml`, `.terraform/`, `*.tfstate`, `*.tfplan`, và `terraform.tfvars` đã được git-ignore.
- Kubernetes API CIDR và Argo CD CIDR không được là `0.0.0.0/0`.
