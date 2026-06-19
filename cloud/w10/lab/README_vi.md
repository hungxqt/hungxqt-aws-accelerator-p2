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
|   |   |-- tenant-namespaces/   # Khởi tạo tenant namespaces và giới hạn tài nguyên (quotas)
|   |   |-- team-rbac/           # Phân quyền Developer RBAC theo namespace
|   |   |-- network-policies/    # Chính sách cô lập mạng egress cho namespace
|   |   |-- gatekeeper-operator/ # OPA Gatekeeper Operator
|   |   |-- gatekeeper-policies/ # Các ràng buộc/chính sách OPA Gatekeeper
|   |   |-- policy-controller/   # Sigstore Policy Controller
|   |   |-- cosign-policies/     # Chính sách xác thực chữ ký ảnh Cosign
|   |   |-- rbac/                # Phân quyền RBAC mức cluster (SRE/Viewer)
|   |   |-- argo-rollout/        # Argo Rollouts controller wrapper chart
|   |   |-- metrics-server/      # Kubernetes Metrics Server wrapper chart
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

instance_type          = "t4g.small"
node_port              = 30080 # production app
development_node_port  = 30081 # development app
argocd_node_port       = 30443

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

### 1. Tải thông tin đăng nhập lên AWS Secrets Manager
Codebase này sử dụng External Secrets Operator (ESO) để lấy thông tin đăng nhập (GitHub PAT và Alertmanager SMTP password) từ AWS Secrets Manager nhằm tránh việc lưu plaintext trên Git.

1. Đảm bảo thông tin xác thực AWS của bạn đã được cấu hình cục bộ.
2. Chạy helper script để tải secrets lên:
   ```powershell
   .\scripts\upload-secrets-to-aws.ps1
   ```

### 2. Cài đặt Argo CD
Push repository này lên Git, sau đó cài Argo CD vào minikube và apply ApplicationSet:

```powershell
.\argocd\install.ps1 `
  -RepoUrl "https://github.com/YOUR_ORG/YOUR_REPO.git" `
  -TargetRevision "main"
```

Argo CD đồng bộ động các ứng dụng trong stack bằng ApplicationSet. Các đường dẫn ứng dụng chính bao gồm:

```text
# Tài nguyên nền tảng & kiểm soát bảo mật của Tenant
argocd/apps/tenant-namespaces/overlays/production # Khởi tạo cả hai namespace demo-development & demo-production cùng quotas
argocd/apps/team-rbac/overlays/*                  # Cấu hình Developer RBAC cho cả hai môi trường
argocd/apps/network-policies/overlays/*           # Áp dụng cô lập mạng giữa các môi trường
argocd/apps/gatekeeper-policies/overlays/*        # Các chính sách bảo mật OPA Gatekeeper
argocd/apps/cosign-policies/overlays/*            # Các chính sách xác thực Sigstore/Cosign

# Ứng dụng theo môi trường (Production & Development)
argocd/apps/frontend/overlays/production          # Prod Frontend (Canary Rollout, NodePort 30080)
argocd/apps/frontend/overlays/development         # Dev Frontend (Rollout, NodePort 30081)
argocd/apps/backend/overlays/production           # Prod Backend (Canary Rollout + AnalysisTemplate)
argocd/apps/backend/overlays/development          # Dev Backend (Rollout)
argocd/apps/database/overlays/production          # Prod Redis Database (StatefulSet)
argocd/apps/database/overlays/development         # Dev Redis Database

# Các operator & công cụ hệ thống
argocd/apps/prometheus/overlays/production        # Prometheus server (NodePort 39090)
argocd/apps/argo-rollout/overlays/production      # Argo Rollouts controller
argocd/apps/gatekeeper-operator/overlays/production# OPA Gatekeeper operator
argocd/apps/policy-controller/overlays/production  # Sigstore policy-controller
argocd/apps/rbac/overlays/production              # Phân quyền RBAC mức cluster
argocd/apps/metrics-server/overlays/production      # Kubernetes Metrics Server
```

Kiểm tra Argo CD và app:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get pods,svc
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get pods,svc,rollouts
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-development get pods,svc,rollouts
terraform -chdir=infra output -raw argocd_url
terraform -chdir=infra output -raw production_app_url
terraform -chdir=infra output -raw development_app_url
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

