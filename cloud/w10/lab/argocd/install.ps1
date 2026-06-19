param(
  [string]$KubeconfigPath = "",
  [string]$RepoUrl = "",
  [string]$TargetRevision = "main"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ArgoCdDir = $PSScriptRoot
$RootDir = Split-Path -Parent $ArgoCdDir
$InfraDir = Join-Path $RootDir "infra"

if (-not $KubeconfigPath) {
  $KubeconfigPath = Join-Path $RootDir "generated\kubeconfig.yaml"
}

function Invoke-Native {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
  }
}

function Try-TerraformOutput {
  param(
    [Parameter(Mandatory = $true)][string]$Name
  )

  $previousErrorActionPreference = $ErrorActionPreference
  $hasNativeCommandPreference = Test-Path variable:PSNativeCommandUseErrorActionPreference
  if ($hasNativeCommandPreference) {
    $previousNativeCommandPreference = $PSNativeCommandUseErrorActionPreference
  }

  try {
    $ErrorActionPreference = "Continue"
    if ($hasNativeCommandPreference) {
      $PSNativeCommandUseErrorActionPreference = $false
    }

    $value = & terraform "-chdir=$InfraDir" output -raw $Name 2>$null
  } catch {
    return ""
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
    if ($hasNativeCommandPreference) {
      $PSNativeCommandUseErrorActionPreference = $previousNativeCommandPreference
    }
  }

  if ($LASTEXITCODE -ne 0) {
    return ""
  }

  return (($value -join "`n").Trim())
}

function ConvertTo-YamlSingleQuotedScalar {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "$Name is required."
  }

  if ($Value -match "[`r`n]") {
    throw "$Name must be a single-line value."
  }

  return "'" + $Value.Replace("'", "''") + "'"
}

if (-not (Test-Path -LiteralPath $KubeconfigPath)) {
  throw "Kubeconfig not found: $KubeconfigPath. Run .\scripts\deploy.ps1 first."
}

if (-not $RepoUrl) {
  $RepoUrl = (& git -c "safe.directory=$RootDir" -C $RootDir config --get remote.origin.url 2>$null)
  if ($LASTEXITCODE -ne 0) {
    $RepoUrl = ""
  }
  $RepoUrl = (($RepoUrl -join "`n").Trim())
}

if (-not $RepoUrl) {
  throw "RepoUrl is required because this workspace has no detectable git remote. Re-run with -RepoUrl https://example.com/owner/repo.git"
}

$repoUrlScalar = ConvertTo-YamlSingleQuotedScalar -Name "RepoUrl" -Value $RepoUrl
$targetRevisionScalar = ConvertTo-YamlSingleQuotedScalar -Name "TargetRevision" -Value $TargetRevision

$serviceExists = $null
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"
try {
  $serviceExists = & kubectl --kubeconfig $KubeconfigPath -n external-secrets get deployment external-secrets --ignore-not-found -o name 2>$null
} catch {
  $serviceExists = $null
} finally {
  $ErrorActionPreference = $previousErrorAction
}

if (-not $serviceExists) {
  Write-Host "External Secrets Operator not found in the cluster. Installing it now..."
  $nsExists = & kubectl --kubeconfig $KubeconfigPath get namespace external-secrets --ignore-not-found -o name 2>$null
  if (-not $nsExists) {
    $null = & kubectl --kubeconfig $KubeconfigPath create namespace external-secrets 2>$null
  }
  $esoYamlUrl = "https://github.com/external-secrets/external-secrets/releases/download/v0.9.20/external-secrets.yaml"
  $esoYaml = [System.Net.WebClient]::new().DownloadString($esoYamlUrl)
  $esoYaml = $esoYaml.Replace("namespace: default", "namespace: external-secrets")
  $esoYaml = $esoYaml.Replace("--service-namespace=default", "--service-namespace=external-secrets")
  $esoYaml = $esoYaml.Replace("--secret-namespace=default", "--secret-namespace=external-secrets")
  $esoYaml = $esoYaml.Replace("external-secrets-webhook.default.svc", "external-secrets-webhook.external-secrets.svc")
  $esoYaml | kubectl --kubeconfig $KubeconfigPath apply -f -
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply External Secrets Operator manifest."
  }
} else {
  Write-Host "External Secrets Operator is already installed."
}

Write-Host "Waiting for External Secrets Operator to become available..."
Invoke-Native kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "-n", "external-secrets",
  "wait",
  "--for=condition=Available",
  "deployment",
  "--all",
  "--timeout=5m"
)

Write-Host "Waiting for External Secrets Operator CRDs to be established..."
Invoke-Native kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "wait",
  "--for=condition=Established",
  "crd/clustersecretstores.external-secrets.io",
  "crd/secretstores.external-secrets.io",
  "crd/externalsecrets.external-secrets.io",
  "--timeout=2m"
)

$awsRegion = Try-TerraformOutput -Name "aws_region"
if (-not $awsRegion) {
  $awsRegion = "us-east-1"
}
Write-Host "Applying ClusterSecretStore with AWS Region: $awsRegion"
$clusterSecretStorePath = Join-Path $ArgoCdDir "install\clustersecretstore.yaml"
$clusterSecretStoreYaml = Get-Content -Raw -LiteralPath $clusterSecretStorePath
$clusterSecretStoreYaml = $clusterSecretStoreYaml.Replace("REPLACE_WITH_AWS_REGION", $awsRegion)
$clusterSecretStoreYaml | kubectl --kubeconfig $KubeconfigPath apply --server-side=true --force-conflicts --field-manager=argocd-installer -f -

$installPath = Join-Path $ArgoCdDir "install"
Invoke-Native kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "apply",
  "--server-side=true",
  "--force-conflicts",
  "--field-manager=argocd-installer",
  "-k", $installPath
)
Invoke-Native kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "wait",
  "--for=condition=Established",
  "crd/applications.argoproj.io",
  "crd/appprojects.argoproj.io",
  "crd/applicationsets.argoproj.io",
  "--timeout=2m"
)
Invoke-Native kubectl @("--kubeconfig", $KubeconfigPath, "-n", "argocd", "wait", "--for=condition=Available", "deployment", "--all", "--timeout=10m")
Invoke-Native kubectl @("--kubeconfig", $KubeconfigPath, "-n", "argocd", "rollout", "status", "statefulset/argocd-application-controller", "--timeout=10m")

$repoUsername = "git"
if ($RepoUrl -match "github\.com[:/]([^/]+)/") {
  $repoUsername = $Matches[1]
}

Write-Host "Applying ExternalSecret for GitHub private repo: $RepoUrl with user: $repoUsername"
$githubSecretPath = Join-Path $ArgoCdDir "install\github-private-repo-externalsecret.yaml"
$githubSecretYaml = Get-Content -Raw -LiteralPath $githubSecretPath
$githubSecretYaml = $githubSecretYaml.Replace("REPLACE_WITH_REPOSITORY_URL", $RepoUrl)
$githubSecretYaml = $githubSecretYaml.Replace("REPLACE_WITH_REPOSITORY_USERNAME", $repoUsername)
$githubSecretYaml | kubectl --kubeconfig $KubeconfigPath apply --server-side=true --force-conflicts --field-manager=argocd-installer -f -

Write-Host "Waiting for GitHub repository ExternalSecret to become Ready..."
Invoke-Native kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "-n", "argocd",
  "wait",
  "--for=condition=Ready",
  "externalsecret/github-private-repo",
  "--timeout=5m"
)

$projectPath = Join-Path $ArgoCdDir "bootstrap\project.yaml"
Write-Host "Applying sandbox AppProject from $projectPath..."
Invoke-Native kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "apply",
  "--server-side=true",
  "--force-conflicts",
  "--field-manager=argocd-installer",
  "-f", $projectPath
)

$appsApplicationSetPath = Join-Path $ArgoCdDir "bootstrap\apps-applicationset.yaml"
$appsApplicationSet = Get-Content -Raw -LiteralPath $appsApplicationSetPath
$appsApplicationSet = $appsApplicationSet.Replace("REPLACE_WITH_REPOSITORY_URL", $repoUrlScalar)
$appsApplicationSet = $appsApplicationSet.Replace("REPLACE_WITH_TARGET_REVISION", $targetRevisionScalar)
$appsApplicationSet | kubectl --kubeconfig $KubeconfigPath apply --server-side=true --force-conflicts --field-manager=argocd-installer -f -
if ($LASTEXITCODE -ne 0) {
  throw "Failed to apply Argo CD ApplicationSet from $appsApplicationSetPath."
}


$adminPassword = ""
$secretName = "argocd-initial-admin-secret"
$passwordB64 = & kubectl --kubeconfig $KubeconfigPath -n argocd get secret $secretName -o jsonpath="{.data.password}" 2>$null
if ($LASTEXITCODE -eq 0 -and $passwordB64) {
  try {
    $adminPassword = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($passwordB64))
  } catch {
    $adminPassword = ""
  }
}

$argoCdUrl = Try-TerraformOutput -Name "argocd_url"
$developmentAppUrl = Try-TerraformOutput -Name "development_app_url"
$productionAppUrl = Try-TerraformOutput -Name "production_app_url"
if (-not $productionAppUrl) {
  $productionAppUrl = Try-TerraformOutput -Name "app_url"
}

Write-Host "Argo CD installed and apps ApplicationSet applied."
if ($argoCdUrl) {
  Write-Host "Argo CD URL: $argoCdUrl"
} else {
  Write-Host "Argo CD URL: terraform -chdir=infra output -raw argocd_url"
}
if ($developmentAppUrl) {
  Write-Host "Development app URL: $developmentAppUrl"
} else {
  Write-Host "Development app URL: unavailable until Terraform is applied with development_node_port."
}
if ($productionAppUrl) {
  Write-Host "Production app URL: $productionAppUrl"
} else {
  Write-Host "Production app URL: unavailable until Terraform outputs are refreshed."
}

if ($adminPassword) {
  Write-Host "Argo CD initial admin password: $adminPassword"
}
