# Argo CD

This folder contains the Argo CD installation overlay, the Argo CD `ApplicationSet` bootstrap resource, and the demo app manifests that Argo CD syncs.

## Layout

```text
argocd/
|-- install/                 # Argo CD install overlay and NodePort Service
|-- bootstrap/               # Argo CD ApplicationSet bootstrap resource
|-- apps/                    # Wrappers & applications synced by Argo CD
|-- install.ps1              # Installs Argo CD and applies the ApplicationSet
|-- uninstall.ps1            # Removes Argo CD from the remote cluster
```

## Install

### 1. Spin up the cluster
First create or refresh the minikube host and kubeconfig:

```powershell
.\scripts\deploy.ps1
```

### 2. Upload your credentials to AWS Secrets Manager
This codebase uses the External Secrets Operator (ESO) to retrieve credentials (your GitHub PAT and SMTP password) from AWS Secrets Manager so they are not stored in the repository.

1. Ensure your AWS credentials are configured locally.
2. Run the helper script to upload your secrets:
   ```powershell
   .\scripts\upload-secrets-to-aws.ps1
   ```

### 3. Deploy Argo CD
After uploading your secrets, install Argo CD and register this repo as the source for the demo app environments:

```powershell
.\argocd\install.ps1 `
  -RepoUrl "https://github.com/YOUR_ORG/YOUR_REPO.git" `
  -TargetRevision "main"
```

Argo CD reads the app stack from:

```text
argocd/apps/frontend/overlays/production    # Frontend UI (Rollout canary, NodePort 30080)
argocd/apps/backend/overlays/production     # Go Backend (Rollout canary + AnalysisTemplate)
argocd/apps/database/overlays/production    # Redis DB (StatefulSet)
argocd/apps/prometheus/overlays/production  # Prometheus server (NodePort 39090)
argocd/apps/argo-rollout/overlays/production# Argo Rollouts controller
argocd/apps/metrics-server/overlays/production# Kubernetes Metrics Server
```

## Uninstall

Remove Argo CD from the remote minikube cluster (leaving the demo app workloads running):

```powershell
.\argocd\uninstall.ps1
```

Remove only the demo app workload resources (keeping Argo CD intact):

```powershell
.\argocd\uninstall.ps1 -DeleteApps
```

The script uses `generated\kubeconfig.yaml` by default. Use `-KubeconfigPath` if you want to target a different kubeconfig.

## Access

Terraform exposes the Argo CD server on the fixed NodePort from `infra/outputs.tf`:

```powershell
terraform -chdir=infra output -raw argocd_url
```

The server uses its default self-signed certificate, so your browser may warn on first access.

Get the initial admin password:

```powershell
$PasswordB64 = kubectl --kubeconfig generated\kubeconfig.yaml -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($PasswordB64))
```

Username:

```text
admin
```

## Notes

- `argocd/bootstrap/apps-applicationset.yaml` contains `REPLACE_WITH_REPOSITORY_URL` and `REPLACE_WITH_TARGET_REVISION` placeholders; `install.ps1` replaces them in memory when applying.
- Argo CD UI/API access defaults to your operator CIDR, not `0.0.0.0/0`.
- Terraform no longer manages the demo namespaces or app resources; those live under `argocd/apps/`.
- `uninstall.ps1` removes Argo CD only by default; pass `-DeleteApps` to delete the synced app resources without removing Argo CD.
