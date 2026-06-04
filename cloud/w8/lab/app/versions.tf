terraform {
  required_version = ">= 1.5.7, < 2.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.31, < 3.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

