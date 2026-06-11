# Week 9 - GitOps, Observability, and Canary Rollouts

This document is used to submit evidence of completing the labs in two documents:

- `pdf/W9-sang-gitops-final.html` - Morning: GitOps and CI/CD.
- `pdf/W9-chieu-obs-canary.html` - Afternoon: Observability, Canary, and the "Ship Smartly" Challenge.

Practice Repository: `minikube-aws-sandbox`.

Deployment Environment:

- AWS EC2 running Docker and minikube.
- Terraform manages AWS infrastructure and publishes kubeconfig to AWS Systems Manager Parameter Store.
- Argo CD manages Kubernetes applications according to the GitOps model.
- Argo Rollouts manages canary rollouts.
- Prometheus collects metrics, evaluates SLOs, and sends alerts.

## Table of Contents

1. [Overview of Results](#1-overview-of-results)
2. [Deployed System Architecture](#2-deployed-system-architecture)
3. [Part I - Morning Lab: GitOps and CI/CD](#3-part-i---morning-lab-gitops-and-cicd)
4. [Part II - Afternoon Lab: Observability and Canary](#4-part-ii---afternoon-lab-observability-and-canary)
5. [Part III - Capstone Project: Ship Smartly](#5-part-iii---capstone-project-ship-smartly)
6. [Conclusion](#6-conclusion)

## 1. Overview of Results

| Requirement Group | Proof of Completion |
|---|---|
| Kubernetes Environment Setup | Terraform creates AWS infrastructure, EC2 bootstraps minikube, and kubeconfig is downloaded to `generated/kubeconfig.yaml`. |
| GitOps | Argo CD is installed in the cluster, and `ApplicationSet` auto-discovers production overlays in `argocd/apps/*/overlays/production`. |
| CI/CD | Git is the primary source of truth; GitHub Actions runs `kubectl kustomize` syntax checks for manifests. |
| Self-heal | When resources are scaled manually using `kubectl`, Argo CD detects drift and reconciles the cluster back to the state declared in Git. |
| Rollback | Rollback is executed using `git revert`, then Argo CD automatically synchronizes to the stable version. |
| Observability | Prometheus scrapes the backend production target at `/api/v1/metrics` and collects the `go_visit_requests_total` metric. |
| Canary | Frontend and backend use Argo Rollouts with a canary strategy. |
| SLO and Alerting | Prometheus has the `BackendSuccessRateSLOViolation` rule; Alertmanager sends an email when the success rate falls below 95%. |
| Auto-abort | Backend `AnalysisTemplate` reads Prometheus metrics and automatically aborts the canary when the success rate violates the SLO. |

![alt text](evidence/images/01.png)

*Figure 01: Overview of the cluster running Argo CD, the demo application, Prometheus, Argo Rollouts, and related resources.*

## 2. Deployed System Architecture

Main request traffic flow:

```text
User / Browser
  -> EC2 Public IPv4
  -> minikube Docker port mapping
  -> Kubernetes NodePort Service
  -> Frontend Pod
  -> Nginx reverse proxy /api/v1/
  -> Backend Service
  -> Backend Pod
  -> Redis StatefulSet
```

GitOps flow:

```text
Git repository
  -> Argo CD ApplicationSet
  -> Kustomize production overlays
  -> Kubernetes resources
  -> Argo Rollouts / Prometheus / app workloads
```

Important endpoints:

| Component | Port / Path | Purpose |
|---|---:|---|
| Frontend production | NodePort `30080` | Production application user interface. |
| Frontend development | NodePort `30081` | Infrastructure port pre-opened for the development environment; development overlays exist in Git, but the current `ApplicationSet` only auto-discovers production overlays. |
| Argo CD | NodePort `30443` | GitOps administration dashboard. |
| Prometheus | NodePort `39090` | Metric querying and alerting dashboard. |
| Kubernetes API | Host port `8443` | Access the cluster using kubeconfig. |
| Backend metrics | `/api/v1/metrics` on port `5000` | Custom metrics scraped by Prometheus. |

### 2.1. Infrastructure Context in `infra/`

The `infra/` folder creates the lab's underlying platform. Terraform does not directly manage Kubernetes workloads; it only creates AWS resources, bootstraps minikube, and publishes the kubeconfig so that subsequent steps can use `kubectl` and Argo CD.

| File / Folder | Role in the Lab |
|---|---|
| `infra/versions.tf` | Pins Terraform `>= 1.5.7, < 2.0`, AWS provider `>= 6.37, < 7.0`, and HTTP provider `>= 3.5, < 4.0`. |
| `infra/main.tf` | Creates a VPC with a public subnet and an EC2 instance running Docker/minikube using the local wrapper modules `modules/vpc` and `modules/ec2-instance`. |
| `infra/locals.tf` | Calculates operator CIDR, app CIDR, detects AMI based on `arm64`/`x86_64` architecture, names the SSM parameter for kubeconfig, and sets tags. |
| `infra/security.tf` | Opens necessary ports: Kubernetes API `8443`, app `30080`, development app `30081`, Argo CD `30443`, and Prometheus `39090`. |
| `infra/iam.tf` | Grants the EC2 instance permission to write exactly one SSM SecureString parameter containing the kubeconfig. |
| `infra/templates/minikube-user-data.sh.tftpl` | Installs Docker, minikube, and kubectl; starts minikube using the Docker driver; and publishes the kubeconfig to the SSM parameter store. |
| `infra/outputs.tf` | Outputs app URLs, Argo CD URL, instance public IP, kubeconfig SSM parameter name, API port, and NodePorts. |

Infrastructure validation commands:

```powershell
terraform -chdir=infra output
terraform -chdir=infra output -raw instance_public_ip
terraform -chdir=infra output -raw kubeconfig_ssm_parameter_name

$InstanceId = terraform -chdir=infra output -raw instance_id
$Region = terraform -chdir=infra output -raw aws_region
aws ssm send-command `
  --region $Region `
  --instance-ids $InstanceId `
  --document-name AWS-RunShellScript `
  --parameters 'commands=["systemctl status minikube-bootstrap --no-pager","tail -n 120 /var/log/minikube-bootstrap.log"]'
```

![alt text](evidence/images/02.png)

*Figure 02: Terraform output showing the public IP, URLs, NodePorts, Kubernetes API port, and the SSM parameter name containing the kubeconfig.*

![alt text](evidence/images/03.png)

*Figure 03: The EC2 minikube host's security group allowing the required ports for the lab: `8443`, `30080`, `30081`, `30443`, and `39090`.*

![alt text](evidence/images/04.png)

*Figure 04: `minikube-bootstrap.service` status and logs showing Docker/minikube starting successfully and publishing the kubeconfig to SSM.*

### 2.2. GitOps Context in `argocd/`

The `argocd/` folder contains the application delivery layer. This is where Argo CD is installed and where all application manifests synced by Argo CD reside.

| File / Folder | Role in the Lab |
|---|---|
| `argocd/install.ps1` | Installs Argo CD using `kubectl apply -k`, waits for CRDs and deployments to be ready, and applies the `ApplicationSet`. |
| `argocd/install/kustomization.yaml` | Deploys Argo CD v3.4.3 from upstream manifests, namespace, NodePort service, and git credential secrets. |
| `argocd/install/argocd-server-nodeport.yaml` | Exposes the Argo CD server using NodePort `30443`. |
| `argocd/install/github-private-repo-secret.yaml` | Declares repository credentials for Argo CD; tokens and passwords must be masked in screenshot evidence. |
| `argocd/bootstrap/apps-applicationset.yaml` | Declares the `sandbox` `AppProject` and the `sandbox-apps` `ApplicationSet`. |
| `argocd/apps/frontend` | Frontend Nginx, Service, NodePort overlay, and Argo Rollouts canary. |
| `argocd/apps/backend` | Go REST API backend, Service, Argo Rollouts canary, and `AnalysisTemplate` reading Prometheus metrics. |
| `argocd/apps/database` | Redis `StatefulSet` and `ClusterIP` Service. |
| `argocd/apps/prometheus` | Helm wrapper installing Prometheus, scrape configurations, alert rules, and Alertmanager. |
| `argocd/apps/argo-rollout` | Helm wrapper installing the Argo Rollouts controller. |

Key point of the current `ApplicationSet`:

```yaml
directories:
  - path: argocd/apps/*/overlays/production
```

Therefore, production is the environment auto-discovered and synced by default. Development overlays exist in the repository, and port `30081` is open, but to have development automatically synced by Argo CD, you would need to extend the generator or apply a separate Application for development.

GitOps validation commands:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get appproject sandbox
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get applicationset sandbox-apps
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get applications
```

![alt text](evidence/images/06.png)

*Figure 06: The `sandbox-apps` `ApplicationSet` scanning `argocd/apps/*/overlays/production` and generating production applications.*

Deployment and environment verification commands:

```powershell
.\scripts\deploy.ps1

kubectl --kubeconfig generated\kubeconfig.yaml get nodes -o wide
terraform -chdir=infra output -raw production_app_url
terraform -chdir=infra output -raw development_app_url
terraform -chdir=infra output -raw argocd_url
```

![alt text](evidence/images/01-terraform-apply-outputs.png)

*Figure 01: `deploy.ps1` completed successfully, Kubernetes API is reachable, and the URLs for the development app, production app, and Argo CD are printed.*

![alt text](evidence/images/07.png)

*Figure 02: `kubectl get nodes -o wide` shows the minikube node in a `Ready` state.*

## 3. Part I - Morning Lab: GitOps and CI/CD

### 3.1. Lab 0 - Spin up Cluster and Prepare Repository

The lab's objective is to have a Kubernetes cluster ready for Argo CD management with a Git repository hosting all manifests.

In this repository, the cluster is provisioned using Terraform and a PowerShell script:

```powershell
.\scripts\deploy.ps1
```

The script performs the following main actions:

- Runs `terraform -chdir=infra init`.
- Runs `terraform -chdir=infra apply -auto-approve`.
- Waits for EC2 to bootstrap Docker and minikube.
- Waits for the kubeconfig to be published as an SSM SecureString.
- Downloads the kubeconfig locally to `generated/kubeconfig.yaml`.
- Checks that the Kubernetes API is accessible.

Verification after completion:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml get nodes
kubectl --kubeconfig generated\kubeconfig.yaml get ns
```

![alt text](evidence/images/08-1.png)

![alt text](evidence/images/08.png)

*Figure 08: The kubeconfig in `generated/kubeconfig.yaml` successfully accesses the Kubernetes API and lists namespaces.*

### 3.2. Lab 1 - Install Argo CD

Argo CD is installed using the following script:

```powershell
.\argocd\install.ps1 `
  -RepoUrl "https://github.com/<org>/<repo>.git" `
  -TargetRevision "main"
```

This script installs Argo CD into the `argocd` namespace, exposes the server via NodePort `30443`, and applies the bootstrap manifest at `argocd/bootstrap/apps-applicationset.yaml`.

Verification:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get pods
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get svc
terraform -chdir=infra output -raw argocd_url
```

![alt text](evidence/images/09.png)

*Figure 09: Argo CD pods in the `argocd` namespace are running.*

![alt text](evidence/images/10.png)

*Figure 10: Argo CD UI dashboard accessed via the URL retrieved from Terraform outputs.*

### 3.3. Lab 2 - Create Applications and Sync from Git

Instead of applying each `Application` manually, the repository uses an `ApplicationSet` to discover production overlays:

```yaml
directories:
  - path: argocd/apps/*/overlays/production
```

The following applications are synchronized from Git:

- `frontend-production`
- `backend-production`
- `database-production`
- `prometheus-production`
- `argo-rollout-production`

Verification:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get applications
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get pods,svc,rollouts
```

![alt text](evidence/images/11.png)

*Figure 11: All `Application` resources created by the `ApplicationSet` are in a `Synced` and `Healthy` state.*

![alt text](evidence/images/12.png)

*Figure 12: The `demo-production` namespace contains the frontend, backend, database, and corresponding services.*

### 3.4. Lab 3 - Auto-Sync and Self-Heal

Verified GitOps principles:

- The desired state is stored in Git.
- Argo CD runs a reconciliation loop comparing Git with the actual cluster state.
- If drift is introduced by directly modifying resources using `kubectl`, Argo CD automatically reconciles them.

Self-heal testing scenario:

```powershell
# Manually introduce drift by scaling the backend replicas to 20.
kubectl --kubeconfig generated\kubeconfig.yaml `
  -n demo-production scale rollout/backend --replicas=20

# Monitor Argo CD / Kubernetes bringing the replicas back to the count declared in Git.
kubectl --kubeconfig generated\kubeconfig.yaml `
  -n demo-production get rollout backend -w
```

In the production overlay, the backend is patched to `replicas: 4`, so after Argo CD performs self-healing, the desired replica count must return to `4`.

![alt text](evidence/images/13.png)

*Figure 13: The backend is scaled manually to introduce drift from the state defined in Git.*

![alt text](evidence/images/14.png)

*Figure 14: Argo CD automatically brings the backend back to the desired state in Git.*

### 3.5. Lab 4 - Rollback via Git Revert

In GitOps, rollbacks must modify the source of truth in Git rather than editing the cluster directly.

Rollback procedure:

```powershell
git log --oneline -5
git revert HEAD --no-edit
git push origin main

kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get applications
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get pods,rollouts
```

Expected result:

- Git history contains a clear revert commit.
- Argo CD detects the new commit and syncs the cluster.
- The application rolls back to the stable state in under 5 minutes.

![alt text](evidence/images/15.png)

*Figure 15: Git history containing the revert commit used for rollback.*

![alt text](evidence/images/16.png)

![alt text](evidence/images/16-1.png)

*Figure 16: Argo CD synchronizes the revert commit and the application returns to a `Synced` / `Healthy` state.*

### 3.6. Lab 5 - App-of-Apps Pattern via ApplicationSet

The lab requires managing multiple applications via a single root controller. In this repository, this is implemented using an `ApplicationSet`:

- `AppProject` named `sandbox` restricts target namespaces, source repositories, and allowed cluster resources.
- `ApplicationSet` named `sandbox-apps` scans the `argocd/apps/*/overlays/production` path.
- When a new application is added to the folder structure and pushed to Git, Argo CD automatically creates the corresponding `Application`.

Verification:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get appproject sandbox -o yaml
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get applicationset sandbox-apps -o yaml
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get applications
```

![alt text](evidence/images/17.png)

*Figure 17: The `ApplicationSet` generates and manages multiple Argo CD `Application` resources based on the Git folder structure.*

### 3.7. Lab 6 - Sync Waves and Deployment Order

The bootstrap manifests use sync waves to ensure a logical deployment order:

- `AppProject` has the annotation `argocd.argoproj.io/sync-wave: "-1"`.
- `ApplicationSet` has the annotation `argocd.argoproj.io/sync-wave: "0"`.

This ensures that the `sandbox` project exists before the `ApplicationSet` attempts to create applications belonging to it.

The `ApplicationSet` also configures sync options:

- `CreateNamespace=true`
- `ServerSideApply=true`
- `RespectIgnoreDifferences=true`

Verification:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get appproject sandbox -o yaml
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get applicationset sandbox-apps -o yaml
```

![alt text](evidence/images/18.png)

![alt text](evidence/images/18-1.png)

*Figure 18: Sync wave annotations proving the bootstrap resources are applied in the correct sequence.*

### 3.8. Lab 7 - CI Manifest Validation

The repository includes a GitHub Actions workflow at `.github/workflows/manifests-validation.yaml`.

The workflow runs on push or pull request events affecting YAML files under:

- `argocd/**/*.yaml`
- `argocd/**/*.yml`
- `argocd-classic/**/*.yaml`
- `argocd-classic/**/*.yml`

The `Validate Manifests Syntax` job runs:

```bash
find . -name "kustomization.yaml" -not -path "*/.terraform/*" | while read -r file; do
  dir=$(dirname "$file")
  kubectl kustomize "$dir" > /dev/null
done
```

Expected result:

- Pull requests with syntax-invalid manifests will fail.
- Pull requests can only be merged once validation passes.
- Git controls changes before they are synced by Argo CD.

![alt text](evidence/images/19.png)

*Figure 19: The `Validate ArgoCD Manifests` workflow running successfully on GitHub Actions.*

## 4. Part II - Afternoon Lab: Observability and Canary

### 4.1. Lab 1 - Install Prometheus and Argo Rollouts via GitOps

Prometheus and Argo Rollouts are managed as standard GitOps applications in the repository:

- `argocd/apps/prometheus/overlays/production`
- `argocd/apps/argo-rollout/overlays/production`

When the `ApplicationSet` syncs, these two components are deployed in the cluster.

Verification:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get applications
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get pods
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get svc prometheus-production-server
```

![alt text](evidence/images/20.png)

*Figure 20: Prometheus production exposed via NodePort `39090`.*

![alt text](evidence/images/21.png)

*Figure 21: Argo CD displaying the Prometheus and Argo Rollouts applications successfully synced.*

![alt text](evidence/images/22.png)

*Figure 22: Prometheus UI accessed via NodePort `39090`.*

### 4.2. Lab 2 - Backend Custom Metrics Exposition

The Go backend exposes the following endpoints:

- `POST /api/v1/visit` - records a page visit in Redis for a specific user.
- `GET /api/v1/metrics` - exposes Prometheus metrics.
- `GET /healthz` - health check probe endpoint.

Key custom metrics:

```text
go_visit_requests_total{status="200"}
go_visit_requests_total{status="400"}
go_visit_requests_total{status="401"}
go_visit_requests_total{status="500"}
go_visit_users_active_total
```

Send requests to generate traffic data:

```powershell
$AppUrl = terraform -chdir=infra output -raw production_app_url
$Body = @{ username = "demo-user"; password = "demo-pass" } | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "$($AppUrl.TrimEnd('/'))/api/v1/visit" `
  -Body $Body `
  -ContentType "application/json"
```

Verify metrics output:

```powershell
Invoke-WebRequest "$($AppUrl.TrimEnd('/'))/api/v1/metrics"
```

![alt text](evidence/images/23.png)

*Figure 23: The `/api/v1/visit` API returning a successful response and incrementing visits.*

![alt text](evidence/images/24.png)

*Figure 24: The `/api/v1/metrics` endpoint displaying `go_visit_requests_total` and `go_visit_users_active_total`.*

### 4.3. Lab 3 - Prometheus Metrics Scraping and SLI Querying

Prometheus production scrapes backend pods using `extraScrapeConfigs`:

```yaml
job_name: 'backend'
metrics_path: '/api/v1/metrics'
static_configs:
  - targets:
      - 'backend.demo-development.svc.cluster.local:5000'
      - 'backend.demo-production.svc.cluster.local:5000'
```

In the primary evidence, you must show the `backend.demo-production.svc.cluster.local:5000` target in an `UP` state. The development target might show as `DOWN` if you haven't synchronized the development overlay, since the current `ApplicationSet` only auto-discovers production overlays.

PromQL queries used for validation:

```promql
go_visit_requests_total
```

```promql
sum(rate(go_visit_requests_total{status="200"}[5m]))
/
sum(rate(go_visit_requests_total[5m]))
```

![alt text](evidence/images/25.png)

*Figure 25: Prometheus Targets showing the backend production scrape target in an `UP` state.*

![alt text](evidence/images/26.png)

*Figure 26: Prometheus query showing the success rate of the backend based on `go_visit_requests_total`.*

### 4.4. Lab 4 - Manual Canary Rollout

The frontend uses Argo Rollouts with a canary strategy:

```yaml
steps:
  - setWeight: 25
  - pause: { duration: 1s }
  - setWeight: 50
  - pause: {}
  - setWeight: 100
```

Explanation:

- The new version is routed 25% of traffic.
- It is then promoted to 50% traffic.
- At 50%, the rollout pauses indefinitely for operator validation.
- If stable, run `promote`; if issues arise, run `abort`.

Verification commands:

```powershell
kubectl argo rollouts get rollout frontend -n demo-production --watch
kubectl argo rollouts promote frontend -n demo-production
kubectl argo rollouts abort frontend -n demo-production
```

![alt text](evidence/images/27.png)

*Figure 27: Argo Rollouts showing the backend paused at the canary step awaiting a manual decision.*

![alt text](evidence/images/28.png)

*Figure 28: After promotion, the backend canary proceeds to 100% and returns to a healthy status.*

## 5. Part III - Capstone Project: Ship Smartly

The challenge requires integrating three components:

1. Changes made via Git and synced automatically by Argo CD.
2. SLO definitions and email alerts sent when SLO is violated.
3. Canary deployments automatically aborted based on Prometheus metrics.

### 5.1. Reproducible GitOps Proof

All production resources are declared in Git:

- Frontend: `argocd/apps/frontend/overlays/production`
- Backend: `argocd/apps/backend/overlays/production`
- Database: `argocd/apps/database/overlays/production`
- Prometheus: `argocd/apps/prometheus/overlays/production`
- Argo Rollouts: `argocd/apps/argo-rollout/overlays/production`

Verification:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get applications
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get all
```

![alt text](evidence/images/29.png)

*Figure 29: The production stack managed by Argo CD, reproducible directly from Git.*

### 5.2. SLO and Email Alerting Proof

Backend SLO:

```text
HTTP 200 success rate must be >= 95%.
```

Prometheus alert rule:

```promql
(sum(rate(go_visit_requests_total{status="200"}[5m])) or vector(1))
/
(sum(rate(go_visit_requests_total[5m])) or vector(1)) < 0.95
```

Alert details:

- Name: `BackendSuccessRateSLOViolation`
- Threshold: Success rate falls below `0.95`
- Duration: `for: 1m`
- Severity: `critical`
- Receiver: Personal email configured via Alertmanager SMTP

Scenario to trigger the alert:

```powershell
$AppUrl = terraform -chdir=infra output -raw production_app_url

# First, register a valid user.
$GoodBody = @{ username = "slo-demo"; password = "correct-pass" } | ConvertTo-Json
Invoke-RestMethod `
  -Method Post `
  -Uri "$($AppUrl.TrimEnd('/'))/api/v1/visit" `
  -Body $GoodBody `
  -ContentType "application/json"

# Send a large volume of requests with an incorrect password to trigger HTTP 401s and degrade the success rate.
$BadBody = @{ username = "slo-demo"; password = "wrong-pass" } | ConvertTo-Json
1..200 | ForEach-Object {
  try {
    Invoke-RestMethod `
      -Method Post `
      -Uri "$($AppUrl.TrimEnd('/'))/api/v1/visit" `
      -Body $BadBody `
      -ContentType "application/json"
  } catch {
    # Ignore exceptions to continue generating error traffic.
  }
}
```

![alt text](evidence/images/30.png)

*Figure 30: Prometheus displaying the `BackendSuccessRateSLOViolation` alert in a `FIRING` state.*

![alt text](evidence/images/31.png)

*Figure 31: The alert email notification received in the personal inbox.*

### 5.3. Automated Canary Rollback via AnalysisTemplate Proof

The backend uses an `AnalysisTemplate` named `backend-success-rate`.

Core configuration:

```yaml
metrics:
  - name: success-rate
    interval: 10s
    successCondition: result[0] >= 0.95
    failureLimit: 2
    provider:
      prometheus:
        address: http://prometheus-production-server.demo-production.svc.cluster.local:80
```

Analysis query:

```promql
sum(rate(go_visit_requests_total{status="200"}[1m])) or vector(1)
/
(sum(rate(go_visit_requests_total[1m])) or vector(1))
```

The backend rollout binds this template under its canary strategy:

```yaml
strategy:
  canary:
    analysis:
      templates:
        - templateName: backend-success-rate
    steps:
      - setWeight: 25
      - pause: { duration: 30s }
      - setWeight: 50
      - pause: { duration: 30s }
      - setWeight: 100
```

Expected result:

- If the success rate remains >= 95%, the rollout proceeds up to 100%.
- If the success rate falls < 95% for a number of checks exceeding `failureLimit`, the `AnalysisRun` fails.
- Once the `AnalysisRun` fails, the rollout becomes degraded and the canary version is automatically aborted.

Monitoring commands:

```powershell
kubectl argo rollouts get rollout backend -n demo-production --watch
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get analysisrun
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production describe analysisrun
```

![alt text](evidence/images/32.png)

![alt text](evidence/images/32-1.png)

*Figure 32: The backend `AnalysisRun` querying Prometheus to evaluate the success rate.*

![alt text](evidence/images/33.png)

*Figure 33: The `AnalysisRun` failed because the metric did not satisfy the `result[0] >= 0.95` condition.*

![alt text](evidence/images/34.png)

*Figure 34: The backend rollout automatically aborting the faulty canary version, preventing it from reaching 100%.*

## 6. Conclusion

The labs and challenges have been completed successfully in accordance with the core principles of Week 9:

- Git is the single source of truth for all Kubernetes manifests.
- Argo CD automatically synchronizes manifests, detects drift, and performs self-healing.
- Rollback is performed cleanly via Git revert, maintaining a clear audit trail.
- Prometheus scrapes and monitors custom application metrics directly from the backend.
- SLOs are defined using PromQL, and Alertmanager sends email notifications on SLO violations.
- Argo Rollouts uses a canary strategy to release new versions progressively and implements `AnalysisTemplate` to automatically abort faulty releases.

This evidence pack serves as the submission framework. Once you place the screenshots in the placeholders above, this document will fully substantiate your completion of the morning labs, afternoon labs, and the "Ship Smartly" capstone challenge.
