$Region = terraform -chdir=infra output -raw aws_region
$Param  = terraform -chdir=infra output -raw kubeconfig_ssm_parameter_name

New-Item -ItemType Directory -Force generated | Out-Null

$Kubeconfig = aws ssm get-parameter `
    --region $Region `
    --name $Param `
    --with-decryption `
    --query "Parameter.Value" `
    --output json | ConvertFrom-Json

[System.IO.File]::WriteAllText(
    (Join-Path (Get-Location) "generated\kubeconfig.yaml"),
    $Kubeconfig,
    [System.Text.UTF8Encoding]::new($false)
)
