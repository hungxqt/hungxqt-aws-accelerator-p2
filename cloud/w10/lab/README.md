# Terraform AWS Minikube Sandbox

[Tiếng Việt](README_vi.md)

## Overview

This repository creates a low-cost personal Kubernetes sandbox on AWS:

- `infra/` creates one public VPC subnet, one EC2 instance, IAM, and security group rules.
- The EC2 instance runs Docker and minikube.
- EC2 publishes the generated kubeconfig to AWS Systems Manager Parameter Store as a `SecureString`.
- `argocd/` installs Argo CD and contains the app manifests Argo CD syncs.
- The demo app is exposed directly through the EC2 public IP and Kubernetes NodePort.

Request flow:

```text
Internet or your allowed CIDR
  -> EC2 public IPv4 :node_port
  -> minikube NodePort Service
  -> demo app Pod
```

Terraform owns AWS infrastructure and minikube bootstrap only. Argo CD owns Kubernetes application delivery.

## Cost Shape

The active stack avoids the recurring resources that usually dominate a small sandbox bill:

- No NAT Gateway.
- No Application Load Balancer.
- No Elastic IP.
- Default EC2 shape is `t4g.small` with CPU credits set to `standard`.

The instance and its public IPv4 address still cost money while the instance is running. Stop the instance manually or run destroy when you are done.

## Repository Layout

```text
.
|-- infra/
|   |-- main.tf                  # VPC and EC2 minikube host
|   |-- security.tf              # EC2 ingress and egress rules
|   |-- iam.tf                   # IAM policy for kubeconfig publication
|   |-- templates/
|   |   `-- minikube-user-data.sh.tftpl
|   `-- terraform.tfvars.example
|-- argocd/
|   |-- install/                 # Argo CD install overlay and NodePort Service
|   |-- bootstrap/               # Argo CD ApplicationSet bootstrap resource
|   |-- apps/                    # Wrappers & applications synced by Argo CD
|   |   |-- frontend/            # Frontend Web UI (Rollout canary)
|   |   |-- backend/             # Go REST API backend (Rollout + AnalysisTemplate)
|   |   |-- database/            # Redis database
|   |   |-- tenant-namespaces/   # Bootstraps tenant namespaces and resource quotas
|   |   |-- team-rbac/           # Namespace-scoped Developer RBAC
|   |   |-- network-policies/    # Namespace egress network isolation policies
|   |   |-- gatekeeper-operator/ # OPA Gatekeeper Operator
|   |   |-- gatekeeper-policies/ # OPA Gatekeeper policies/constraints
|   |   |-- policy-controller/   # Sigstore Policy Controller
|   |   |-- cosign-policies/     # Cosign image signature verification policies
|   |   |-- rbac/                # Cluster-scoped operator/viewer RBAC
|   |   |-- argo-rollout/        # Argo Rollouts controller wrapper chart
|   |   |-- metrics-server/      # Kubernetes Metrics Server wrapper chart
|   |   `-- prometheus/          # Prometheus monitoring wrapper chart
|   |-- install.ps1
|   `-- uninstall.ps1
|-- scripts/
|   |-- deploy.ps1               # Infra bootstrap and kubeconfig fetch
|   |-- destroy.ps1
|   `-- fetch-kube-config.ps1
|-- generated/                   # Local kubeconfig, git-ignored
|`-- modules/
    |-- vpc/                     # Local wrapper module
    `-- ec2-instance/            # Local wrapper module
```

## Prerequisites

The following tools must be available on PATH:

- Terraform
- AWS CLI authenticated to the target AWS account
- kubectl
- PowerShell

Quick check:

```powershell
terraform version
aws sts get-caller-identity
kubectl version --client=true
```

## Optional Configuration

Copy the infra example file if you want to customize values:

```powershell
Copy-Item infra\terraform.tfvars.example infra\terraform.tfvars
```

Common `infra/terraform.tfvars` values:

```hcl
aws_region  = "us-east-1"
name_prefix = "tf-minikube-demo"

# When null, Terraform detects your current public IPv4 and allows only that /32
# to reach the Kubernetes API. Do not use 0.0.0.0/0 for API access.
allowed_kubernetes_api_cidr = null

# When null, app access uses the same detected/operator CIDR.
allowed_app_cidr = null

# When null, Argo CD UI/API access uses the detected/operator CIDR.
allowed_argocd_cidr = null

instance_type          = "t4g.small"
node_port              = 30080 # production app
development_node_port  = 30081 # development app
argocd_node_port       = 30443

tags = {
  Environment = "demo"
}
```

## Deploy Infrastructure

```powershell
.\scripts\deploy.ps1
```

The script:

1. Runs `terraform -chdir=infra init`.
2. Runs `terraform -chdir=infra apply -auto-approve`.
3. Waits for EC2 to create minikube and publish kubeconfig to SSM.
4. Downloads SSM `SecureString` to `generated/kubeconfig.yaml`.
5. Waits for the Kubernetes API.
6. Prints the app, Argo CD, and kubeconfig locations.

Use an explicit infra var file:

```powershell
.\scripts\deploy.ps1 -InfraVarFile="terraform.tfvars"
```

Skip init after the first successful init:

```powershell
.\scripts\deploy.ps1 -SkipInit
```

## Install Argo CD And Sync The App

### 1. Upload your credentials to AWS Secrets Manager
This codebase uses the External Secrets Operator (ESO) to retrieve credentials (GitHub PAT and Alertmanager SMTP password) from AWS Secrets Manager so they are not committed in plaintext.

1. Ensure your AWS credentials are configured locally.
2. Run the helper script to upload your secrets:
   ```powershell
   .\scripts\upload-secrets-to-aws.ps1
   ```

### 2. Deploy Argo CD
Push this repository to Git, then install Argo CD into minikube and apply the ApplicationSet:

```powershell
.\argocd\install.ps1 `
  -RepoUrl "https://github.com/YOUR_ORG/YOUR_REPO.git" `
  -TargetRevision "main"
```

Argo CD syncs the application stack dynamically using an ApplicationSet. Main application paths include:

```text
# Tenant platform resources & security controls
argocd/apps/tenant-namespaces/overlays/production # Bootstraps demo-development & demo-production namespaces and quotas
argocd/apps/team-rbac/overlays/*                  # Sets up Developer RBAC for both environments
argocd/apps/network-policies/overlays/*           # Enforces network isolation between environments
argocd/apps/gatekeeper-policies/overlays/*        # OPA Gatekeeper security policies
argocd/apps/cosign-policies/overlays/*            # Sigstore verification policies

# Workload environments (Production & Development)
argocd/apps/frontend/overlays/production          # Prod Frontend (Canary Rollout, NodePort 30080)
argocd/apps/frontend/overlays/development         # Dev Frontend (Rollout, NodePort 30081)
argocd/apps/backend/overlays/production           # Prod Backend (Canary Rollout + AnalysisTemplate)
argocd/apps/backend/overlays/development          # Dev Backend (Rollout)
argocd/apps/database/overlays/production          # Prod Redis Database (StatefulSet)
argocd/apps/database/overlays/development         # Dev Redis Database

# Operators & system tools
argocd/apps/prometheus/overlays/production        # Prometheus server (NodePort 39090)
argocd/apps/argo-rollout/overlays/production      # Argo Rollouts controller
argocd/apps/gatekeeper-operator/overlays/production# OPA Gatekeeper operator
argocd/apps/policy-controller/overlays/production  # Sigstore policy-controller
argocd/apps/rbac/overlays/production              # Cluster-level RBAC
argocd/apps/metrics-server/overlays/production      # Kubernetes Metrics Server
```

Check Argo CD and the app:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get pods,svc
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get pods,svc,rollouts
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-development get pods,svc,rollouts
terraform -chdir=infra output -raw argocd_url
terraform -chdir=infra output -raw production_app_url
terraform -chdir=infra output -raw development_app_url
```

Remove Argo CD only from the remote minikube cluster (keeping the demo app resources):

```powershell
.\argocd\uninstall.ps1
```

Remove only the synced demo app workload resources (keeping Argo CD):

```powershell
.\argocd\uninstall.ps1 -DeleteApps
```

## Run Infra Manually

```powershell
terraform -chdir=infra init
terraform -chdir=infra fmt -check
terraform -chdir=infra validate
terraform -chdir=infra plan -out=infra.tfplan
terraform -chdir=infra apply infra.tfplan
```

Download kubeconfig:

```powershell
.\scripts\fetch-kube-config.ps1
kubectl --kubeconfig generated\kubeconfig.yaml get nodes
```

## Public IP Changes

This stack does not allocate an Elastic IP. If you stop and start the EC2 instance, AWS can assign a different public IPv4 address.

The minikube bootstrap service runs on every boot. If it detects a new public IP, it recreates the minikube profile so the API certificate is valid for the new address, then republishes kubeconfig to SSM. Re-run `.\scripts\deploy.ps1 -SkipInit` to fetch the refreshed kubeconfig. Argo CD will reconcile the app after the cluster is reachable.

## Destroy

```powershell
.\scripts\destroy.ps1
```

Manual destroy:

```powershell
$Region = terraform -chdir=infra output -raw aws_region
$Param = terraform -chdir=infra output -raw kubeconfig_ssm_parameter_name

aws ssm delete-parameter --region $Region --name $Param
terraform -chdir=infra destroy
```

Destroying infra removes the EC2 minikube cluster and therefore the Argo CD/app resources inside it.

## CI Image Publishing

The GitHub Actions CI workflow validates manifests, lints workflow/YAML files, runs Go checks, builds backend and frontend images, and publishes non-latest tags to Docker Hub on pushes to `main`.

Trivy scans are currently reporting-only: findings are uploaded as artifacts, but vulnerability findings do not fail the workflow. This is intentional for the current lab phase. To make Trivy a blocking gate later, change the Trivy `exit-code` from `"0"` to `"1"` for the severities that should block releases.

Published images are signed with Cosign using an encrypted private key stored in AWS Secrets Manager. The CI workflow assumes a narrow AWS role through GitHub OIDC, fetches `minikube-sandbox/cosign-key` and `minikube-sandbox/cosign-password`, signs the pushed image digest refs, then removes the key file from the runner temp directory. The current lab accepts the existing weak Cosign password; rotate it before using this signing path for a real environment. Signature verification uses `cosign/cosign.pub`. Argo CD manifests should use digest-pinned image references when moving a built image into the cluster.

## Troubleshooting

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

Security notes:

- Kubeconfig is stored in SSM as a `SecureString`.
- `generated/kubeconfig.yaml`, `.terraform/`, `*.tfstate`, `*.tfplan`, and `terraform.tfvars` are git-ignored.
- The Kubernetes API CIDR and Argo CD CIDR must not be `0.0.0.0/0`.
