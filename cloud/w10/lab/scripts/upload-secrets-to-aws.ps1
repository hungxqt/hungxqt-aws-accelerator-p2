param(
  [string]$AwsRegion = "",
  [string]$GithubPat = "",
  [string]$SmtpPassword = "",
  [string]$RedisPassword = "",
  [string]$RedisProductionPassword = "",
  [string]$RedisDevelopmentPassword = "",
  [string]$CosignKeyPath = "",
  [string]$CosignPassword = ""
)

$ErrorActionPreference = "Stop"
$StrictMode = "Latest"

$ScriptsDir = $PSScriptRoot
$RootDir = Split-Path -Parent $ScriptsDir
$InfraDir = Join-Path $RootDir "infra"

# 1. Check if AWS CLI is installed
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
  Write-Error "AWS CLI is not installed or not in PATH."
  Write-Host "Please install the AWS CLI (https://aws.amazon.com/cli/) and run 'aws configure' before using this script."
  exit 1
}

# 2. Fetch AWS region if not provided
if (-not $AwsRegion) {
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $AwsRegion = & terraform "-chdir=$InfraDir" output -raw aws_region 2>$null
    $AwsRegion = (($AwsRegion -join "`n").Trim())
  } catch {
    $AwsRegion = ""
  } finally {
    $ErrorActionPreference = $previousErrorAction
  }

  if (-not $AwsRegion -or $LASTEXITCODE -ne 0) {
    $AwsRegion = "us-east-1"
  }
}

Write-Host "Using AWS Region: $AwsRegion"

# 3. Prompt for GitHub PAT if not provided
if (-not $GithubPat) {
  $GithubPat = Read-Host -Prompt "Enter GitHub Personal Access Token (PAT) for repository authentication"
  if ([string]::IsNullOrEmpty($GithubPat)) {
    Write-Error "GitHub PAT is required."
    exit 1
  }
}

# 4. Prompt for SMTP Password if not provided
if (-not $SmtpPassword) {
  $SmtpPassword = Read-Host -Prompt "Enter Alertmanager SMTP Auth Password"
  if ([string]::IsNullOrEmpty($SmtpPassword)) {
    Write-Error "SMTP Password is required."
    exit 1
  }
}

# Helper to generate random 16-char password
function Generate-RandomPassword {
  $charList = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  $pass = ""
  for ($i = 0; $i -lt 16; $i++) {
    $pass += $charList[(Get-Random -Minimum 0 -Maximum $charList.Length)]
  }
  return $pass
}

# 4b. Prompt/generate Redis passwords
if (-not $RedisProductionPassword) {
  if ($RedisPassword) {
    $RedisProductionPassword = $RedisPassword
  } else {
    $RedisProductionPassword = Read-Host -Prompt "Enter Redis Production Password (press enter to generate a secure random password)"
    if ([string]::IsNullOrEmpty($RedisProductionPassword)) {
      $RedisProductionPassword = Generate-RandomPassword
    }
  }
}

if (-not $RedisDevelopmentPassword) {
  if ($RedisPassword) {
    $RedisDevelopmentPassword = "${RedisPassword}-dev"
  } else {
    $RedisDevelopmentPassword = Read-Host -Prompt "Enter Redis Development Password (press enter to generate a secure random password)"
    if ([string]::IsNullOrEmpty($RedisDevelopmentPassword)) {
      $RedisDevelopmentPassword = Generate-RandomPassword
    }
  }
}


# Helper function to create or update AWS Secrets Manager secret
function Set-AwsSecret {
  param(
    [string]$SecretName,
    [string]$SecretValue,
    [string]$Region
  )

  Write-Host "Checking if secret '$SecretName' exists in AWS Secrets Manager..."
  $previousErrorAction = $ErrorActionPreference
  $hasNativeCommandPreference = Test-Path variable:PSNativeCommandUseErrorActionPreference
  if ($hasNativeCommandPreference) {
    $previousNativeCommandPreference = $PSNativeCommandUseErrorActionPreference
  }

  $exists = $false
  try {
    $ErrorActionPreference = "SilentlyContinue"
    if ($hasNativeCommandPreference) {
      $PSNativeCommandUseErrorActionPreference = $false
    }
    $null = & aws secretsmanager describe-secret --secret-id $SecretName --region $Region 2>$null
    if ($LASTEXITCODE -eq 0) {
      $exists = $true
    }
  } catch {
    $exists = $false
  } finally {
    $ErrorActionPreference = $previousErrorAction
    if ($hasNativeCommandPreference) {
      $PSNativeCommandUseErrorActionPreference = $previousNativeCommandPreference
    }
  }

  if ($exists) {
    Write-Host "Secret '$SecretName' already exists. Updating its value..."
    & aws secretsmanager put-secret-value --secret-id $SecretName --secret-string $SecretValue --region $Region | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Failed to update secret: $SecretName"
      exit 1
    }
    Write-Host "Successfully updated secret '$SecretName'."
  } else {
    Write-Host "Secret '$SecretName' does not exist. Creating it..."
    & aws secretsmanager create-secret --name $SecretName --secret-string $SecretValue --region $Region | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Failed to create secret: $SecretName"
      exit 1
    }
    Write-Host "Successfully created secret '$SecretName'."
  }
}

# 4c. Load Cosign Key
if (-not $CosignKeyPath) {
  $CosignKeyPath = Join-Path $RootDir "cosign/cosign.key"
}
if (-not (Test-Path -LiteralPath $CosignKeyPath)) {
  Write-Error "Cosign key file not found at: $CosignKeyPath"
  exit 1
}
$CosignKey = Get-Content -Path $CosignKeyPath -Raw

# 4d. Resolve Cosign Password
if (-not $CosignPassword) {
  $CosignPassword = Read-Host -Prompt "Enter Cosign private key password (press enter to default to 'admin123')"
  if ([string]::IsNullOrEmpty($CosignPassword)) {
    $CosignPassword = "admin123"
  }
}

# 5. Set the secrets
Set-AwsSecret -SecretName "minikube-sandbox/github-pat" -SecretValue $GithubPat -Region $AwsRegion
Set-AwsSecret -SecretName "minikube-sandbox/smtp-password" -SecretValue $SmtpPassword -Region $AwsRegion
Set-AwsSecret -SecretName "minikube-sandbox/redis-password-production" -SecretValue $RedisProductionPassword -Region $AwsRegion
Set-AwsSecret -SecretName "minikube-sandbox/redis-password-development" -SecretValue $RedisDevelopmentPassword -Region $AwsRegion
Set-AwsSecret -SecretName "minikube-sandbox/cosign-key" -SecretValue $CosignKey -Region $AwsRegion
Set-AwsSecret -SecretName "minikube-sandbox/cosign-password" -SecretValue $CosignPassword -Region $AwsRegion

Write-Host "`nSecrets successfully saved to AWS Secrets Manager!"
Write-Host "Please ensure the minikube host EC2 instance profile has the necessary IAM permissions to access them."
Write-Host "You can grant permissions by adding a policy with 'secretsmanager:GetSecretValue' to the host's IAM role."
