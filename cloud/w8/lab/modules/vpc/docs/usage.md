# Usage Guide

This folder is a reusable module. A project should call it from its own root module and pass values for that project's account, region, environment, CIDR plan, subnet layout, and tags.

## Standard Project Shape

```text
my-project/
  environments/
    dev/
      main.tf
      variables.tf
      backend.tf
      terraform.tfvars.example
```

The `modules/vpc/` module should stay outside project-specific environment folders. That keeps networking defaults reusable and avoids editing shared module code for every application.

## Project Root Example

```hcl
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

module "networking" {
  source = "../../../modules/vpc"

  name = "${var.project}-${var.environment}"
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

## Operating Rule

Do not edit `modules/vpc/main.tf`, `modules/vpc/variables.tf`, or `modules/vpc/outputs.tf` for a single project. Configure use cases by setting variables in the project root.

Use `enable_nat_gateway = true` only when private workloads need outbound internet access. The shared default is `false` to avoid surprise NAT Gateway cost.
