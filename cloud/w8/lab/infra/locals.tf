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

  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets     = [for index in range(2) : cidrsubnet(var.vpc_cidr_block, 8, index)]

  operator_cidr = var.allowed_kubernetes_api_cidr != null ? var.allowed_kubernetes_api_cidr : "${chomp(data.http.operator_ip[0].response_body)}/32"

  kubeconfig_ssm_parameter_name = coalesce(var.kubeconfig_ssm_parameter_name, "/${local.name_prefix}/kind/kubeconfig")
  kubeconfig_ssm_parameter_arn  = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.kubeconfig_ssm_parameter_name}"

  alb_name          = substr("${local.name_prefix}-alb", 0, 32)
  target_group_name = substr("${local.name_prefix}-tg", 0, 32)

  tags = merge(
    {
      Project   = local.name_prefix
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

