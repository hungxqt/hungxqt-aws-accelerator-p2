data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "http" "operator_ip" {
  count = var.allowed_kubernetes_api_cidr == null ? 1 : 0

  url                = "https://checkip.amazonaws.com"
  request_timeout_ms = 5000
}

locals {
  name_prefix = var.name_prefix

  availability_zones = slice(data.aws_availability_zones.available.names, 0, 1)
  public_subnets     = [cidrsubnet(var.vpc_cidr_block, 8, 0)]

  operator_cidr = var.allowed_kubernetes_api_cidr != null ? var.allowed_kubernetes_api_cidr : "${chomp(data.http.operator_ip[0].response_body)}/32"
  app_cidr      = coalesce(var.allowed_app_cidr, var.allowed_http_cidr, local.operator_cidr)
  argocd_cidr   = coalesce(var.allowed_argocd_cidr, local.operator_cidr)

  ami_architecture  = can(regex("^[a-z0-9]+g\\.", var.instance_type)) ? "arm64" : "x86_64"
  ami_ssm_parameter = coalesce(var.ami_ssm_parameter, "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-${local.ami_architecture}")

  kubeconfig_ssm_parameter_name = coalesce(var.kubeconfig_ssm_parameter_name, "/${local.name_prefix}/minikube/kubeconfig")
  kubeconfig_ssm_parameter_arn  = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.kubeconfig_ssm_parameter_name}"

  tags = merge(
    {
      Project   = local.name_prefix
      ManagedBy = "Terraform"
    },
    var.tags
  )
}
