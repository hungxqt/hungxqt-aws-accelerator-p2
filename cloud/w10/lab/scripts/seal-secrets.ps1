param(
  [string]$KubeconfigPath = "",
  [string]$GithubPat = "",
  [string]$SmtpPassword = "",
  [switch]$ForceCertFetch
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ScriptsDir = $PSScriptRoot
$RootDir = Split-Path -Parent $ScriptsDir
$GeneratedDir = Join-Path $RootDir "generated"
$CertPath = Join-Path $GeneratedDir "pub-cert.pem"

if (-not $KubeconfigPath) {
  $KubeconfigPath = Join-Path $GeneratedDir "kubeconfig.yaml"
}

# 1. Check if kubeseal CLI is installed
if (-not (Get-Command kubeseal -ErrorAction SilentlyContinue)) {
  Write-Error "kubeseal CLI is not installed or not in PATH."
  Write-Host "Please download the kubeseal CLI binary from https://github.com/bitnami-labs/sealed-secrets/releases"
  Write-Host "For Windows, download kubeseal-X.Y.Z-windows-amd64.tar.gz, extract the binary, and add it to your PATH."
  exit 1
}

# 2. Fetch the certificate if it doesn't exist or ForceCertFetch is set
if ($ForceCertFetch -or -not (Test-Path -LiteralPath $CertPath)) {
  if (-not (Test-Path -LiteralPath $KubeconfigPath)) {
    Write-Error "Kubeconfig not found: $KubeconfigPath. Cannot fetch Sealed Secrets certificate from the cluster."
    Write-Host "Make sure the cluster is running (.\scripts\deploy.ps1) and the kubeconfig is fetched."
    exit 1
  }
  
  Write-Host "Fetching Sealed Secrets certificate from the cluster..."
  New-Item -ItemType Directory -Force -Path $GeneratedDir | Out-Null
  
  $serviceExists = $null
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = "SilentlyContinue"
  try {
    $serviceExists = & kubectl --kubeconfig $KubeconfigPath -n kube-system get service sealed-secrets-controller --ignore-not-found -o name 2>$null
  } catch {
    $serviceExists = $null
  } finally {
    $ErrorActionPreference = $previousErrorAction
  }
  
  if (-not $serviceExists) {
    Write-Host "Sealed Secrets controller not found in the cluster. Installing it now..."
    & kubectl --kubeconfig $KubeconfigPath apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.2/controller.yaml
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Failed to install Sealed Secrets controller."
      exit 1
    }
    Write-Host "Waiting for Sealed Secrets controller to become available..."
    & kubectl --kubeconfig $KubeconfigPath -n kube-system wait --for=condition=Available deployment/sealed-secrets-controller --timeout=2m
    if ($LASTEXITCODE -ne 0) {
      Write-Error "Timed out waiting for Sealed Secrets controller."
      exit 1
    }
  }

  # Run kubeseal to fetch the certificate
  $certContent = & kubeseal --kubeconfig $KubeconfigPath --fetch-cert `
    --controller-name=sealed-secrets-controller `
    --controller-namespace=kube-system
    
  if ($LASTEXITCODE -ne 0 -or -not $certContent) {
    Write-Error "Failed to fetch certificate from cluster. Ensure the Sealed Secrets controller is running."
    exit 1
  }
  
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($CertPath, ($certContent -join "`n"), $utf8NoBom)
  Write-Host "Certificate saved to $CertPath"
}

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

# 5. Seal GitHub PAT Secret
Write-Host "Sealing GitHub repository secret..."
$githubSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: github-private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://github.com/hungxqt/test-argocd.git
  username: hungxqt
  password: $GithubPat
"@

$tempGithubFile = Join-Path $GeneratedDir "temp-github-secret.yaml"
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($tempGithubFile, $githubSecretYaml, $utf8NoBom)

$githubSealedContent = Get-Content $tempGithubFile -Raw | & kubeseal --cert $CertPath --format=yaml
if ($LASTEXITCODE -ne 0 -or -not $githubSealedContent) {
  Write-Error "Failed to seal GitHub repository secret."
  exit 1
}

# Write to existing target paths
$githubTargets = @(
  (Join-Path $RootDir "argocd-opentelemetry/install/github-private-repo-sealedsecret.yaml"),
  (Join-Path $RootDir "argocd-helm/install/templates/github-private-repo-sealedsecret.yaml")
)

foreach ($target in $githubTargets) {
  $parentDir = Split-Path -Parent $target
  if (Test-Path -LiteralPath $parentDir) {
    if ($target -like "*argocd-helm*") {
      $helmSealedContent = $githubSealedContent -join "`n"
      $helmSealedContent = $helmSealedContent.Replace("namespace: argocd", "namespace: {{ .Release.Namespace }}")
      [System.IO.File]::WriteAllText($target, $helmSealedContent, $utf8NoBom)
    } else {
      [System.IO.File]::WriteAllText($target, ($githubSealedContent -join "`n"), $utf8NoBom)
    }
    Write-Host "GitHub SealedSecret written to: $target"
  }
}

Remove-Item $tempGithubFile -Force

# 6. Seal SMTP Password Secret
Write-Host "Sealing Alertmanager SMTP secret..."
$smtpSecretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-smtp-secret
  namespace: demo-production
type: Opaque
stringData:
  smtp_auth_password: $SmtpPassword
"@

$tempSmtpFile = Join-Path $GeneratedDir "temp-smtp-secret.yaml"
[System.IO.File]::WriteAllText($tempSmtpFile, $smtpSecretYaml, $utf8NoBom)

$smtpSealedContent = Get-Content $tempSmtpFile -Raw | & kubeseal --cert $CertPath --format=yaml
if ($LASTEXITCODE -ne 0 -or -not $smtpSealedContent) {
  Write-Error "Failed to seal SMTP secret."
  exit 1
}

$smtpTargets = @(
  (Join-Path $RootDir "argocd-opentelemetry/apps/prometheus/overlays/production/templates/sealedsecret-smtp.yaml"),
  (Join-Path $RootDir "argocd-helm/apps/prometheus/templates/sealedsecret-smtp.yaml")
)

foreach ($target in $smtpTargets) {
  $parentDir = Split-Path -Parent $target
  if (Test-Path -LiteralPath $parentDir) {
    [System.IO.File]::WriteAllText($target, ($smtpSealedContent -join "`n"), $utf8NoBom)
    Write-Host "SMTP SealedSecret written to: $target"
  }
}

Remove-Item $tempSmtpFile -Force

Write-Host "Sealing completed successfully! You can now commit the sealed secret files safely."
