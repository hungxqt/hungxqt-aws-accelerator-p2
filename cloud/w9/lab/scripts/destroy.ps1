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

if (-not $SkipInit) {
  Invoke-Native terraform @("-chdir=$InfraDir", "init")
}

$Region = Try-TerraformOutput -WorkingDir $InfraDir -Name "aws_region"
$ParameterName = Try-TerraformOutput -WorkingDir $InfraDir -Name "kubeconfig_ssm_parameter_name"

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
