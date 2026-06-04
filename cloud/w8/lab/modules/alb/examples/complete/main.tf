terraform {
  required_version = ">= 1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "alb" {
  source = "../.."

  name = "example-alb"
  tags = local.tags
}

locals {
  tags = merge(var.tags, {
    Example   = "complete"
    ManagedBy = "Terraform"
  })
}

variable "region" {
  description = "AWS region for the example."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Additional tags for the example resources."
  type        = map(string)
  default     = {}
}

output "security_group_arn" {
  description = "Amazon Resource Name (ARN) of the security group"
  value       = module.alb.security_group_arn
}

output "security_group_id" {
  description = "ID of the security group"
  value       = module.alb.security_group_id
}
