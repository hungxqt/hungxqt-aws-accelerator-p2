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
  cidr = var.cidr

  tags = local.tags
}

locals {
  tags = merge(var.tags, {
    Example   = "minimal"
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
  default     = "example-minimal"
}

variable "cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.10.0.0/16"
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
