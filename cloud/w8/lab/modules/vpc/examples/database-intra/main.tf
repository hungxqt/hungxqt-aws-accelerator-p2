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
  cidr = "10.30.0.0/16"

  azs              = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets   = ["10.30.101.0/24", "10.30.102.0/24", "10.30.103.0/24"]
  private_subnets  = ["10.30.1.0/24", "10.30.2.0/24", "10.30.3.0/24"]
  database_subnets = ["10.30.21.0/24", "10.30.22.0/24", "10.30.23.0/24"]
  intra_subnets    = ["10.30.31.0/24", "10.30.32.0/24", "10.30.33.0/24"]

  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  enable_nat_gateway                 = false

  tags = local.tags
}

locals {
  tags = merge(var.tags, {
    Example   = "database-intra"
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
  default     = "example-database-intra"
}

variable "tags" {
  description = "Additional tags for the example resources."
  type        = map(string)
  default     = {}
}

output "database_subnet_group_name" {
  description = "Database subnet group name."
  value       = module.vpc.database_subnet_group_name
}

output "intra_subnet_ids" {
  description = "Intra subnet IDs."
  value       = module.vpc.intra_subnets
}
