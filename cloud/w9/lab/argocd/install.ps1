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
