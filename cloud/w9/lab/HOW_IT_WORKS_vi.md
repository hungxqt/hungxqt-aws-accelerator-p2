# HOW IT WORKS - Terraform AWS Minikube Sandbox

Tài liệu này giải thích cách repository triển khai hạ tầng, cách EC2 bootstrap minikube, cách kubeconfig được đưa về máy local, và đặc biệt cách Argo CD tiếp quản việc deploy ứng dụng Kubernetes.

Điểm quan trọng nhất của kiến trúc hiện tại:

- Terraform chỉ quản lý AWS infrastructure và bootstrap minikube.
- Argo CD quản lý Kubernetes application delivery.
- Không còn Terraform root `app/`.
- Không còn Terraform-managed `demo` namespace, `Deployment`, hay `Service`.
- Không dùng ALB, không dùng Elastic IP, không dùng Kubernetes `LoadBalancer`.
- Traffic đi trực tiếp vào public IPv4 của EC2 qua NodePort.

## 1. Ownership Boundary

| Phần | Công cụ quản lý | File chính |
| --- | --- | --- |
| AWS infrastructure | Terraform | `infra/` |
| VPC và EC2 module wrapper | Terraform local modules | `modules/vpc/`, `modules/ec2-instance/` |
| EC2 bootstrap và minikube | EC2 user data + systemd | `infra/templates/minikube-user-data.sh.tftpl` |
| Lấy kubeconfig về local | PowerShell + AWS SSM | `scripts/deploy.ps1`, `scripts/fetch-kube-config.ps1` |
| Cài Argo CD | kubectl + Kustomize | `argocd/install.ps1`, `argocd/install/` |
| Kubernetes app | Argo CD | `argocd/bootstrap/apps-applicationset.yaml`, `argocd/apps/frontend/`, `argocd/apps/backend/`, etc. |
| Gỡ Argo CD | kubectl | `argocd/uninstall.ps1` |
| Destroy AWS infra | Terraform | `scripts/destroy.ps1` |

Ranh giới này giúp repo tránh việc Terraform phải quản lý Kubernetes resources khi Kubernetes API chưa tồn tại ở thời điểm `terraform apply` bắt đầu. Terraform tạo remote minikube cluster trước. Sau đó Argo CD được cài vào cluster và bắt đầu sync app từ Git.

## 2. Sơ Đồ Kiến Trúc Tổng Thể

```mermaid
flowchart LR
  Operator["Máy local của operator<br/>PowerShell, Terraform, AWS CLI, kubectl"]
  Deploy["scripts/deploy.ps1"]
  TF["Terraform root: infra/"]
  AWS["AWS resources<br/>VPC, subnet, SG, IAM, EC2"]
  EC2["EC2 public instance<br/>Docker + minikube"]
  Bootstrap["minikube-bootstrap.service<br/>tạo cluster, publish kubeconfig"]
  SSM["SSM Parameter Store<br/>SecureString kubeconfig"]
  Kubeconfig["generated/kubeconfig.yaml"]
  ArgoInstall["argocd/install.ps1"]
  Argo["Argo CD namespace<br/>controller, repo-server, server"]
  AppCR["Argo CD Application<br/>frontend & backend"]
  Git["Git repository<br/>argocd/apps/"]
  Demo["demo-production namespace<br/>Rollout + StatefulSet + Service"]

  Operator --> Deploy
  Deploy --> TF
  TF --> AWS
  AWS --> EC2
  EC2 --> Bootstrap
  Bootstrap --> SSM
  Deploy --> SSM
  SSM --> Kubeconfig
  Operator --> ArgoInstall
  ArgoInstall --> Kubeconfig
  ArgoInstall --> Argo
  ArgoInstall --> AppCR
  AppCR --> Argo
  Argo --> Git
  Git --> Argo
  Argo --> Demo
```

Luồng trên chia thành hai pha:

1. `scripts/deploy.ps1` triển khai AWS infra, đợi EC2 bootstrap minikube, lấy kubeconfig từ SSM về `generated/kubeconfig.yaml`.
2. `argocd/install.ps1` dùng kubeconfig đó để cài Argo CD và tạo Argo CD `Application`.

Đây là lý do Argo CD không nằm trong Terraform apply flow. Terraform không cần Kubernetes provider để tạo app. Sau khi cluster tồn tại, Argo CD mới chịu trách nhiệm sync Kubernetes resources.

## 3. Sơ Đồ Traffic

Stack hiện tại expose app và Argo CD bằng NodePort trên EC2 public IP.

```mermaid
flowchart TB
  UserApp["Người dùng demo app"]
  UserArgo["Operator truy cập Argo CD"]
  PublicIP["EC2 public IPv4"]
  Port30080["Host port 30080<br/>var.node_port"]
  Port30081["Host port 30081<br/>var.development_node_port"]
  Port30443["Host port 30443<br/>var.argocd_node_port"]
  PortMap["minikube Docker driver<br/>--ports mapping"]
  ProdAppSvc["Production frontend Service<br/>type NodePort, nodePort 30080"]
  DevAppSvc["Development frontend Service<br/>type NodePort, nodePort 30081"]
  AppPod["Pod frontend/backend<br/>containerPort 80/5000"]
  ArgoSvc["Service argocd-server-nodeport<br/>type NodePort, nodePort 30443"]
  ArgoServer["argocd-server<br/>targetPort 8080"]

  UserApp -->|"http://EC2_PUBLIC_IP:30080 hoặc :30081"| PublicIP
  UserArgo -->|"https://EC2_PUBLIC_IP:30443"| PublicIP
  PublicIP --> Port30080
  PublicIP --> Port30081
  PublicIP --> Port30443
  Port30080 --> PortMap
  Port30081 --> PortMap
  Port30443 --> PortMap
  PortMap --> ProdAppSvc
  PortMap --> DevAppSvc
  ProdAppSvc --> AppPod
  DevAppSvc --> AppPod
  PortMap --> ArgoSvc
  ArgoSvc --> ArgoServer
```

Các port chính:

| Port | Terraform variable | Mục đích | Security group CIDR |
| --- | --- | --- | --- |
| `8443` | `kubernetes_api_port` | Kubernetes API của minikube | `allowed_kubernetes_api_cidr` hoặc operator `/32` |
| `30080` | `node_port` | Production demo app NodePort | `allowed_app_cidr`, `allowed_http_cidr`, hoặc operator `/32` |
| `30081` | `development_node_port` | Development demo app NodePort | `allowed_app_cidr`, `allowed_http_cidr`, hoặc operator `/32` |
| `30443` | `argocd_node_port` | Argo CD UI/API NodePort | `allowed_argocd_cidr` hoặc operator `/32` |

`allowed_kubernetes_api_cidr` và `allowed_argocd_cidr` bị validate để không cho dùng `0.0.0.0/0`. App CIDR có thể mở rộng hơn, nhưng nên cân nhắc vì đây là public NodePort trên EC2.

## 4. Terraform Deploy Infra Như Thế Nào

### 4.1. Terraform root `infra/`

`infra/versions.tf` đặt version floor:

- Terraform `>= 1.5.7, < 2.0`.
- AWS provider `>= 6.37, < 7.0`.
- HTTP provider `>= 3.5, < 4.0`.

`infra/main.tf` tạo hai module:

- `module "vpc"` gọi local wrapper `../modules/vpc`.
- `module "minikube_host"` gọi local wrapper `../modules/ec2-instance`.

Local wrapper `modules/vpc` pin upstream `terraform-aws-modules/vpc/aws` version `6.6.1`.

Local wrapper `modules/ec2-instance` pin upstream `terraform-aws-modules/ec2-instance/aws` version `6.4.0`.

### 4.2. VPC

VPC được cấu hình cho sandbox chi phí thấp:

- CIDR mặc định `10.40.0.0/16`.
- Một public subnet.
- `map_public_ip_on_launch = true`.
- Không NAT Gateway.
- Không Elastic IP.
- Không Application Load Balancer.
- Không private app tier.

EC2 host nằm trong public subnet này và nhận public IPv4 động từ AWS.

### 4.3. EC2 minikube host

EC2 được tạo bởi `module "minikube_host"` với các điểm chính:

- Instance type mặc định `t4g.small`.
- AMI là Amazon Linux 2023, chọn theo architecture của instance type.
- Nếu instance type dạng Graviton như `t4g.small`, AMI architecture là `arm64`.
- Public IP được gán trực tiếp, nhưng không tạo Elastic IP.
- Root EBS volume `gp3`, encrypted, mặc định 30 GiB.
- IMDSv2 bắt buộc với `http_tokens = "required"`.
- `instance_initiated_shutdown_behavior = "stop"`.
- `user_data_replace_on_change = true`.

`user_data_replace_on_change = true` nghĩa là nếu bootstrap template thay đổi, Terraform plan có thể thay EC2 instance. Khi thay EC2, minikube cluster bên trong instance cũng bị tạo lại.

### 4.4. Auto-detect operator CIDR

`infra/locals.tf` dùng HTTP provider gọi:

```text
https://checkip.amazonaws.com
```

Nếu `allowed_kubernetes_api_cidr = null`, Terraform lấy public IPv4 hiện tại của máy chạy Terraform và chuyển thành `/32`.

CIDR này được dùng cho Kubernetes API. App và Argo CD cũng có thể kế thừa CIDR này nếu `allowed_app_cidr` hoặc `allowed_argocd_cidr` là `null`.

Điều này giúp mặc định an toàn hơn so với mở API ra toàn internet. Nhưng nếu public IP của bạn thay đổi, bạn cần apply lại infra để security group cho phép IP mới.

### 4.5. IAM và SSM kubeconfig

EC2 có IAM role gồm:

- `AmazonSSMManagedInstanceCore`, để instance hoạt động với AWS Systems Manager.
- Custom policy `aws_iam_policy.kubeconfig_writer`, cho phép ghi đúng một SSM parameter chứa kubeconfig.
- KMS encrypt permissions bị ràng buộc qua SSM service trong đúng account.

Kubeconfig được lưu trong SSM Parameter Store dạng `SecureString`. Local script tải kubeconfig bằng `aws ssm get-parameter --with-decryption` và ghi vào:

```text
generated/kubeconfig.yaml
```

File này đã được git-ignore.

## 5. EC2 Bootstrap Minikube

Bootstrap nằm ở:

```text
infra/templates/minikube-user-data.sh.tftpl
```

Đây là custom component quan trọng nhất của infra. Terraform render template này thành EC2 user data và truyền vào các giá trị như:

- AWS region.
- Kubernetes version.
- minikube version.
- kubectl version.
- Kubernetes API port.
- Production app NodePort.
- Development app NodePort.
- Argo CD NodePort.
- SSM parameter name cho kubeconfig.

### 5.1. User data làm gì khi EC2 boot

User data chạy các bước:

1. `dnf update -y`.
2. Cài `awscli-2`, `conntrack-tools`, và `docker`.
3. Enable và start Docker.
4. Tạo Linux user `minikube` nếu chưa có.
5. Thêm user `minikube` vào group `docker`.
6. Detect architecture của EC2: `arm64` hoặc `amd64`.
7. Tải minikube binary theo `minikube_version`.
8. Tải kubectl binary theo `kubectl_version`.
9. Ghi `/etc/minikube-bootstrap/env`.
10. Tạo `/usr/local/sbin/minikube-bootstrap.sh`.
11. Tạo systemd unit `minikube-bootstrap.service`.
12. Enable và start service.

### 5.2. `minikube-bootstrap.service`

Systemd service này chạy bootstrap thật sự và có thể chạy lại sau khi EC2 reboot.

```mermaid
flowchart TD
  Start["minikube-bootstrap.service start"]
  Env["Đọc /etc/minikube-bootstrap/env"]
  IMDS["Lấy EC2 public IPv4 bằng IMDSv2"]
  Compare["So sánh với public IP lần trước"]
  Delete["Nếu IP đổi -> minikube delete profile cũ"]
  Status["Kiểm tra minikube profile"]
  StartMini["Nếu chưa Running -> minikube start"]
  Ready["kubectl wait node Ready"]
  Export["Export kubeconfig raw"]
  Rewrite["Rewrite server thành https://PUBLIC_IP:8443"]
  PutSSM["Put kubeconfig vào SSM SecureString"]
  Done["Ghi public-ip và bootstrap-complete"]

  Start --> Env --> IMDS --> Compare
  Compare --> Delete --> Status
  Compare --> Status
  Status --> StartMini --> Ready
  Status --> Ready
  Ready --> Export --> Rewrite --> PutSSM --> Done
```

Các chi tiết quan trọng:

- Service lấy public IPv4 bằng IMDSv2.
- Nếu public IP thay đổi sau stop/start, service xóa minikube profile cũ và tạo lại. Việc này cần thiết vì Kubernetes API certificate phải chứa public IP mới.
- `minikube start` dùng Docker driver và container runtime `containerd`.
- Minikube listen trên `0.0.0.0`.
- API server dùng port `8443`.
- `--apiserver-ips="$PUBLIC_IPV4"` đưa public IP vào certificate SAN.
- `--ports` map năm port từ minikube Docker container ra EC2 host:
  - `8443:8443` cho Kubernetes API.
  - `30443:30443` cho Argo CD.
  - `30080:30080` cho production demo app.
  - `30081:30081` cho development demo app.
  - `39090:39090` cho Prometheus.
- Kubeconfig raw được rewrite để `server:` trỏ về `https://PUBLIC_IPV4:8443`.
- Kubeconfig public được publish vào SSM `SecureString`.

Bootstrap logs:

```text
/var/log/minikube-user-data.log
/var/log/minikube-bootstrap.log
```

## 6. `scripts/deploy.ps1` Làm Gì

Lệnh deploy:

```powershell
.\scripts\deploy.ps1
```

Script này không cài Argo CD. Nó chỉ deploy AWS infra, đợi minikube sẵn sàng, và lấy kubeconfig về local.

```mermaid
sequenceDiagram
  participant Operator as Operator
  participant Deploy as scripts/deploy.ps1
  participant Terraform as Terraform infra/
  participant EC2 as EC2 user data
  participant SSM as SSM SecureString
  participant Kubectl as kubectl local

  Operator->>Deploy: .\scripts\deploy.ps1
  Deploy->>Terraform: terraform -chdir=infra init
  Deploy->>Terraform: terraform -chdir=infra apply -auto-approve
  Terraform->>EC2: Tạo EC2 với user_data
  EC2->>EC2: Cài Docker, minikube, kubectl
  EC2->>EC2: Start minikube
  EC2->>SSM: Put kubeconfig SecureString
  Deploy->>Terraform: Đọc outputs
  loop Tối đa 30 phút
    Deploy->>SSM: aws ssm get-parameter --with-decryption
    SSM-->>Deploy: kubeconfig nếu đã sẵn sàng
  end
  Deploy->>Deploy: Ghi generated/kubeconfig.yaml
  loop Tối đa 10 phút
    Deploy->>Kubectl: kubectl --kubeconfig generated/kubeconfig.yaml get nodes
  end
  Deploy-->>Operator: In App URL, Argo CD URL, kubeconfig path
```

Sau khi `deploy.ps1` thành công:

- AWS infra đã được tạo.
- EC2 đang chạy minikube.
- Kubernetes API reachable từ máy local qua `generated/kubeconfig.yaml`.
- Terraform outputs đã có `development_app_url`, `production_app_url`, và `argocd_url`.
- Argo CD và app chưa nhất thiết đã tồn tại. Chúng được tạo ở pha `argocd/install.ps1`.

## 7. Argo CD Là Trung Tâm Của App Delivery

Thư mục `argocd/` gồm:

```text
argocd/
|-- install/                 # Argo CD installation overlay
|-- bootstrap/               # Tài nguyên bootstrap Argo CD ApplicationSet
|-- apps/                    # Các wrapper & ứng dụng được đồng bộ bởi Argo CD
|-- install.ps1              # Cài Argo CD và apply ApplicationSet
`-- uninstall.ps1            # Gỡ Argo CD khỏi remote cluster
```

### 7.1. Argo CD install overlay

`argocd/install/kustomization.yaml` gồm:

```text
argocd/install/namespace.yaml
https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.3/manifests/install.yaml
argocd/install/argocd-server-nodeport.yaml
```

Project không viết lại toàn bộ manifest Argo CD. Nó dùng upstream Argo CD install manifest version `v3.4.3`, rồi thêm hai phần local:

- Namespace `argocd`.
- Service `argocd-server-nodeport`.

`argocd-server-nodeport.yaml` là custom Service để expose Argo CD UI/API:

- Name: `argocd-server-nodeport`.
- Namespace: `argocd`.
- Type: `NodePort`.
- Service port: `443`.
- Target port: `8080`.
- NodePort: `30443`.
- Selector: `app.kubernetes.io/name: argocd-server`.

Vì EC2 security group mở port `30443` và minikube bootstrap map port `30443`, bạn truy cập Argo CD bằng:

```text
https://EC2_PUBLIC_IP:30443/
```

Argo CD server dùng certificate tự ký, nên browser có thể hiện TLS warning.

### 7.2. `argocd/install.ps1`

Lệnh cài Argo CD:

```powershell
.\argocd\install.ps1 `
  -RepoUrl "https://github.com/*/test-argocd.git" `
  -TargetRevision "main"
```

Script làm các bước:

1. Dùng kubeconfig mặc định `generated\kubeconfig.yaml`, trừ khi truyền `-KubeconfigPath`.
2. Nếu không truyền `-RepoUrl`, script thử đọc Git remote của workspace.
3. Apply Argo CD install overlay bằng server-side apply:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml apply `
  --server-side=true `
  --force-conflicts `
  --field-manager=argocd-installer `
  -k argocd/install
```

Server-side apply là điểm quan trọng. CRD của Argo CD, đặc biệt `applicationsets.argoproj.io`, có annotation rất lớn. Nếu dùng client-side apply thông thường, có thể gặp lỗi:

```text
metadata.annotations: Too long: may not be more than 262144 bytes
```

4. Đợi ba CRD của Argo CD Established:
   - `applications.argoproj.io`
   - `appprojects.argoproj.io`
   - `applicationsets.argoproj.io`
5. Đợi tất cả deployment trong namespace `argocd` Available.
6. Đợi StatefulSet `argocd-application-controller` rollout xong.
7. Đọc `argocd/bootstrap/apps-applicationset.yaml`, thay repo URL và target revision theo tham số, rồi apply Argo CD `ApplicationSet`.
8. In Argo CD URL và demo app URL từ Terraform outputs nếu đọc được.

### 7.3. Argo CD ApplicationSet

`argocd/bootstrap/apps-applicationset.yaml` khai báo một Argo CD `ApplicationSet` tên là `sandbox-apps` sử dụng Git generator để tự động phát hiện và quản lý các môi trường ứng dụng riêng biệt.

Nó quét các đường dẫn khớp với:
- `argocd/apps/*/overlays/production` (ví dụ: `argocd/apps/backend/overlays/production`).

Với mỗi môi trường tìm thấy, nó sẽ tự động tạo một tài nguyên `Application` với các cấu hình sau:

| Thiết lập | Giá trị / Hành vi |
| --- | --- |
| **Project** | `sandbox` (được định nghĩa là một `AppProject` tùy chỉnh trong cùng manifest bootstrap). |
| **Đường dẫn nguồn** | Đường dẫn do generator tìm được (ví dụ: `argocd/apps/backend/overlays/production`). |
| **Namespace đích** | Namespace tương ứng với môi trường (ví dụ: `demo-production`). |
| **Tự động dọn dẹp** | `prune = true` (các tài nguyên bị xóa khỏi Git sẽ bị xóa khỏi cluster). |
| **Tự động sửa lỗi** | `selfHeal = true` (các thay đổi thủ công trên cluster sẽ bị ghi đè bởi trạng thái trong Git). |
| **Tự động tạo Namespace** | `CreateNamespace = true` (tự động tạo namespace đích nếu chưa tồn tại). |

Sau khi Argo CD đã cài, bạn không cần Terraform để update app. Muốn đổi app, sửa manifest trong `argocd/apps/`, push lên Git, rồi để Argo CD reconcile.

### 7.4. Demo app manifests

`argocd/apps/` chứa các thư mục con cho từng ứng dụng và controller:

- `frontend/`: Web UI (được expose qua NodePort `30080` ở production / `30081` ở development). Sử dụng `Rollout` để triển khai dạng canary.
- `backend/`: Go REST API backend (sử dụng `Rollout` canary và `AnalysisTemplate`).
- `database/`: Cơ sở dữ liệu Redis (sử dụng `StatefulSet` với persistent volume storage).
- `prometheus/`: Hệ thống giám sát Prometheus (được expose qua NodePort `39090` sử dụng Helm chart wrapper).
- `argo-rollout/`: Argo Rollouts controller (sử dụng Helm chart wrapper).

Đối với các ứng dụng có cấu trúc base/overlay tùy chỉnh (frontend, backend, database), cấu trúc thư mục như sau:

```text
base/                     # Các manifest cơ sở dùng chung (như Rollout, StatefulSet, ClusterIP Service)
overlays/development/     # Overlay cho môi trường Development (namespace demo-development, số lượng replica và NodePort riêng)
overlays/production/      # Overlay cho môi trường Production (namespace demo-production, số lượng replica và NodePort riêng)
```

Với các ứng dụng frontend/backend/database, thư mục base chứa `Rollout` (cho frontend và backend) hoặc `StatefulSet` (cho database) và một Service `ClusterIP` nội bộ dùng chung.

Các overlay sẽ bổ sung namespace, số lượng replica và các thiết lập Service tương ứng với từng môi trường:

- **Frontend**:
  - Rollout dùng chung trong base chạy nginx trên container port `80` với memory limit `128Mi` và CPU limit `100m`.
  - Development overlay: namespace `demo-development`, `1` replica, exposed qua Service `NodePort` tại port `30081`.
  - Production overlay: namespace `demo-production`, `1` replica, exposed qua Service `NodePort` tại port `30080`.
- **Backend**:
  - Rollout dùng chung trong base chạy Go backend trên container port `5000` với memory limit `256Mi` và CPU limit `200m`. Nó cấu hình chiến lược canary được đánh giá bởi `AnalysisTemplate`.
  - Development overlay: namespace `demo-development`, `1` replica, exposed nội bộ qua Service `ClusterIP` tại port `5000`.
  - Production overlay: namespace `demo-production`, `4` replicas, exposed nội bộ qua Service `ClusterIP` tại port `5000`.
- **Database**:
  - Statefulset trong base chạy `redis:7-alpine` trên port `6379` với volume claim 1Gi.
  - Development overlay: namespace `demo-development`, `1` replica.
  - Production overlay: namespace `demo-production`, `1` replica.

Mỗi NodePort hoặc port của ứng dụng được expose phải khớp ở 3 nơi:

- `infra/variables.tf` biến `node_port` (`30080`), `development_node_port` (`30081`), hoặc `argocd_node_port` (`30443`).
- EC2 security group ingress rules cho các ứng dụng.
- Minikube bootstrap cấu hình `--ports` cho các port tương ứng (bao gồm cả `39090` cho Prometheus).

Nếu bạn đổi bất kỳ NodePort nào được expose, hãy cập nhật cả Terraform variables và các manifest Service overlay tương ứng.

## 8. GitOps Workflow Sau Khi Cài Argo CD

```mermaid
flowchart LR
  Edit["Sửa manifest trong argocd/apps/"]
  Commit["Commit và push lên Git"]
  Repo["Git repo / branch targetRevision"]
  RepoServer["argocd-repo-server đọc repo"]
  Controller["argocd-application-controller<br/>so sánh desired vs live"]
  Sync["Automated sync"]
  Cluster["demo namespace trên minikube"]

  Edit --> Commit --> Repo
  Repo --> RepoServer
  RepoServer --> Controller
  Controller --> Sync
  Sync --> Cluster
```

Vì `prune` và `selfHeal` đang bật:

- Sửa image, replicas, probes, hoặc resource limits trong Git -> Argo CD update cluster.
- Xóa manifest khỏi Git -> Argo CD prune resource khỏi cluster.
- Sửa trực tiếp Deployment bằng `kubectl edit` -> Argo CD phát hiện drift và sửa lại theo Git.

Đây là workflow chính sau khi stack đã chạy. Terraform không phải công cụ deploy app nữa.

## 9. Các Component Mới Hoặc Custom

### 9.1. Local Terraform wrapper modules

`modules/vpc` và `modules/ec2-instance` là wrapper quanh upstream Terraform modules.

Mục đích:

- Pin version upstream rõ ràng.
- Giữ local docs/examples.
- Tạo contract module ổn định cho repo.
- Tránh viết lại toàn bộ VPC/EC2 resource bằng tay.

### 9.2. `minikube-user-data.sh.tftpl`

Đây là bootstrap riêng của project. Nó biến một EC2 public instance thành remote minikube host:

- Cài Docker, minikube, kubectl.
- Tạo minikube profile.
- Expose Kubernetes API qua public IP và port `8443`.
- Map NodePort cho app và Argo CD ra EC2 host.
- Rewrite kubeconfig để local kubectl truy cập remote cluster.
- Publish kubeconfig vào SSM `SecureString`.
- Xử lý trường hợp EC2 public IP đổi sau stop/start.

### 9.3. `argocd-server-nodeport.yaml`

Custom Service này tạo đường vào Argo CD UI/API:

```text
EC2 public IP:30443 -> minikube port mapping -> argocd-server-nodeport -> argocd-server
```

Nếu không có Service này, Argo CD vẫn chạy trong cluster nhưng bạn phải dùng port-forward mới truy cập được UI.

### 9.4. `argocd/install.ps1`

Script này là cầu nối giữa pha Terraform và pha GitOps:

- Cài Argo CD bằng server-side apply.
- Đợi Argo CD sẵn sàng.
- Tạo Argo CD `Application`.
- Gắn repo URL và branch vào Application.

### 9.5. `argocd/uninstall.ps1`

Script này gỡ chỉ Argo CD khỏi remote cluster (giữ lại app workloads):

```powershell
.\argocd\uninstall.ps1
```

Để chỉ xóa resources của demo app mà không gỡ Argo CD, chạy:

```powershell
.\argocd\uninstall.ps1 -DeleteApps
```

Mặc định, nó xóa các đối tượng Application, namespace `argocd`, cluster RBAC của Argo CD, và Argo CD CRDs. Flag `-DeleteApps` sẽ chỉ xóa demo app resources trong `argocd/apps/` và thoát.

## 10. Các Lệnh Vận Hành Chính

### 10.1. Deploy infra và lấy kubeconfig

```powershell
.\scripts\deploy.ps1
```

Skip Terraform init nếu đã init trước:

```powershell
.\scripts\deploy.ps1 -SkipInit
```

Dùng var file:

```powershell
.\scripts\deploy.ps1 -InfraVarFile="terraform.tfvars"
```

### 10.2. Cài Argo CD và sync app

```powershell
.\argocd\install.ps1 `
  -RepoUrl "https://github.com/*/test-argocd.git" `
  -TargetRevision "main"
```

### 10.3. Kiểm tra cluster, Argo CD, app

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml get nodes
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get pods,svc
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get application
kubectl --kubeconfig generated\kubeconfig.yaml -n demo get pods,svc
```

### 10.4. Lấy URL

```powershell
terraform -chdir=infra output -raw development_app_url
terraform -chdir=infra output -raw production_app_url
terraform -chdir=infra output -raw argocd_url
```

### 10.5. Lấy Argo CD admin password

```powershell
$PasswordB64 = kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($PasswordB64))
```

Username mặc định:

```text
admin
```

### 10.6. Gỡ Argo CD

```powershell
.\argocd\uninstall.ps1
```

Xóa chỉ resources của demo app workload:

```powershell
.\argocd\uninstall.ps1 -DeleteApps
```

### 10.7. Destroy toàn bộ AWS infra

```powershell
.\scripts\destroy.ps1
```

Destroy infra sẽ terminate EC2. Vì minikube và Argo CD chạy bên trong EC2, toàn bộ Kubernetes resources trong cluster cũng mất theo EC2.

## 11. Troubleshooting Theo Từng Lớp

### 11.1. Terraform apply xong nhưng deploy script đợi kubeconfig quá lâu

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

Nguyên nhân hay gặp:

- EC2 chưa tải xong minikube hoặc kubectl.
- Docker chưa sẵn sàng.
- Minikube start chậm do instance nhỏ.
- EC2 thiếu permission `ssm:PutParameter`.
- Kubeconfig trong SSM chưa trỏ đúng `https://EC2_PUBLIC_IP:8443`.

### 11.2. `kubectl get nodes` không kết nối được

Kiểm tra:

- `generated/kubeconfig.yaml` có tồn tại không.
- Security group có mở `kubernetes_api_port` cho public IP hiện tại của bạn không.
- EC2 có public IPv4 mới sau stop/start không.
- Kubeconfig có `server: https://EC2_PUBLIC_IP:8443` không.

Nếu EC2 public IP đổi, systemd service sẽ recreate minikube profile và publish kubeconfig mới. Chạy lại:

```powershell
.\scripts\deploy.ps1 -SkipInit
```

để fetch kubeconfig mới về local.

### 11.3. Cài Argo CD gặp lỗi CRD annotation quá lớn

Không dùng client-side `kubectl apply -k argocd/install` cho overlay Argo CD. Dùng script:

```powershell
.\argocd\install.ps1 -RepoUrl "https://github.com/*/test-argocd.git" -TargetRevision "main"
```

Script đã dùng server-side apply để tránh lỗi annotation quá lớn của CRD.

### 11.4. Argo CD chạy nhưng app không sync

Kiểm tra Application:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get application frontend-production -o yaml
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get application backend-production -o yaml
```

Kiểm tra các điểm sau:

- `repoURL` có đúng repo mà Argo CD truy cập được không.
- `targetRevision` có đúng branch/tag không.
- `path` có đúng `argocd/apps/backend/overlays/production` hoặc `argocd/apps/frontend/overlays/production` không.
- Repo có chứa Kubernetes manifests hợp lệ không.
- Nếu repo private, cần cấu hình repository credentials cho Argo CD.

### 11.5. Argo CD URL mở được nhưng browser báo certificate warning

Đây là trạng thái hiện tại. `argocd-server` dùng TLS certificate tự ký trong cluster.

Truy cập:

```text
https://EC2_PUBLIC_IP:30443/
```

Trong sandbox này, có thể accept warning. Nếu muốn production-like, cần domain, TLS certificate thật, và ingress/load balancer riêng.

## 12. Khi Mở Rộng Project

- Nếu thêm app mới, tạo thư mục mới dưới `argocd/apps/` (ví dụ: `argocd/apps/my-new-app/overlays/production`). Argo CD `ApplicationSet` sẽ tự động phát hiện đường dẫn overlay mới và tạo tài nguyên `Application` tương ứng.
- Nếu app mới cần NodePort khác, phải cập nhật Terraform security group, minikube port mapping, và Kubernetes Service manifest.
- Nếu dùng private Git repo, cần thêm repo credentials cho Argo CD.
- Nếu muốn endpoint ổn định, cần thêm Elastic IP hoặc DNS. Hiện tại public IP của EC2 có thể đổi sau stop/start.
- Nếu muốn production Kubernetes, không nên xem minikube trên EC2 là thay thế EKS. Đây là sandbox chi phí thấp để học và demo GitOps.
- Nếu muốn app delivery đúng GitOps, không sửa app resources trực tiếp bằng `kubectl`; hãy sửa manifest trong Git và để Argo CD sync.
