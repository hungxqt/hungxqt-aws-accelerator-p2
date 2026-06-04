param(
  [string]$InfraVarFile = "",
  [string]$AppVarFile = "",
  [switch]$SkipInit
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RootDir = Split-Path -Parent $PSScriptRoot
$InfraDir = Join-Path $RootDir "infra"
$AppDir = Join-Path $RootDir "app"
$GeneratedDir = Join-Path $RootDir "generated"
$KubeconfigPath = Join-Path $GeneratedDir "kubeconfig.yaml"

New-Item -ItemType Directory -Force -Path $GeneratedDir | Out-Null

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

function Get-TerraformOutput {
  param(
    [Parameter(Mandatory = $true)][string]$WorkingDir,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $value = & terraform "-chdir=$WorkingDir" output -raw $Name
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to read Terraform output '$Name' from $WorkingDir."
  }

  return (($value -join "`n").Trim())
}

function Get-SsmSecureString {
  param(
    [Parameter(Mandatory = $true)][string]$Region,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $json = & aws ssm get-parameter `
    --region $Region `
    --name $Name `
    --with-decryption `
    --query "Parameter.Value" `
    --output json 2>$null

  if ($LASTEXITCODE -ne 0 -or -not $json) {
    return $null
  }

  return (($json -join "`n") | ConvertFrom-Json)
}

if (-not $SkipInit) {
  Invoke-Native terraform @("-chdir=$InfraDir", "init")
}

$infraApplyArgs = @("-chdir=$InfraDir", "apply", "-auto-approve")
if ($InfraVarFile) {
  $infraApplyArgs += "-var-file=$InfraVarFile"
}
Invoke-Native terraform $infraApplyArgs

$Region = Get-TerraformOutput -WorkingDir $InfraDir -Name "aws_region"
$ParameterName = Get-TerraformOutput -WorkingDir $InfraDir -Name "kubeconfig_ssm_parameter_name"
$AlbDnsName = Get-TerraformOutput -WorkingDir $InfraDir -Name "alb_dns_name"

Write-Host "Waiting for EC2 bootstrap to publish kubeconfig to SSM: $ParameterName"
$deadline = (Get-Date).AddMinutes(30)
$kubeconfig = $null
while ((Get-Date) -lt $deadline) {
  $kubeconfig = Get-SsmSecureString -Region $Region -Name $ParameterName
  if ($kubeconfig) {
    break
  }

  Start-Sleep -Seconds 15
}

if (-not $kubeconfig) {
  throw "Timed out waiting for kubeconfig in SSM parameter $ParameterName."
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($KubeconfigPath, $kubeconfig, $utf8NoBom)

Write-Host "Waiting for kind Kubernetes API to become reachable."
$deadline = (Get-Date).AddMinutes(10)
$clusterReady = $false
while ((Get-Date) -lt $deadline) {
  & kubectl --kubeconfig $KubeconfigPath get nodes
  if ($LASTEXITCODE -eq 0) {
    $clusterReady = $true
    break
  }

  Start-Sleep -Seconds 10
}

if (-not $clusterReady) {
  throw "Timed out waiting for Kubernetes API readiness."
}

if (-not $SkipInit) {
  Invoke-Native terraform @("-chdir=$AppDir", "init")
}

$nodePort = Get-TerraformOutput -WorkingDir $InfraDir -Name "node_port"
$appApplyArgs = @(
  "-chdir=$AppDir",
  "apply",
  "-auto-approve"
)
if ($AppVarFile) {
  $appApplyArgs += "-var-file=$AppVarFile"
}
$appApplyArgs += "-var=kubeconfig_path=$KubeconfigPath"
$appApplyArgs += "-var=node_port=$nodePort"
Invoke-Native terraform $appApplyArgs

$namespace = Get-TerraformOutput -WorkingDir $AppDir -Name "namespace"
$deployment = Get-TerraformOutput -WorkingDir $AppDir -Name "deployment_name"
Invoke-Native kubectl @("--kubeconfig", $KubeconfigPath, "-n", $namespace, "rollout", "status", "deployment/$deployment", "--timeout=5m")

Write-Host ""
Write-Host "Deployment complete."
Write-Host "App URL: http://$AlbDnsName/"
Write-Host "Kubeconfig: $KubeconfigPath"
