## Week 10 - Secure & Operate: RBAC, Admission, Secrets, Supply Chain

This evidence pack documents the Week 10 work for RBAC, admission policy, secrets management, supply-chain security, and the adapted multi-tenant challenge in the `minikube-aws-sandbox` repository.

- `pdf/w10_morning_rbac_admission.html` - Morning: RBAC and Admission Policy.
- `pdf/w10_afternoon_secrets_supply_chain.html` - Afternoon: Secrets, Supply Chain, Platform Integration, and Challenge.

Repository: `minikube-aws-sandbox`.

Environment:

- AWS EC2 runs Docker and minikube.
- Terraform provisions the EC2 host, security group, IAM permissions, and kubeconfig publication.
- Argo CD manages Kubernetes resources from Git through `argocd/bootstrap/apps-applicationset.yaml`.
- Gatekeeper, External Secrets Operator, Sigstore policy-controller, and Calico provide the Week 10 controls.

## Table of Contents

1. [Result Summary](#1-result-summary)
2. [Current Platform Architecture](#2-current-platform-architecture)
3. [Part I - Morning Lab: RBAC and Admission Policy](#3-part-i---morning-lab-rbac-and-admission-policy)
4. [Part II - Afternoon Lab: Secrets and Supply Chain](#4-part-ii---afternoon-lab-secrets-and-supply-chain)
5. [Part III - Challenge: Adapted Tenant Isolation](#5-part-iii---challenge-adapted-tenant-isolation)
6. [Conclusion](#6-conclusion)

## 1. Result Summary

| Requirement group | Evidence status |
|---|---|
| RBAC roles | Implemented through GitOps using `argocd/apps/rbac` and `argocd/apps/team-rbac`. |
| RBAC verification | Verified with `kubectl auth can-i` impersonation checks. |
| Gatekeeper admission policy | Implemented with Gatekeeper operator and constraints under `argocd/apps/gatekeeper-policies`. |
| Required manifest guardrails | Enforces required labels, allowed registries, no `:latest`, resource limits, non-root user, and no `hostNetwork`. |
| External Secrets Operator | ESO is installed during Argo CD bootstrap and active `ExternalSecret` manifests exist. |
| Secret rotation target | Partial: current Redis secret uses `refreshInterval: "1h"` and is consumed through env/args, so it does not prove `< 60s` no-restart rotation. |
| Trivy scan | Partial: Trivy scans run in CI and upload artifacts, but current `exit-code: "0"` means findings are reporting-only. |
| Cosign signing | Implemented in CI using Cosign and AWS Secrets Manager-stored signing material. |
| Admission signature verification | Implemented through Sigstore policy-controller and `ClusterImagePolicy`. |
| Challenge tenant | Implemented as the adapted `demo-development` tenant rather than the slide's `payments` tenant. |
| Challenge quota and LimitRange | Implemented: `ResourceQuota` and `LimitRange` configurations exist under the `tenant-namespaces` application. |
| Challenge network isolation | Implemented with Calico-enabled minikube and NetworkPolicy manifests. |

![alt text](evidence/images/w10/1.png)

*Figure 01: Argo CD manages the Week 10 platform applications from Git.*

## 2. Current Platform Architecture

The platform runs on an AWS EC2 instance bootstrapped by Terraform. The EC2 user-data starts minikube with Docker and Calico, publishes kubeconfig to AWS Systems Manager Parameter Store, and exposes the ports used by the lab.

The Kubernetes application layer is managed by Argo CD. The important bootstrap object is `argocd/bootstrap/apps-applicationset.yaml`; it scans `argocd/apps/*/overlays/*` and creates one Argo CD `Application` per overlay. This means `production` and `development` overlays can both become GitOps-managed applications.

The active tenant namespaces are:

| Namespace | Purpose | Security labels |
|---|---|---|
| `demo-production` | Existing production application namespace. | `platform.xbrain.dev/security-profile=demo-restricted`, `policy.sigstore.dev/include=true` |
| `demo-development` | Adapted challenge tenant namespace. | `platform.xbrain.dev/security-profile=demo-restricted`, `policy.sigstore.dev/include=true` |

### 2.1. Infrastructure Context

| File / directory | Role in Week 10 evidence |
|---|---|
| `infra/templates/minikube-user-data.sh.tftpl` | Starts minikube with `--cni=calico`, which is required for NetworkPolicy enforcement. |
| `infra/security.tf` | Opens the operator and application ports needed for lab access. |
| `infra/iam.tf` | Grants narrowly scoped AWS access, including secrets used by Cosign and ESO flows. |
| `infra/outputs.tf` | Exposes the URLs, public IP, and kubeconfig SSM parameter used in evidence commands. |

### 2.2. GitOps Context

| File / directory | Role in Week 10 evidence |
|---|---|
| `argocd/bootstrap/apps-applicationset.yaml` | Discovers application overlays and assigns sync waves and destinations. |
| `argocd/apps/rbac` | Defines cluster-level developer/SRE/viewer RBAC from the morning lab. |
| `argocd/apps/team-rbac` | Defines namespace-scoped developer access for tenant overlays. |
| `argocd/apps/gatekeeper-operator` | Installs OPA Gatekeeper. |
| `argocd/apps/gatekeeper-policies` | Defines admission constraints. |
| `argocd/apps/database` | Defines Redis plus `ExternalSecret` for credentials. |
| `argocd/apps/policy-controller` | Installs Sigstore policy-controller. |
| `argocd/apps/cosign-policies` | Defines `ClusterImagePolicy` objects for signature admission. |
| `argocd/apps/network-policies` | Defines tenant network egress isolation. |
| `argocd/apps/tenant-namespaces` | Owns tenant namespaces and security labels. |

![alt text](evidence/images/w10/2.png)

*Figure 02: The tenant namespaces carry the labels that activate Gatekeeper and Sigstore policy-controller.*

## 3. Part I - Morning Lab: RBAC and Admission Policy

### 3.1. Lab 1.1 - RBAC Through GitOps

The morning lab requires three roles: developer, SRE, and viewer. In this repository, the RBAC implementation is split between cluster-wide RBAC and tenant-scoped team RBAC.

| Slide role | Repo identity | Main permission boundary |
|---|---|---|
| Developer | `oidc:demo-developers` and tenant-specific developer groups | Workload management in the assigned namespace only. |
| SRE | `oidc:demo-sres` | Pod operation across namespaces through `demo-sre` ClusterRole. |
| Viewer | `oidc:demo-viewers` | Read-only access across common workload and platform resources. |

Relevant files:

| File | Role / Details |
|---|---|
| `argocd/apps/rbac/base/clusterroles.yaml` | ClusterRole definitions for SRE and viewer. |
| `argocd/apps/rbac/base/clusterrolebindings.yaml` | SRE and viewer ClusterRoleBindings. |
| `argocd/apps/team-rbac/base/role.yaml` | Tenant developer role used by environment overlays. |
| `argocd/apps/team-rbac/overlays/development/rolebinding.yaml` | Development tenant binding for the adapted challenge. |

RBAC validation commands:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i create deployments -n demo-production --as=demo-developer --as-group=oidc:demo-developers
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i create deployments -n kube-system --as=demo-developer --as-group=oidc:demo-developers
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i get pods -A --as=demo-sre --as-group=oidc:demo-sres
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i delete nodes --as=demo-viewer --as-group=oidc:demo-viewers
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i get secrets -n demo-development --as=demo-development-developer --as-group=oidc:demo-development-developers
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i create rolebindings -n demo-development --as=demo-development-developer --as-group=oidc:demo-development-developers
```

Expected evidence results:

| Check | Expected result |
|---|---|
| Developer creates workload in assigned namespace | `yes` |
| Developer creates workload in `kube-system` | `no` |
| SRE reads pods across namespaces | `yes` |
| Viewer deletes nodes | `no` |
| Development tenant developer reads secrets | `no` |
| Development tenant developer creates rolebindings | `no` |

![alt text](evidence/images/w10/3-1.png)

![alt text](evidence/images/w10/3-2.png)

![alt text](evidence/images/w10/3-3.png)

*Figure 03: RBAC manifests define developer, SRE, viewer, and tenant developer permissions in Git.*

![alt text](evidence/images/w10/4-1.png)

![alt text](evidence/images/w10/4-2.png)

![alt text](evidence/images/w10/4-3.png)

![alt text](evidence/images/w10/4-4.png)

![alt text](evidence/images/w10/4-5.png)

![alt text](evidence/images/w10/4-6.png)

*Figure 04: `kubectl auth can-i` verifies the allowed and denied RBAC paths.*

### 3.2. Lab 1.2 - Gatekeeper Admission Policy

The morning lab requires admission policies that reject unsafe manifests at the API server. This repository installs Gatekeeper and manages constraints through GitOps.

Relevant files:

| File / directory | Role / Details |
|---|---|
| `argocd/apps/gatekeeper-operator/overlays/production/Chart.yaml` | Gatekeeper Helm chart dependency. |
| `argocd/apps/gatekeeper-operator/overlays/production/values.yaml` | Minikube-sized Gatekeeper resource specifications. |
| `argocd/apps/gatekeeper-policies/base` | ConstraintTemplates and Constraint files. |
| `argocd/apps/gatekeeper-policies/base/kustomization.yaml` | Lists all Gatekeeper policy resources applied by GitOps. |

Implemented constraints:

| Constraint | Purpose |
|---|---|
| `pods-must-have-app-label` | Requires pod label `app`. |
| `pods-must-use-allowed-registries` | Allows only approved registries. |
| `pods-must-not-use-latest-tag` | Rejects `:latest` images. |
| `pods-must-have-resource-limits` | Requires container resource limits. |
| `pods-must-not-run-as-root-user` | Rejects `runAsUser: 0`. |
| `pods-must-not-use-host-network` | Rejects `hostNetwork: true`. |

Gatekeeper status commands:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml get pods -n gatekeeper-production
kubectl --kubeconfig generated\kubeconfig.yaml get constrainttemplates
# Check constraints status
kubectl --kubeconfig generated\kubeconfig.yaml get constraint
```

Server-side dry-run checks:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production run bad-latest --image=docker.io/library/nginx:latest --restart=Never --dry-run=server
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production run bad-no-limits --image=docker.io/library/nginx:1.27 --restart=Never --dry-run=server
```

![alt text](evidence/images/w10/5.png)

*Figure 05: Gatekeeper and its constraints are managed by Argo CD.*

![alt text](evidence/images/w10/6.png)

*Figure 06: Admission rejects a pod that uses an image tagged `:latest`.*

![alt text](evidence/images/w10/7.png)

![alt text](evidence/images/w10/7-1.png)

*Figure 07: Admission rejects missing limits, root user, and hostNetwork violations.*

![alt text](evidence/images/w10/8.png)

*Figure 08: The required-label or registry policy demonstrates the custom policy requirement.*

## 4. Part II - Afternoon Lab: Secrets and Supply Chain

### 4.1. Lab 2.1 - External Secrets Operator

The afternoon lab asks for AWS Secrets Manager plus External Secrets Operator so Kubernetes Secrets are synchronized from AWS instead of storing secret values in Git.

Relevant files:

| File | Role / Details |
|---|---|
| `argocd/install.ps1` | Installs External Secrets Operator before applying Argo CD repo credentials. |
| `argocd/install/clustersecretstore.yaml` | Defines `ClusterSecretStore` named `aws-secretsmanager`. |
| `argocd/apps/database/base/externalsecret.yaml` | Syncs Redis password from AWS Secrets Manager into Kubernetes. |
| `scripts/upload-secrets-to-aws.ps1` | Uploads lab secrets to AWS Secrets Manager. |

Current implementation note:

The active Redis `ExternalSecret` uses `refreshInterval: "1h"`. The Redis container consumes `REDIS_PASSWORD` through an environment variable and command argument. That proves ESO synchronization, but it does not fully prove the slide target of `< 60s` rotation with no pod restart. This item is marked as partial since the active implementation relies on environment variables requiring a pod restart to pick up changes.

ESO validation commands:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml get pods -n external-secrets
kubectl --kubeconfig generated\kubeconfig.yaml get clustersecretstore aws-secretsmanager
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get externalsecret redis-credentials
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get secret redis-credentials
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-production get pod -l app=database
```

Secret-safety check:

```powershell
rg -n "prod@123|password:|secretAccessKey|AWS_SECRET_ACCESS_KEY|COSIGN_PASSWORD|DOCKERHUB_TOKEN" .
```

Expected evidence results:

| Check | Expected result |
|---|---|
| ESO pods | Running in `external-secrets` namespace. |
| `ClusterSecretStore` | Exists and points to AWS Secrets Manager. |
| Redis `ExternalSecret` | Ready in `demo-production`. |
| Kubernetes Secret | Exists and contains secret data. |
| Secret value leakage scan | No real secret values found in the git codebase. |

![alt text](evidence/images/w10/9.png)

*Figure 09: External Secrets Operator synchronizes AWS Secrets Manager values into Kubernetes Secrets.*

![alt text](evidence/images/w10/10.png)

![alt text](evidence/images/w10/10-1.png)

*Figure 10: Secret synchronization and pod age evidence. Current repo behavior is marked partial for the `< 60s` no-restart target.*



### 4.2. Lab 2.2 - Trivy, Cosign, and Admission Verification

The supply-chain lab asks for three controls: scan images, sign images, and verify signatures before admission.

Relevant files:

| File / directory | Role / Details |
|---|---|
| `.github/workflows/ci.yaml` | Builds images, runs Trivy, pushes digests, signs digests, and verifies signatures. |
| `argocd/security/cosign.pub` | Public key used by Cosign verification and policy-controller. |
| `scripts/upload-secrets-to-aws.ps1` | Uploads `minikube-sandbox/cosign-key` and `minikube-sandbox/cosign-password`. |
| `argocd/apps/policy-controller` | Installs Sigstore policy-controller. |
| `argocd/apps/cosign-policies/overlays/production/policy.yaml` | Requires signed frontend/backend images. |
| `argocd/apps/cosign-policies/overlays/production/redis-policy.yaml` | Allows the official Redis image through a static pass policy. |

Current implementation note:

Trivy currently runs in reporting mode because the workflow uses `exit-code: "0"`. The findings do not block the pipeline. Therefore, this check is marked as partial.

CI and signing evidence commands:

```powershell
git grep -n "trivy-action\\|cosign\\|ClusterImagePolicy\\|policy-controller" -- .github/workflows/ci.yaml argocd infra scripts
kubectl --kubeconfig generated\kubeconfig.yaml get pods -n cosign-system
kubectl --kubeconfig generated\kubeconfig.yaml get clusterimagepolicy
kubectl --kubeconfig generated\kubeconfig.yaml get ns demo-production demo-development --show-labels
```

Expected evidence:

| Check | Expected result |
|---|---|
| Trivy scan step | Present in CI, reporting-only (exit-code 0). |
| Cosign signing step | Present and signs target digests. |
| Cosign verification step | Present in CI using `argocd/security/cosign.pub`. |
| policy-controller | Running in `cosign-system`. |
| `ClusterImagePolicy` | Present in the cluster. |
| Namespace inclusion label | Labeled with `policy.sigstore.dev/include=true`. |

![alt text](evidence/images/w10/11.png)

![alt text](evidence/images/w10/11-1.png)

*Figure 11: GitHub Actions runs Trivy scans and Cosign signing/verification for published images.*

![alt text](evidence/images/w10/12.png)

*Figure 12: Cosign verifies a signed image digest with the committed public key.*

![alt text](evidence/images/w10/13.png)

*Figure 13: Sigstore policy-controller applies admission verification to labeled namespaces.*

## 5. Part III - Challenge: Adapted Tenant Isolation

The slide challenge names the new tenant `payments`. In this repository, the adapted challenge implementation uses `demo-development` as the second tenant. The evidence below demonstrates the same isolation goal applied to the repository's current multi-tenant overlays.

Challenge requirements mapped to this repository:

| Slide requirement | Repo evidence target | Status |
|---|---|---|
| New tenant namespace | `demo-development` in namespaces.yaml | Implemented |
| Least-privilege RBAC | RoleBinding for `oidc:demo-development-developers` | Implemented |
| ResourceQuota and LimitRange | `ResourceQuota` and `LimitRange` defined under tenant-namespaces base | Implemented |
| NetworkPolicy isolation | Restricted egress to namespace & DNS | Implemented |
| GitOps app deployment | Applicationset discovers `overlays/*` | Implemented |
| Inherited guardrails | Gatekeeper and Sigstore active | Implemented |

### 5.1. RBAC Isolation

RBAC isolation commands:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i update rollouts.argoproj.io -n demo-development --as=demo-development-developer --as-group=oidc:demo-development-developers
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i get pods -n demo-development --as=demo-development-developer --as-group=oidc:demo-development-developers
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i update rollouts.argoproj.io -n demo-production --as=demo-development-developer --as-group=oidc:demo-development-developers
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i get secrets -n demo-development --as=demo-development-developer --as-group=oidc:demo-development-developers
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i create rolebindings -n demo-development --as=demo-development-developer --as-group=oidc:demo-development-developers
kubectl --kubeconfig generated\kubeconfig.yaml auth can-i create clusterrolebindings --as=demo-development-developer --as-group=oidc:demo-development-developers
```

Expected isolation results:

| Check | Expected result |
|---|---|
| Manage workloads in `demo-development` | `yes` |
| Manage workloads in `demo-production` | `no` |
| Read secrets in namespace | `no` |
| Create rolebindings | `no` |
| Create clusterrolebindings | `no` |

![alt text](evidence/images/w10/14.png)

*Figure 14: demo-development developers are limited to their namespace, without permissions to read secrets or configure RBAC.*

### 5.2. ResourceQuota and LimitRange

The slide challenge requires one `ResourceQuota` and one `LimitRange` for the new tenant. These are now implemented inside [quotas.yaml](file:///E:/code-folder/xbrain_projects/minikube-aws-sandbox/argocd/apps/tenant-namespaces/base/quotas.yaml) in the GitOps directory.

Commands to verify the quotas:

```powershell
git grep -n "ResourceQuota\|LimitRange" argocd
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-development get resourcequota,limitrange
```

Expected result:

| Check | Expected result |
|---|---|
| Repo manifests search | Shows definitions in `argocd/apps/tenant-namespaces/base/quotas.yaml`. |
| Namespace resources query | Shows active `tenant-quota` and `tenant-limits` in `demo-development`. |

![alt text](evidence/images/w10/15-1.png)

![alt text](evidence/images/w10/15-2.png)

*Figure 15: ResourceQuota and LimitRange status. Successfully deployed to enforce namespace bounds.*

### 5.3. NetworkPolicy and Inherited Guardrails

NetworkPolicy verification commands:

```powershell
# Verify Calico pods
kubectl --kubeconfig generated\kubeconfig.yaml get pods -n kube-system | Select-String -Pattern "calico"
# Verify NetworkPolicy
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-development get networkpolicy
# Test same-namespace connectivity
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-development run netcheck-dev --rm -i --restart=Never --image=curlimages/curl:8.11.1 -- sh -c "curl -fsS --max-time 5 http://backend:5000/healthz"
# Test cross-namespace blocked connectivity
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-development run netcheck-dev-to-prod --rm -i --restart=Never --image=curlimages/curl:8.11.1 -- sh -c "curl -fsS --max-time 5 http://backend.demo-production.svc.cluster.local:5000/healthz"
```

![alt text](evidence/images/w10/16.png)

*Figure 16: Actual connection results.*

Expected connectivity results:

| Connection | Expected result |
|---|---|
| Calico CNI status | Running pods in `kube-system`. |
| `demo-development` to same-namespace backend | `Allowed` (returns status 200). |
| `demo-development` to `demo-production` backend | `Blocked` (times out). |

Inherited guardrail validation:

```powershell
kubectl --kubeconfig generated\kubeconfig.yaml get ns demo-development --show-labels
kubectl --kubeconfig generated\kubeconfig.yaml -n demo-development run bad-latest --image=docker.io/library/nginx:latest --restart=Never --dry-run=server
kubectl --kubeconfig generated\kubeconfig.yaml get clusterimagepolicy
```

![alt text](evidence/images/w10/17.png)

*Figure 17: Inherited guardrails.*

Expected results:

- `demo-development` namespace has labels matching security constraints.
- Rejects pods with `:latest` images via Gatekeeper.
- Applies image verification constraints automatically.

## 6. Conclusion

Week 10 adds cluster-level security controls on top of the Week 9 GitOps, observability, and rollout foundation. RBAC limits who can act, Gatekeeper rejects unsafe manifests, ESO removes plaintext secret values from Git, Cosign signs published images, and policy-controller verifies signed images at admission time.

The adapted challenge uses `demo-development` as the second tenant. It demonstrates namespace ownership, namespace-scoped RBAC, inherited admission and signature guardrails, and NetworkPolicy-based traffic isolation.
