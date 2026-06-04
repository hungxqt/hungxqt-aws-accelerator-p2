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
    [Parameter(Mandatory = $true)][string]$WorkingDir,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $value = & terraform "-chdir=$WorkingDir" output -raw $Name 2>$null
  if ($LASTEXITCODE -ne 0) {
    return $null
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

$Region = Try-TerraformOutput -WorkingDir $InfraDir -Name "aws_region"
$ParameterName = Try-TerraformOutput -WorkingDir $InfraDir -Name "kubeconfig_ssm_parameter_name"

if ($Region -and $ParameterName -and -not (Test-Path -LiteralPath $KubeconfigPath)) {
  New-Item -ItemType Directory -Force -Path $GeneratedDir | Out-Null
  $kubeconfig = Get-SsmSecureString -Region $Region -Name $ParameterName
  if ($kubeconfig) {
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($KubeconfigPath, $kubeconfig, $utf8NoBom)
  }
}

if (Test-Path -LiteralPath $KubeconfigPath) {
  if (-not $SkipInit) {
    Invoke-Native terraform @("-chdir=$AppDir", "init")
  }

  $appDestroyArgs = @(
    "-chdir=$AppDir",
    "destroy",
    "-auto-approve",
    "-var=kubeconfig_path=$KubeconfigPath"
  )
  if ($AppVarFile) {
    $appDestroyArgs += "-var-file=$AppVarFile"
  }
  Invoke-Native terraform $appDestroyArgs
} else {
  Write-Host "No kubeconfig found; skipping app destroy and continuing with infra destroy."
}

if ($Region -and $ParameterName) {
  & aws ssm delete-parameter --region $Region --name $ParameterName 2>$null
}

$infraDestroyArgs = @("-chdir=$InfraDir", "destroy", "-auto-approve")
if ($InfraVarFile) {
  $infraDestroyArgs += "-var-file=$InfraVarFile"
}
Invoke-Native terraform $infraDestroyArgs

if (Test-Path -LiteralPath $KubeconfigPath) {
  Remove-Item -LiteralPath $KubeconfigPath -Force
}

Write-Host "Destroy complete."
