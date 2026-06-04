# Terraform AWS kind ALB Demo

[Tiếng Việt](README_vi.md)

## Overview

This repository uses Terraform to create a small Kubernetes-on-AWS demo:

- `infra/` creates AWS infrastructure: VPC, public subnets, EC2, IAM role, security groups, Application Load Balancer, listener, target group, and target attachment.
- The EC2 instance is bootstrapped with `user_data` to install Docker, kind, and kubectl, then create a single-node kind cluster locally on the instance.
- The EC2 instance writes the generated kind kubeconfig to AWS Systems Manager Parameter Store as a `SecureString`.
- `app/` reads that kubeconfig and uses the Kubernetes provider to deploy a small application into the kind cluster.
- The AWS ALB forwards internet traffic to the EC2 NodePort; the Kubernetes Service routes traffic to the Pod.

Request flow:

```text
Internet
  -> AWS Application Load Balancer :80
  -> EC2 public instance :node_port
  -> kind NodePort Service
  -> demo app Pod
```

This is a demo stack, not a production Kubernetes architecture.

## Why The Stack Has Two Phases

Terraform provider configuration must be known before a provider can plan or apply resources. The Kubernetes provider needs a `kubeconfig`, but that kubeconfig only exists after EC2 is created and cloud-init finishes creating the kind cluster.

For that reason, the project uses two Terraform roots:

- `infra/`: creates AWS infrastructure and bootstraps kind.
- `app/`: uses the Kubernetes provider to deploy workloads after kubeconfig is ready.

The `scripts/deploy.ps1` wrapper combines both phases into one end-to-end deploy command.

## Repository Layout

```text
.
|-- infra/
|   |-- main.tf                 # VPC, EC2 kind host, ALB, target group
|   |-- security.tf             # ALB SG and EC2 SG rules
|   |-- iam.tf                  # IAM policy for EC2 to write kubeconfig to SSM
|   |-- templates/
|   |   `-- kind-user-data.sh.tftpl
|   `-- terraform.tfvars.example
|-- app/
|   |-- main.tf                 # Namespace, Deployment, NodePort Service
|   `-- terraform.tfvars.example
|-- scripts/
|   |-- deploy.ps1              # One-command full deploy
|   `-- destroy.ps1             # Destroy app first, then infra
|-- generated/                  # Local kubeconfig, git-ignored
`-- modules/
    |-- vpc/                    # Local wrapper module
    |-- ec2-instance/           # Local wrapper module
    `-- alb/                    # Local wrapper module
```

## Providers

- `infra/`
  - `hashicorp/aws`: creates AWS resources.
  - `hashicorp/http`: detects the operator public IPv4 address when `allowed_kubernetes_api_cidr = null`.
- `app/`
  - `hashicorp/kubernetes`: deploys Kubernetes resources into the kind cluster.

## Prerequisites

The following tools must be available on PATH:

- Terraform
- AWS CLI, authenticated to the target AWS account
- kubectl
- PowerShell

Quick check:

```powershell
terraform version
aws sts get-caller-identity
kubectl version --client=true
```

## Optional Configuration

Copy the example files if you want to customize values:

```powershell
Copy-Item infra\terraform.tfvars.example infra\terraform.tfvars
Copy-Item app\terraform.tfvars.example app\terraform.tfvars
```

Common `infra/terraform.tfvars` values:

```hcl
aws_region  = "ap-southeast-1"
name_prefix = "hungqt-tf-kind"

# Prefer restricting this to your IP. If null, Terraform detects your current public IPv4.
allowed_kubernetes_api_cidr = null

allowed_http_cidr = "0.0.0.0/0"
instance_type     = "t3.medium"
node_port         = 30080

tags = {
  Environment = "demo"
  Owner       = "hungqt"
}
```

Common `app/terraform.tfvars` values:

```hcl
namespace       = "demo"
app_name        = "demo-app"
replicas        = 1
container_image = "nginxinc/nginx-unprivileged:1.29-alpine"
```

You do not need to set `node_port` in `app/terraform.tfvars` when using the deploy script; the script reads `node_port` from the `infra/` output and passes it into the `app/` phase.

## Deploy Everything With One Command

```powershell
.\scripts\deploy.ps1
```

The script does the following:

1. Runs `terraform -chdir=infra init`.
2. Runs `terraform -chdir=infra apply -auto-approve`.
3. Waits for EC2 cloud-init to create the kind cluster and publish kubeconfig to SSM Parameter Store.
4. Reads the SSM `SecureString` and writes it to `generated/kubeconfig.yaml`.
5. Waits for the Kubernetes API to become reachable.
6. Runs `terraform -chdir=app init`.
7. Runs `terraform -chdir=app apply -auto-approve`.
8. Waits for the Kubernetes Deployment rollout.
9. Prints the ALB URL.

Use explicit var files:

```powershell
.\scripts\deploy.ps1 `
  -InfraVarFile="terraform.tfvars" `
  -AppVarFile="terraform.tfvars"
```

Skip init after the first successful init:

```powershell
.\scripts\deploy.ps1 -SkipInit
```

## Run Each Phase Independently

### Phase 1: Infra

```powershell
terraform -chdir=infra init
terraform -chdir=infra fmt -check
terraform -chdir=infra validate
terraform -chdir=infra plan -out=infra.tfplan
terraform -chdir=infra apply infra.tfplan
```

Read outputs needed by the `app/` phase:

```powershell
$Region = terraform -chdir=infra output -raw aws_region
$Param = terraform -chdir=infra output -raw kubeconfig_ssm_parameter_name
$NodePort = terraform -chdir=infra output -raw node_port
```

Wait for EC2 to create kubeconfig, then download it locally:

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

Check the app:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n demo get pods,svc
kubectl --kubeconfig generated\kubeconfig.yaml -n demo rollout status deployment/demo-app --timeout=5m
terraform -chdir=infra output -raw app_url
```

## Destroy

Use the script:

```powershell
.\scripts\destroy.ps1
```

Manual destroy by phase:

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

Destroy order matters: remove Kubernetes resources first, then remove EC2/ALB/VPC.

## Why The Service Is NodePort, Not LoadBalancer

This cluster is kind running inside one EC2 instance. It is not EKS and it does not have the AWS cloud controller or AWS Load Balancer Controller. If you change the Kubernetes Service to `type = "LoadBalancer"`, Kubernetes will usually leave `EXTERNAL-IP` as `<pending>`.

For kind on EC2, the correct pattern is:

```text
ALB -> EC2 NodePort -> Kubernetes Service -> Pod
```

If you need real `Service type = LoadBalancer` behavior, use EKS or install the right controller and redesign the IAM/networking model.

## Troubleshooting

SSM parameter is missing:

```powershell
$Region = terraform -chdir=infra output -raw aws_region
$Param = terraform -chdir=infra output -raw kubeconfig_ssm_parameter_name
aws ssm get-parameter --region $Region --name $Param --with-decryption
```

In the AWS Console, make sure you are in the correct region. The parameter path includes the leading slash, for example:

```text
/hungqt-tf-kind/kind/kubeconfig
```

Check EC2 and SSM Agent:

```powershell
$InstanceId = terraform -chdir=infra output -raw kind_host_instance_id
aws ssm describe-instance-information --region $Region --filters "Key=InstanceIds,Values=$InstanceId"
```

Fetch bootstrap logs through SSM:

```powershell
aws ssm send-command `
  --region $Region `
  --instance-ids $InstanceId `
  --document-name AWS-RunShellScript `
  --parameters 'commands=["cloud-init status --long","tail -n 240 /var/log/kind-bootstrap.log"]'
```

ALB target is unhealthy:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n demo get pods,svc
kubectl --kubeconfig generated\kubeconfig.yaml -n demo describe svc demo-app
```

Verify that `node_port` from `infra/` and `app/` match.

## Security Notes

- EC2 has no SSH ingress by default.
- ALB allows HTTP according to `allowed_http_cidr`.
- EC2 allows NodePort traffic only from the ALB security group.
- Kubernetes API access should be restricted to the operator IP. Use `allowed_kubernetes_api_cidr` to control this.
- Kubeconfig is stored in SSM as a `SecureString`, and the local `generated/kubeconfig.yaml` file is git-ignored.
- Do not commit `terraform.tfstate`, `.terraform/`, `*.tfplan`, or `generated/kubeconfig.yaml`.
