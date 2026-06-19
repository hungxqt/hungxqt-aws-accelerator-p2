param(
  [string]$InfraVarFile = "",
  [switch]$SkipInit
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RootDir = Split-Path -Parent $PSScriptRoot
$InfraDir = Join-Path $RootDir "infra"
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

  $previousErrorActionPreference = $ErrorActionPreference
  $json = $null
  try {
    $ErrorActionPreference = "Continue"
    $PSNativeCommandUseErrorActionPreference = $false
    $json = & aws ssm get-parameter `
      --region $Region `
      --name $Name `
      --with-decryption `
      --query "Parameter.Value" `
      --output json 2>$null
  } catch {
    return $null
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  if ($LASTEXITCODE -ne 0 -or -not $json) {
    return $null
  }

  try {
    return (($json -join "`n") | ConvertFrom-Json)
  } catch {
    return $null
  }
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
$DevelopmentAppUrl = Get-TerraformOutput -WorkingDir $InfraDir -Name "development_app_url"
$ProductionAppUrl = Get-TerraformOutput -WorkingDir $InfraDir -Name "production_app_url"
$InstancePublicIp = Get-TerraformOutput -WorkingDir $InfraDir -Name "instance_public_ip"
$KubernetesApiPort = Get-TerraformOutput -WorkingDir $InfraDir -Name "kubernetes_api_port"
$ExpectedKubeApiServer = "https://${InstancePublicIp}:${KubernetesApiPort}"

Write-Host "Waiting for EC2 bootstrap to publish kubeconfig to SSM: $ParameterName"
$deadline = (Get-Date).AddMinutes(30)
$kubeconfig = $null
while ((Get-Date) -lt $deadline) {
  $kubeconfig = Get-SsmSecureString -Region $Region -Name $ParameterName
  if ($kubeconfig -and $kubeconfig.Contains($ExpectedKubeApiServer)) {
    break
  }

  Start-Sleep -Seconds 15
}

if (-not $kubeconfig) {
  throw "Timed out waiting for kubeconfig in SSM parameter $ParameterName."
}

if (-not $kubeconfig.Contains($ExpectedKubeApiServer)) {
  throw "Timed out waiting for kubeconfig in SSM parameter $ParameterName to target $ExpectedKubeApiServer."
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($KubeconfigPath, $kubeconfig, $utf8NoBom)

Write-Host "Waiting for minikube Kubernetes API to become reachable."
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

Write-Host ""
Write-Host "Infrastructure and kubeconfig are ready."
Write-Host "Development app URL: $DevelopmentAppUrl"
Write-Host "Production app URL: $ProductionAppUrl"
Write-Host "Argo CD URL: $(Get-TerraformOutput -WorkingDir $InfraDir -Name "argocd_url")"
Write-Host "Kubeconfig: $KubeconfigPath"
