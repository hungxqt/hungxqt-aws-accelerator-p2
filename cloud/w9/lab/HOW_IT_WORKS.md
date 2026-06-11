# HOW IT WORKS - Terraform AWS Minikube Sandbox

This document explains how this repository deploys infrastructure, how EC2 bootstraps minikube, how kubeconfig is brought back to the local machine, and especially how Argo CD takes over Kubernetes application delivery.

The most important points in the current architecture:

- Terraform only manages AWS infrastructure and minikube bootstrap.
- Argo CD manages Kubernetes application delivery.
- There is no longer an `app/` Terraform root.
- There are no Terraform-managed `demo` namespace, `Deployment`, or `Service` resources.
- There is no ALB, no Elastic IP, and no Kubernetes `LoadBalancer`.
- Traffic goes directly to the EC2 public IPv4 through NodePort.

## 1. Ownership Boundary

| Area | Managed by | Main files |
| --- | --- | --- |
| AWS infrastructure | Terraform | `infra/` |
| VPC and EC2 module wrappers | Terraform local modules | `modules/vpc/`, `modules/ec2-instance/` |
| EC2 bootstrap and minikube | EC2 user data + systemd | `infra/templates/minikube-user-data.sh.tftpl` |
| Fetch kubeconfig locally | PowerShell + AWS SSM | `scripts/deploy.ps1`, `scripts/fetch-kube-config.ps1` |
| Install Argo CD | kubectl + Kustomize | `argocd/install.ps1`, `argocd/install/` |
| Kubernetes app | Argo CD | `argocd/bootstrap/apps-applicationset.yaml`, `argocd/apps/frontend/`, `argocd/apps/backend/`, etc. |
| Uninstall Argo CD | kubectl | `argocd/uninstall.ps1` |
| Destroy AWS infra | Terraform | `scripts/destroy.ps1` |

This boundary avoids making Terraform manage Kubernetes resources before the Kubernetes API exists. Terraform creates the remote minikube cluster first. After that, Argo CD is installed into the cluster and starts syncing the app from Git.

## 2. Overall Architecture Diagram

```mermaid
flowchart LR
  Operator["Operator local machine<br/>PowerShell, Terraform, AWS CLI, kubectl"]
  Deploy["scripts/deploy.ps1"]
  TF["Terraform root: infra/"]
  AWS["AWS resources<br/>VPC, subnet, SG, IAM, EC2"]
  EC2["EC2 public instance<br/>Docker + minikube"]
  Bootstrap["minikube-bootstrap.service<br/>creates cluster, publishes kubeconfig"]
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

The flow has two separate phases:

1. `scripts/deploy.ps1` deploys AWS infra, waits for EC2 to bootstrap minikube, and downloads kubeconfig from SSM into `generated/kubeconfig.yaml`.
2. `argocd/install.ps1` uses that kubeconfig to install Argo CD and create the Argo CD `Application`.

This is why Argo CD is not part of the Terraform apply flow. Terraform does not need a Kubernetes provider to create the app. After the cluster exists, Argo CD becomes responsible for syncing Kubernetes resources.

## 3. Traffic Diagram

The current stack exposes both the app and Argo CD through NodePort on the EC2 public IP.

```mermaid
flowchart TB
  UserApp["Demo app user"]
  UserArgo["Operator accessing Argo CD"]
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

  UserApp -->|"http://EC2_PUBLIC_IP:30080 or :30081"| PublicIP
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

Main ports:

| Port | Terraform variable | Purpose | Security group CIDR |
| --- | --- | --- | --- |
| `8443` | `kubernetes_api_port` | minikube Kubernetes API | `allowed_kubernetes_api_cidr` or operator `/32` |
| `30080` | `node_port` | Production demo app NodePort | `allowed_app_cidr`, `allowed_http_cidr`, or operator `/32` |
| `30081` | `development_node_port` | Development demo app NodePort | `allowed_app_cidr`, `allowed_http_cidr`, or operator `/32` |
| `30443` | `argocd_node_port` | Argo CD UI/API NodePort | `allowed_argocd_cidr` or operator `/32` |

`allowed_kubernetes_api_cidr` and `allowed_argocd_cidr` are validated so they cannot be `0.0.0.0/0`. The app CIDR can be broader, but that should be intentional because it is a public NodePort on EC2.

## 4. How Terraform Deploys Infra

### 4.1. Terraform root `infra/`

`infra/versions.tf` sets the version floor:

- Terraform `>= 1.5.7, < 2.0`.
- AWS provider `>= 6.37, < 7.0`.
- HTTP provider `>= 3.5, < 4.0`.

`infra/main.tf` creates two modules:

- `module "vpc"` calls the local wrapper `../modules/vpc`.
- `module "minikube_host"` calls the local wrapper `../modules/ec2-instance`.

The local wrapper `modules/vpc` pins upstream `terraform-aws-modules/vpc/aws` version `6.6.1`.

The local wrapper `modules/ec2-instance` pins upstream `terraform-aws-modules/ec2-instance/aws` version `6.4.0`.

### 4.2. VPC

The VPC is configured as a low-cost sandbox:

- Default CIDR `10.40.0.0/16`.
- One public subnet.
- `map_public_ip_on_launch = true`.
- No NAT Gateway.
- No Elastic IP.
- No Application Load Balancer.
- No private app tier.

The EC2 host is placed in this public subnet and receives a dynamic public IPv4 from AWS.

### 4.3. EC2 minikube host

The EC2 instance is created by `module "minikube_host"` with these main settings:

- Default instance type `t4g.small`.
- AMI is Amazon Linux 2023, selected by instance type architecture.
- If the instance type is Graviton, such as `t4g.small`, the AMI architecture is `arm64`.
- Public IP is assigned directly, but no Elastic IP is created.
- Root EBS volume is `gp3`, encrypted, and defaults to 30 GiB.
- IMDSv2 is required with `http_tokens = "required"`.
- `instance_initiated_shutdown_behavior = "stop"`.
- `user_data_replace_on_change = true`.

`user_data_replace_on_change = true` means changes to the bootstrap template can cause Terraform to replace the EC2 instance. If the EC2 instance is replaced, the minikube cluster inside it is recreated.

### 4.4. Auto-detect operator CIDR

`infra/locals.tf` uses the HTTP provider to call:

```text
https://checkip.amazonaws.com
```

If `allowed_kubernetes_api_cidr = null`, Terraform reads the current public IPv4 of the machine running Terraform and turns it into a `/32`.

That CIDR is used for the Kubernetes API. The app and Argo CD can also inherit this CIDR if `allowed_app_cidr` or `allowed_argocd_cidr` is `null`.

This is safer by default than exposing the API to the whole internet. If your public IP changes, you need to apply infra again so the security group allows the new IP.

### 4.5. IAM and SSM kubeconfig

The EC2 instance has an IAM role with:

- `AmazonSSMManagedInstanceCore`, so the instance can work with AWS Systems Manager.
- Custom policy `aws_iam_policy.kubeconfig_writer`, allowing it to write exactly one SSM parameter containing kubeconfig.
- KMS encrypt permissions restricted through the SSM service in the same account.

Kubeconfig is stored in SSM Parameter Store as a `SecureString`. The local script downloads it with `aws ssm get-parameter --with-decryption` and writes it to:

```text
generated/kubeconfig.yaml
```

That file is git-ignored.

## 5. EC2 Bootstrap Minikube

The bootstrap template is:

```text
infra/templates/minikube-user-data.sh.tftpl
```

This is the most important custom infra component. Terraform renders this template into EC2 user data and passes values such as:

- AWS region.
- Kubernetes version.
- minikube version.
- kubectl version.
- Kubernetes API port.
- Production app NodePort.
- Development app NodePort.
- Argo CD NodePort.
- SSM parameter name for kubeconfig.

### 5.1. What user data does when EC2 boots

User data runs these steps:

1. `dnf update -y`.
2. Install `awscli-2`, `conntrack-tools`, and `docker`.
3. Enable and start Docker.
4. Create Linux user `minikube` if it does not already exist.
5. Add user `minikube` to the `docker` group.
6. Detect EC2 architecture: `arm64` or `amd64`.
7. Download the minikube binary for `minikube_version`.
8. Download the kubectl binary for `kubectl_version`.
9. Write `/etc/minikube-bootstrap/env`.
10. Create `/usr/local/sbin/minikube-bootstrap.sh`.
11. Create systemd unit `minikube-bootstrap.service`.
12. Enable and start the service.

### 5.2. `minikube-bootstrap.service`

This systemd service runs the real bootstrap and can run again after EC2 reboots.

```mermaid
flowchart TD
  Start["minikube-bootstrap.service start"]
  Env["Read /etc/minikube-bootstrap/env"]
  IMDS["Read EC2 public IPv4 with IMDSv2"]
  Compare["Compare with previous public IP"]
  Delete["If IP changed -> delete old minikube profile"]
  Status["Check minikube profile"]
  StartMini["If not Running -> minikube start"]
  Ready["kubectl wait node Ready"]
  Export["Export raw kubeconfig"]
  Rewrite["Rewrite server to https://PUBLIC_IP:8443"]
  PutSSM["Put kubeconfig into SSM SecureString"]
  Done["Write public-ip and bootstrap-complete"]

  Start --> Env --> IMDS --> Compare
  Compare --> Delete --> Status
  Compare --> Status
  Status --> StartMini --> Ready
  Status --> Ready
  Ready --> Export --> Rewrite --> PutSSM --> Done
```

Important details:

- The service reads public IPv4 with IMDSv2.
- If public IP changes after stop/start, the service deletes the old minikube profile and recreates it. This is required because the Kubernetes API certificate must include the new public IP.
- `minikube start` uses the Docker driver and container runtime `containerd`.
- minikube listens on `0.0.0.0`.
- The API server uses port `8443`.
- `--apiserver-ips="$PUBLIC_IPV4"` adds the public IP to the certificate SAN.
- `--ports` maps five ports from the minikube Docker container to the EC2 host:
  - `8443:8443` for the Kubernetes API.
  - `30443:30443` for Argo CD.
  - `30080:30080` for the production demo app.
  - `30081:30081` for the development demo app.
  - `39090:39090` for Prometheus.
- Raw kubeconfig is rewritten so `server:` points to `https://PUBLIC_IPV4:8443`.
- The public kubeconfig is published to SSM as a `SecureString`.

Bootstrap logs:

```text
/var/log/minikube-user-data.log
/var/log/minikube-bootstrap.log
```

## 6. What `scripts/deploy.ps1` Does

Deploy command:

```powershell
.\scripts\deploy.ps1
```

This script does not install Argo CD. It only deploys AWS infra, waits for minikube to become ready, and fetches kubeconfig locally.

```mermaid
sequenceDiagram
  participant Operator as Operator
  participant Deploy as scripts/deploy.ps1
  participant Terraform as Terraform infra/
  participant EC2 as EC2 user data
  participant SSM as SSM SecureString
  participant Kubectl as local kubectl

  Operator->>Deploy: .\scripts\deploy.ps1
  Deploy->>Terraform: terraform -chdir=infra init
  Deploy->>Terraform: terraform -chdir=infra apply -auto-approve
  Terraform->>EC2: Create EC2 with user_data
  EC2->>EC2: Install Docker, minikube, kubectl
  EC2->>EC2: Start minikube
  EC2->>SSM: Put kubeconfig SecureString
  Deploy->>Terraform: Read outputs
  loop Up to 30 minutes
    Deploy->>SSM: aws ssm get-parameter --with-decryption
    SSM-->>Deploy: kubeconfig if ready
  end
  Deploy->>Deploy: Write generated/kubeconfig.yaml
  loop Up to 10 minutes
    Deploy->>Kubectl: kubectl --kubeconfig generated/kubeconfig.yaml get nodes
  end
  Deploy-->>Operator: Print App URL, Argo CD URL, kubeconfig path
```

After `deploy.ps1` succeeds:

- AWS infra has been created.
- EC2 is running minikube.
- The Kubernetes API is reachable from the local machine through `generated/kubeconfig.yaml`.
- Terraform outputs include `development_app_url`, `production_app_url`, and `argocd_url`.
- Argo CD and the app do not necessarily exist yet. They are created by the `argocd/install.ps1` phase.

## 7. Argo CD Is The Center Of App Delivery

The `argocd/` directory contains:

```text
argocd/
|-- install/                 # Argo CD installation overlay
|-- bootstrap/               # Argo CD ApplicationSet bootstrap resource
|-- apps/                    # Wrappers & applications synced by Argo CD
|-- install.ps1              # Installs Argo CD and applies the ApplicationSet
`-- uninstall.ps1            # Removes Argo CD from the remote cluster
```

### 7.1. Argo CD install overlay

`argocd/install/kustomization.yaml` includes:

```text
argocd/install/namespace.yaml
https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.3/manifests/install.yaml
argocd/install/argocd-server-nodeport.yaml
```

The project does not rewrite the entire Argo CD manifest. It uses the upstream Argo CD install manifest version `v3.4.3`, then adds two local pieces:

- Namespace `argocd`.
- Service `argocd-server-nodeport`.

`argocd-server-nodeport.yaml` is a custom Service that exposes Argo CD UI/API:

- Name: `argocd-server-nodeport`.
- Namespace: `argocd`.
- Type: `NodePort`.
- Service port: `443`.
- Target port: `8080`.
- NodePort: `30443`.
- Selector: `app.kubernetes.io/name: argocd-server`.

Because the EC2 security group opens port `30443` and minikube bootstrap maps port `30443`, you can access Argo CD at:

```text
https://EC2_PUBLIC_IP:30443/
```

Argo CD server uses a self-signed certificate, so the browser may show a TLS warning.

### 7.2. `argocd/install.ps1`

Install Argo CD:

```powershell
.\argocd\install.ps1 `
  -RepoUrl "https://github.com/*/test-argocd.git" `
  -TargetRevision "main"
```

The script does these steps:

1. Use the default kubeconfig `generated\kubeconfig.yaml`, unless `-KubeconfigPath` is passed.
2. If `-RepoUrl` is not passed, try to read the workspace Git remote.
3. Apply the Argo CD install overlay with server-side apply:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml apply `
  --server-side=true `
  --force-conflicts `
  --field-manager=argocd-installer `
  -k argocd/install
```

Server-side apply is important here. Argo CD CRDs, especially `applicationsets.argoproj.io`, have very large annotations. If you use normal client-side apply, you may hit this error:

```text
metadata.annotations: Too long: may not be more than 262144 bytes
```

4. Wait for the three Argo CD CRDs to be Established:
   - `applications.argoproj.io`
   - `appprojects.argoproj.io`
   - `applicationsets.argoproj.io`
5. Wait for all deployments in namespace `argocd` to become Available.
6. Wait for StatefulSet `argocd-application-controller` rollout to finish.
7. Render `argocd/bootstrap/apps-applicationset.yaml`, replace repo URL and target revision from script parameters, then apply the Argo CD `ApplicationSet` resource.
8. Print Argo CD URL and demo app URL from Terraform outputs if available.

### 7.3. Argo CD ApplicationSet

`argocd/bootstrap/apps-applicationset.yaml` declares an Argo CD `ApplicationSet` named `sandbox-apps` that uses a Git generator to dynamically discover and manage individual application environments.

It targets:
- Paths matching `argocd/apps/*/overlays/production` (e.g., `argocd/apps/backend/overlays/production`).

For each matching environment, it dynamically generates an `Application` resource with the following settings:

| Setting | Value / Behavior |
| --- | --- |
| **Project** | `sandbox` (a custom `AppProject` defined in the same bootstrap manifest). |
| **Source path** | The path discovered by the generator (e.g., `argocd/apps/backend/overlays/production`). |
| **Destination namespace** | The environment-specific namespace (e.g., `demo-production`). |
| **Automated Pruning** | `prune = true` (resources removed from Git are deleted from the cluster). |
| **Self Healing** | `selfHeal = true` (manual cluster changes are overridden by Git state). |
| **Create Namespace** | `CreateNamespace = true` (creates target namespaces if they do not exist). |

After Argo CD is installed, you do not need Terraform to update the app. To change the app, edit manifests under `argocd/apps/`, push to Git, and let Argo CD reconcile.

### 7.4. Demo app manifests

`argocd/apps/` contains subdirectories for individual applications and controllers:

- `frontend/`: Web UI (exposed via NodePort `30080` in production / `30081` in development). Uses `Rollout` for canary deployment.
- `backend/`: Go REST API backend (uses `Rollout` canary and `AnalysisTemplate`).
- `database/`: Redis database (uses `StatefulSet` with persistent volume storage).
- `prometheus/`: Prometheus monitoring stack (exposed via NodePort `39090` using a Helm chart wrapper).
- `argo-rollout/`: Argo Rollouts controller (using a Helm chart wrapper).

For applications with a custom base/overlay layout (frontend, backend, database), the folder structure is:

```text
base/                     # Shared base manifests (e.g., Rollout, StatefulSet, ClusterIP Service)
overlays/development/     # Development overlay (namespace demo-development, specific replica counts, NodePorts)
overlays/production/      # Production overlay (namespace demo-production, specific replica counts, NodePorts)
```

For frontend/backend/database applications, the base contains the shared `Rollout` (for frontend and backend) or `StatefulSet` (for database) and an internal `ClusterIP` Service.

The overlays add environment-specific namespaces, replica counts, and Service exposures:

- **Frontend**:
  - Rollout in base runs nginx on container port `80` with memory limit `128Mi` and CPU limit `100m`.
  - Development overlay: namespace `demo-development`, `1` replica, exposed via `NodePort` Service on `30081`.
  - Production overlay: namespace `demo-production`, `1` replica, exposed via `NodePort` Service on `30080`.
- **Backend**:
  - Rollout in base runs the Go backend on container port `5000` with memory limit `256Mi` and CPU limit `200m`. It configures a canary deployment strategy evaluated by `AnalysisTemplate`.
  - Development overlay: namespace `demo-development`, `1` replica, exposed internally via a `ClusterIP` Service on port `5000`.
  - Production overlay: namespace `demo-production`, `4` replicas, exposed internally via a `ClusterIP` Service on port `5000`.
- **Database**:
  - StatefulSet in base runs `redis:7-alpine` on port `6379` with a 1Gi persistent volume claim.
  - Development overlay: namespace `demo-development`, `1` replica.
  - Production overlay: namespace `demo-production`, `1` replica.

Each app NodePort or exposed port must match three places:

- `infra/variables.tf` variable `node_port` (`30080`), `development_node_port` (`30081`), or `argocd_node_port` (`30443`).
- EC2 security group ingress rules for the apps.
- minikube bootstrap `--ports` mappings for the same ports (including `39090` for Prometheus).

If you change any of the exposed NodePorts, update the Terraform variables and the matching Service overlay manifests.

## 8. GitOps Workflow After Argo CD Is Installed

```mermaid
flowchart LR
  Edit["Edit manifest in argocd/apps/"]
  Commit["Commit and push to Git"]
  Repo["Git repo / targetRevision branch"]
  RepoServer["argocd-repo-server reads repo"]
  Controller["argocd-application-controller<br/>compares desired vs live"]
  Sync["Automated sync"]
  Cluster["demo environment namespaces on minikube"]

  Edit --> Commit --> Repo
  Repo --> RepoServer
  RepoServer --> Controller
  Controller --> Sync
  Sync --> Cluster
```

Because `prune` and `selfHeal` are enabled:

- Change image, replicas, probes, or resource limits in Git -> Argo CD updates the cluster.
- Remove a manifest from Git -> Argo CD prunes the resource from the cluster.
- Edit the Deployment directly with `kubectl edit` -> Argo CD detects drift and restores the Git version.

This is the main workflow after the stack is running. Terraform is no longer the app deployment tool.

## 9. New Or Custom Components

### 9.1. Local Terraform wrapper modules

`modules/vpc` and `modules/ec2-instance` are wrappers around upstream Terraform modules.

Purpose:

- Pin upstream versions clearly.
- Keep local docs/examples.
- Provide a stable module contract for the repo.
- Avoid rewriting all VPC/EC2 resources by hand.

### 9.2. `minikube-user-data.sh.tftpl`

This is the project-specific bootstrap. It turns one public EC2 instance into a remote minikube host:

- Install Docker, minikube, and kubectl.
- Create the minikube profile.
- Expose Kubernetes API through public IP and port `8443`.
- Map NodePorts for the app and Argo CD to the EC2 host.
- Rewrite kubeconfig so local kubectl can access the remote cluster.
- Publish kubeconfig to SSM `SecureString`.
- Handle public IP changes after EC2 stop/start.

### 9.3. `argocd-server-nodeport.yaml`

This custom Service creates the entry path to Argo CD UI/API:

```text
EC2 public IP:30443 -> minikube port mapping -> argocd-server-nodeport -> argocd-server
```

Without this Service, Argo CD still runs in the cluster, but you would need port-forwarding to access the UI.

### 9.4. `argocd/install.ps1`

This script bridges the Terraform phase and the GitOps phase:

- Install Argo CD with server-side apply.
- Wait for Argo CD to be ready.
- Create the Argo CD `Application`.
- Attach repo URL and branch to the Application.

### 9.5. `argocd/uninstall.ps1`

This script removes Argo CD only (leaving the app workloads) from the remote cluster:

```powershell
.\argocd\uninstall.ps1
```

To remove only the demo app resources without removing Argo CD, run:

```powershell
.\argocd\uninstall.ps1 -DeleteApps
```

By default, it deletes the Application objects, namespace `argocd`, Argo CD cluster RBAC, and Argo CD CRDs. The `-DeleteApps` flag instead deletes only the app resources under `argocd/apps/` and exits.

## 10. Main Operations Commands

### 10.1. Deploy infra and fetch kubeconfig

```powershell
.\scripts\deploy.ps1
```

Skip Terraform init if it has already succeeded:

```powershell
.\scripts\deploy.ps1 -SkipInit
```

Use a var file:

```powershell
.\scripts\deploy.ps1 -InfraVarFile="terraform.tfvars"
```

### 10.2. Install Argo CD and sync the app

```powershell
.\argocd\install.ps1 `
  -RepoUrl "https://github.com/*/test-argocd.git" `
  -TargetRevision "main"
```

### 10.3. Check cluster, Argo CD, and app

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml get nodes
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get pods,svc
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get application
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-development get pods,svc
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get pods,svc
```

### 10.4. Get URLs

```powershell
terraform -chdir=infra output -raw development_app_url
terraform -chdir=infra output -raw production_app_url
terraform -chdir=infra output -raw argocd_url
```

### 10.5. Get Argo CD admin password

```powershell
$PasswordB64 = kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($PasswordB64))
```

Default username:

```text
admin
```

### 10.6. Uninstall Argo CD

```powershell
.\argocd\uninstall.ps1
```

Delete the demo app workload resources only:

```powershell
.\argocd\uninstall.ps1 -DeleteApps
```

### 10.7. Destroy all AWS infra

```powershell
.\scripts\destroy.ps1
```

Destroying infra terminates EC2. Because minikube and Argo CD run inside EC2, all Kubernetes resources in the cluster are removed with EC2.

## 11. Troubleshooting By Layer

### 11.1. Terraform apply completed but deploy script waits too long for kubeconfig

Check EC2 bootstrap logs through SSM:

```powershell
$InstanceId = terraform -chdir=infra output -raw instance_id
$Region = terraform -chdir=infra output -raw aws_region

aws ssm send-command `
  --region $Region `
  --instance-ids $InstanceId `
  --document-name AWS-RunShellScript `
  --parameters 'commands=["systemctl status minikube-bootstrap --no-pager","tail -n 240 /var/log/minikube-bootstrap.log"]'
```

Common causes:

- EC2 has not finished downloading minikube or kubectl.
- Docker is not ready.
- minikube starts slowly because the instance is small.
- EC2 is missing `ssm:PutParameter` permission.
- Kubeconfig in SSM does not yet point to `https://EC2_PUBLIC_IP:8443`.

### 11.2. `kubectl get nodes` cannot connect

Check:

- Whether `generated/kubeconfig.yaml` exists.
- Whether the security group opens `kubernetes_api_port` for your current public IP.
- Whether EC2 received a new public IPv4 after stop/start.
- Whether kubeconfig has `server: https://EC2_PUBLIC_IP:8443`.

If EC2 public IP changed, the systemd service recreates the minikube profile and publishes a new kubeconfig. Run:

```powershell
.\scripts\deploy.ps1 -SkipInit
```

to fetch the new kubeconfig locally.

### 11.3. Argo CD install hits the large CRD annotation error

Do not use client-side `kubectl apply -k argocd/install` for the Argo CD overlay. Use the script:

```powershell
.\argocd\install.ps1 -RepoUrl "https://github.com/*/test-argocd.git" -TargetRevision "main"
```

The script uses server-side apply to avoid the CRD annotation size error.

### 11.4. Argo CD is running but the app does not sync

Check the Application:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get application frontend-production -o yaml
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get application backend-production -o yaml
```

Check these points:

- Whether `repoURL` points to a repo Argo CD can access.
- Whether `targetRevision` is the right branch/tag.
- Whether `path` is `argocd/apps/backend/overlays/production` or `argocd/apps/backend/overlays/production`.
- Whether the repo contains valid Kubernetes manifests.
- If the repo is private, configure repository credentials for Argo CD.

### 11.5. Argo CD URL opens but the browser shows a certificate warning

This is expected in the current setup. `argocd-server` uses a self-signed TLS certificate in the cluster.

Access:

```text
https://EC2_PUBLIC_IP:30443/
```

For this sandbox, accepting the warning is fine. For a production-like setup, add a domain, a real TLS certificate, and separate ingress/load balancer wiring.

## 12. When Extending The Project

- If you add a new app, create a new directory under `argocd/apps/` (e.g., `argocd/apps/my-new-app/overlays/production`). The Argo CD `ApplicationSet` will automatically detect the new overlay path and create the corresponding `Application` resource.
- If the new app needs a different NodePort, update the Terraform security group, minikube port mapping, and Kubernetes Service manifest.
- If you use a private Git repo, add repository credentials for Argo CD.
- If you need a stable endpoint, add an Elastic IP or DNS. The current EC2 public IP can change after stop/start.
- If you need production Kubernetes, do not treat minikube on EC2 as an EKS replacement. This is a low-cost sandbox for learning and demoing GitOps.
- If you want proper GitOps application delivery, do not edit app resources directly with `kubectl`; edit manifests in Git and let Argo CD sync.
