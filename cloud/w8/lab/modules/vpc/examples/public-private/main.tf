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
  cidr = "10.20.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]
  private_subnets = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]

  enable_nat_gateway = false

  tags = local.tags
}

locals {
  tags = merge(var.tags, {
    Example   = "public-private"
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
  default     = "example-public-private"
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

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.vpc.private_subnets
}
