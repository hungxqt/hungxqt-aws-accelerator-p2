terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.28, < 7.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "vpc" {
  source = "../.."

  name = var.name
  cidr = "10.50.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.50.1.0/24", "10.50.2.0/24", "10.50.3.0/24"]

  tags = local.tags
}

module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "6.6.1"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    }
  }

  tags = local.tags
}

locals {
  tags = merge(var.tags, {
    Example   = "endpoints"
    ManagedBy = "Terraform"
  })
}

variable "region" {
  description = "AWS region for the example."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name prefix for VPC resources."
  type        = string
  default     = "example-endpoints"
}

variable "tags" {
  description = "Additional tags for the example resources."
  type        = map(string)
  default     = {}
}

output "vpc_id" {
  description = "Created VPC ID."
  value       = module.vpc.vpc_id
}
