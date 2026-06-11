[CmdletBinding()]
param(
  [string]$KubeconfigPath = "",
  [string]$WaitTimeout = "10m",
  [switch]$DeleteApps
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ArgoCdDir = $PSScriptRoot
$RootDir = Split-Path -Parent $ArgoCdDir

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

function Invoke-NativeOptional {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$Reason
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "$Reason Command skipped after exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
  }
}

if (-not (Test-Path -LiteralPath $KubeconfigPath)) {
  throw "Kubeconfig not found: $KubeconfigPath. Run .\scripts\deploy.ps1 or .\scripts\fetch-kube-config.ps1 first."
}

$demoAppPaths = @(
  (Join-Path $ArgoCdDir "apps\frontend"),
  (Join-Path $ArgoCdDir "apps\backend"),
  (Join-Path $ArgoCdDir "apps\database"),
  (Join-Path $ArgoCdDir "apps\prometheus"),
  (Join-Path $ArgoCdDir "apps\argo-rollout")
)
$applicationsetName = "sandbox-apps"
$applicationNames = @(
  "frontend-development", "frontend-production",
  "backend-development", "backend-production",
  "database-development", "database-production",
  "prometheus-development", "prometheus-production",
  "argo-rollout-development", "argo-rollout-production"
)

Write-Host "Using kubeconfig: $KubeconfigPath"

if ($DeleteApps) {
  Write-Host "Deleting Argo CD ApplicationSet to remove the app definition."
  Invoke-NativeOptional kubectl @(
    "--kubeconfig", $KubeconfigPath,
    "-n", "argocd",
    "delete", "applicationset.argoproj.io", $applicationsetName,
    "--ignore-not-found=true",
    "--wait=true",
    "--timeout=$WaitTimeout"
  ) "ApplicationSet may already be gone."

  Write-Host "Deleting generated Argo CD Application objects (cascading delete)."
  foreach ($applicationName in $applicationNames) {
    Invoke-NativeOptional kubectl @(
      "--kubeconfig", $KubeconfigPath,
      "-n", "argocd",
      "delete", "application.argoproj.io", $applicationName,
      "--ignore-not-found=true",
      "--wait=true",
      "--timeout=$WaitTimeout"
    ) "Application resources may already be gone."
  }

  Write-Host "Running final cleanup of any remaining demo app resources."
  foreach ($path in $demoAppPaths) {
    Invoke-NativeOptional kubectl @(
      "--kubeconfig", $KubeconfigPath,
      "delete", "-k", $path,
      "--ignore-not-found=true",
      "--wait=true",
      "--timeout=$WaitTimeout"
    ) "Demo app resources at $path may already be gone."
  }
  
  Write-Host "App resources deleted. Skipping Argo CD uninstallation."
  return
}

if (-not $DeleteApps) {
  Write-Host "Deleting Argo CD ApplicationSet."
Invoke-NativeOptional kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "-n", "argocd",
  "delete", "applicationset.argoproj.io", $applicationsetName,
  "--ignore-not-found=true",
  "--wait=true",
  "--timeout=$WaitTimeout"
) "ApplicationSet may already be gone."

Write-Host "Deleting generated Argo CD Application objects."
foreach ($applicationName in $applicationNames) {
  Invoke-NativeOptional kubectl @(
    "--kubeconfig", $KubeconfigPath,
    "-n", "argocd",
    "patch", "application.argoproj.io", $applicationName,
    "--type=merge",
    "-p", '{"metadata":{"finalizers":[]}}'
  ) "Application finalizers may already be absent, or the Argo CD CRDs may already be removed."

  Invoke-NativeOptional kubectl @(
    "--kubeconfig", $KubeconfigPath,
    "-n", "argocd",
    "delete", "application.argoproj.io", $applicationName,
    "--ignore-not-found=true",
    "--wait=true",
    "--timeout=$WaitTimeout"
  ) "Application resources may already be gone."
}

# Synced app resources are kept unless -DeleteApps is passed for selective deletion.

Write-Host "Deleting Argo CD namespace resources."
Invoke-Native kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "delete", "namespace", "argocd",
  "--ignore-not-found=true",
  "--wait=true",
  "--timeout=$WaitTimeout"
)

Write-Host "Deleting Argo CD cluster RBAC."
Invoke-Native kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "delete", "clusterrole",
  "argocd-application-controller",
  "argocd-applicationset-controller",
  "argocd-server",
  "--ignore-not-found=true",
  "--wait=true",
  "--timeout=$WaitTimeout"
)
Invoke-Native kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "delete", "clusterrolebinding",
  "argocd-application-controller",
  "argocd-applicationset-controller",
  "argocd-server",
  "--ignore-not-found=true",
  "--wait=true",
  "--timeout=$WaitTimeout"
)

Write-Host "Deleting Argo CD CRDs."
Invoke-Native kubectl @(
  "--kubeconfig", $KubeconfigPath,
  "delete", "crd",
  "applications.argoproj.io",
  "appprojects.argoproj.io",
  "applicationsets.argoproj.io",
  "--ignore-not-found=true",
  "--wait=true",
  "--timeout=$WaitTimeout"
)

  Write-Host "Argo CD stack removed."
}
