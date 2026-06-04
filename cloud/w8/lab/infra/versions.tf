terraform {
  required_version = ">= 1.5.7, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.37, < 7.0"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.5, < 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.tags
  }
}

provider "http" {}

