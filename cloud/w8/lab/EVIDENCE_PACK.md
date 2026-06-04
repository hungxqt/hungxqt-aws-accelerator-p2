# Evidence pack - Demo Terraform AWS kind ALB

Last updated: 2026-06-04

[Tiếng Việt](EVIDENCE_PACK_vi.md)

This evidence pack documents how the project satisfies the requirement:

> Create one EC2 instance, run a local Kubernetes cluster with kind or
> minikube, deploy a lightweight app into Kubernetes, expose the app to the
> Internet through an AWS Application Load Balancer, and automate the full flow
> with Terraform using at least two Terraform providers.

## 1. Project Overview

This repository builds a small Kubernetes-on-AWS demo with Terraform.

- `infra/` creates AWS infrastructure: VPC, public subnets, EC2, IAM role, security groups, Application Load Balancer, listener, target group, and target attachment.
- EC2 is bootstrapped with `user_data` to install Docker, kind, kubectl, and create a single-node kind cluster.
- EC2 writes the generated kubeconfig to AWS Systems Manager Parameter Store as a `SecureString`.
- `scripts/deploy.ps1` downloads that kubeconfig to `generated/kubeconfig.yaml`.
- `app/` uses the Terraform Kubernetes provider to deploy the app into the kind cluster as a Deployment and expose it with a NodePort Service.
- ALB forwards Internet traffic to the EC2 NodePort, then Kubernetes routes traffic to the app Pod.

Current project configuration values:

| Item | Value |
|---|---|
| AWS region | `ap-southeast-1` |
| Name prefix | `hungqt-tf-kind` |
| Kubernetes distribution | `kind` |
| kind cluster name | `terraform-demo` |
| EC2 instance type | `t3.medium` |
| NodePort | `30080` |
| Kubernetes namespace | `demo` |
| Kubernetes app name | `demo-app` |
| Container image | `nginxinc/nginx-unprivileged:1.29-alpine` |
| SSM kubeconfig parameter | `/hungqt-tf-kind/kind/kubeconfig` |
| One-step deploy command | `.\scripts\deploy.ps1` |
| Destroy command | `.\scripts\destroy.ps1` |

## 2. Architecture Evidence

![alt text](evidence/images/architecture.png)

Request flow:

```text
Internet
  -> AWS Application Load Balancer :80
  -> EC2 public instance :30080
  -> kind NodePort Service :30080
  -> Kubernetes Deployment Pod :8080
```

Terraform/provider flow:

```text
scripts/deploy.ps1
  -> terraform -chdir=infra apply
  -> EC2 cloud-init creates kind and writes kubeconfig to SSM
  -> script downloads SSM SecureString to generated/kubeconfig.yaml
  -> terraform -chdir=app apply uses Kubernetes provider
```

## 3. Requirement Compliance Matrix

| Requirement | How the project satisfies it |
|---|---|
| Infrastructure is created by Terraform | Terraform root `infra/` creates VPC, EC2, IAM, security groups, ALB, target group, listener, and target attachment through the AWS provider. |
| One EC2 host runs Kubernetes locally | EC2 `user_data` installs Docker, kind, and kubectl, then creates a single-node kind cluster. |
| App runs inside Kubernetes | Terraform root `app/` creates a Kubernetes Namespace, Deployment, and NodePort Service through the Kubernetes provider. |
| App is not installed directly on EC2 | EC2 only runs Docker/kind; the HTTP workload is the Kubernetes Deployment using image `nginxinc/nginx-unprivileged:1.29-alpine`. |
| App is reachable from the Internet through ALB | ALB listener forwards to a target group pointing at EC2 NodePort `30080`; the Service routes requests to the Pod. |
| One-command automation | `.\scripts\deploy.ps1` runs infra apply, waits for SSM kubeconfig, runs app apply, waits for rollout, and prints the ALB URL. |
| Uses at least two Terraform providers | `infra/` uses `hashicorp/aws` and `hashicorp/http`; `app/` uses `hashicorp/kubernetes`. |
| Wires another provider dynamically | The Kubernetes provider reads `generated/kubeconfig.yaml`, which is produced from infra output and EC2 bootstrap through SSM. |

## 4. One-Command Deployment Evidence

Command:

```powershell
.\scripts\deploy.ps1
```

![alt text](evidence/images/image-3.png)

![alt text](evidence/images/image-4.png)

This proves:

- Terraform initializes and applies the AWS infrastructure root.
- EC2 bootstrap creates kind and publishes kubeconfig to SSM.
- The script downloads kubeconfig to `generated/kubeconfig.yaml`.
- Terraform initializes and applies the Kubernetes app root.
- The script waits for Deployment rollout and prints the ALB URL.

## 5. Provider Wiring Evidence

Infra providers:

```powershell
terraform -chdir=infra providers
```

![alt text](evidence/images/image-1.png)

Description:

- Uses AWS provider `registry.terraform.io/hashicorp/aws`
- Uses http provider `registry.terraform.io/hashicorp/http`
- Local wrapper modules in `modules/`
- Upstream AWS modules for VPC, EC2 instance, and ALB

App provider:

```powershell
terraform -chdir=app providers
```

![alt text](evidence/images/image-2.png)

Description:

- Uses Kubernetes provider `registry.terraform.io/hashicorp/kubernetes`

Provider bridge:

```text
infra output kubeconfig_ssm_parameter_name
  -> EC2 user_data writes kubeconfig to SSM SecureString
  -> scripts/deploy.ps1 downloads SSM value to generated/kubeconfig.yaml
  -> app provider "kubernetes" uses var.kubeconfig_path
```

Code evidence:

- `infra/outputs.tf` exposes `kubeconfig_ssm_parameter_name`, `node_port`, and
  `app_url`.
- `infra/templates/kind-user-data.sh.tftpl` runs `aws ssm put-parameter`.
- `scripts/deploy.ps1` reads infra outputs and fetches the SSM parameter.
- `app/versions.tf` configures `provider "kubernetes"` with
  `config_path = var.kubeconfig_path`.

## 6. AWS Runtime Evidence

Capture metadata only. Do not print kubeconfig contents.

SSM parameter metadata:

```powershell
aws ssm get-parameter ^
  --region ap-southeast-1 ^
  --name /hungqt-tf-kind/kind/kubeconfig ^
  --with-decryption ^
  --query "Parameter.{Name:Name,Type:Type,Version:Version,LastModifiedDate:LastModifiedDate}" ^
  --output json
```

![alt text](evidence/images/image-5.png)

Description:

- `Name` is `/hungqt-tf-kind/kind/kubeconfig`.
- `Type` is `SecureString`.
- `Version` is present.

EC2 instance:

```powershell
$InstanceId = terraform -chdir=infra output -raw kind_host_instance_id
aws ec2 describe-instances `
  --region ap-southeast-1 `
  --instance-ids $InstanceId `
  --query "Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,PublicIpAddress:PublicIpAddress,IamInstanceProfile:IamInstanceProfile.Arn}" `
  --output table
```

![alt text](evidence/images/image-6.png)

Description:

- Instance state is `running`.
- Instance has an IAM instance profile.
- Instance has a public IP.

ALB target health:

```powershell
$TargetGroupName = "hungqt-tf-kind-tg"
$TargetGroupArn = aws elbv2 describe-target-groups `
  --region ap-southeast-1 `
  --names $TargetGroupName `
  --query "TargetGroups[0].TargetGroupArn" `
  --output text

aws elbv2 describe-target-health `
  --region ap-southeast-1 `
  --target-group-arn $TargetGroupArn `
  --query "TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}" `
  --output table
```

![alt text](evidence/images/image-7.png)

Description:

- Target is the EC2 instance.
- Port is `30080`.
- State is `healthy`.

## 7. Kubernetes Runtime Evidence

Fetch kubeconfig from SSM:

```powershell
$Region = terraform -chdir=infra output -raw aws_region
$Param = terraform -chdir=infra output -raw kubeconfig_ssm_parameter_name
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
```

![alt text](evidence/images/image-8.png)

![alt text](evidence/images/image-9.png)

Confirm node readiness:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml get nodes -o wide
```

![alt text](evidence/images/image-10.png)

Description:

- One kind control-plane node is listed.
- `STATUS` is `Ready`.
- Kubernetes version matches the configured kind node image.

Confirm app resources:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n demo get pods,svc -o wide
```

![alt text](evidence/images/image-11.png)

Description:

- Pod `demo-app` is `Running`.
- Service `demo-app` has type `NodePort`.
- Service exposes `80:30080/TCP`.

Confirm rollout:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n demo rollout status deployment/demo-app --timeout=5m
```

![alt text](evidence/images/image-12.png)

Description:

- Output contains `deployment "demo-app" successfully rolled out`.

## 8. Public Access Evidence

Get the public URL:

```powershell
$AppUrl = terraform -chdir=infra output -raw app_url
$AppUrl
```

![alt text](evidence/images/image-13.png)

Verify HTTP 200:

```powershell
$Response = Invoke-WebRequest -Uri $AppUrl -UseBasicParsing -TimeoutSec 30
$Response.StatusCode
$Response.Content.Split("`n")[0..4]
```

![alt text](evidence/images/image-14.png)

Description:

- Status code is `200`.
- Response contains the nginx welcome page HTML.
- The request is sent to the ALB DNS name, not the EC2 public IP.

## 9. Validation Evidence

```powershell
terraform -chdir=infra fmt -check
terraform -chdir=infra validate
terraform -chdir=app fmt -check
terraform -chdir=app validate
```

![alt text](evidence/images/image-15.png)

Description:

- All commands run successfully.
- `validate` prints `Success! The configuration is valid.`

## 10. Security Evidence

Security controls to mention during review:

- EC2 has no SSH ingress by default.
- ALB accepts HTTP according to `allowed_http_cidr`.
- EC2 accepts NodePort traffic only from the ALB security group.
- Kubernetes API access is restricted by `allowed_kubernetes_api_cidr`; when this value is `null`, Terraform detects the operator public IPv4 and only allows that `/32` CIDR.
- Kubeconfig is stored in SSM Parameter Store as a `SecureString`.
- `generated/kubeconfig.yaml`, `.terraform/`, `*.tfstate`, `*.tfplan`, and `terraform.tfvars` are ignored by Git.
- The demo container uses `nginxinc/nginx-unprivileged:1.29-alpine`, runs as a non-root user, drops Linux capabilities, and disallows privilege escalation.

Redaction scan before sharing:

```powershell
rg -n "client-[k]ey-data|client-certificate-[d]ata|BEGIN .*PRIVATE [K]EY|aws_secret_access_[k]ey|A[K]IA|A[S]IA" EVIDENCE_PACK.md evidence
```

Expected result:

- No matches.

## 11. Cleanup Evidence

Destroy command:

```powershell
.\scripts\destroy.ps1
```

![alt text](evidence/images/image-16.png)

![alt text](evidence/images/image-17.png)

Description:

- Kubernetes resources are destroyed before AWS infrastructure.
- The SSM kubeconfig parameter is deleted.
- EC2, ALB, target group, security groups, and VPC resources are removed.

Manual destroy sequence if needed:

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

Destroy order is important: remove Kubernetes resources first, then remove EC2, ALB, and VPC infrastructure.
