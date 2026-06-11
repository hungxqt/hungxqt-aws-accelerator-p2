variable "aws_region" {
  description = "AWS region where all resources are created."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Short name prefix used for created resources."
  type        = string
  default     = "tf-minikube-demo"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,18}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-20 lowercase alphanumeric or hyphen characters, start with a letter, and end with a letter or number."
  }
}

variable "vpc_cidr_block" {
  description = "CIDR block for the demo VPC."
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr_block, 0))
    error_message = "vpc_cidr_block must be a valid IPv4 CIDR block."
  }
}

variable "allowed_app_cidr" {
  description = "IPv4 CIDR allowed to reach app NodePorts directly on the EC2 host. When null, the operator CIDR is used."
  type        = string
  default     = null

  validation {
    condition     = var.allowed_app_cidr == null || can(cidrhost(var.allowed_app_cidr, 0))
    error_message = "allowed_app_cidr must be null or a valid IPv4 CIDR block."
  }
}

variable "allowed_http_cidr" {
  description = "Deprecated compatibility alias for allowed_app_cidr."
  type        = string
  default     = null

  validation {
    condition     = var.allowed_http_cidr == null || can(cidrhost(var.allowed_http_cidr, 0))
    error_message = "allowed_http_cidr must be null or a valid IPv4 CIDR block."
  }
}

variable "allowed_kubernetes_api_cidr" {
  description = "IPv4 CIDR allowed to reach the minikube Kubernetes API on the EC2 host. When null, the caller public IPv4 is detected."
  type        = string
  default     = null

  validation {
    condition     = var.allowed_kubernetes_api_cidr == null || (can(cidrhost(var.allowed_kubernetes_api_cidr, 0)) && var.allowed_kubernetes_api_cidr != "0.0.0.0/0")
    error_message = "allowed_kubernetes_api_cidr must be null or a valid IPv4 CIDR block other than 0.0.0.0/0."
  }
}

variable "allowed_argocd_cidr" {
  description = "IPv4 CIDR allowed to reach the Argo CD UI/API NodePort. When null, the operator CIDR is used."
  type        = string
  default     = null

  validation {
    condition     = var.allowed_argocd_cidr == null || (can(cidrhost(var.allowed_argocd_cidr, 0)) && var.allowed_argocd_cidr != "0.0.0.0/0")
    error_message = "allowed_argocd_cidr must be null or a valid IPv4 CIDR block other than 0.0.0.0/0."
  }
}

variable "ami_ssm_parameter" {
  description = "SSM public parameter for the Amazon Linux AMI used by the minikube host. When null, an Amazon Linux 2023 AMI is selected from the instance type architecture."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type for Docker and the single-node minikube cluster."
  type        = string
  default     = "t4g.small"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB for the minikube host."
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size >= 20
    error_message = "root_volume_size must be at least 20 GiB."
  }
}

variable "minikube_version" {
  description = "minikube CLI version installed on the EC2 host."
  type        = string
  default     = "v1.38.1"
}

variable "kubectl_version" {
  description = "kubectl version installed on the EC2 host."
  type        = string
  default     = "v1.34.0"
}

variable "kubernetes_version" {
  description = "Kubernetes version used by minikube."
  type        = string
  default     = "v1.34.0"
}

variable "minikube_profile" {
  description = "minikube profile name created on the EC2 host."
  type        = string
  default     = "terraform-demo"
}

variable "minikube_cpus" {
  description = "CPU count assigned to the minikube node."
  type        = number
  default     = 2

  validation {
    condition     = var.minikube_cpus >= 2
    error_message = "minikube_cpus must be at least 2."
  }
}

variable "minikube_memory_mb" {
  description = "Memory in MB assigned to the minikube node."
  type        = number
  default     = 1800

  validation {
    condition     = var.minikube_memory_mb >= 1800
    error_message = "minikube_memory_mb must be at least 1800."
  }
}

variable "node_port" {
  description = "Production app NodePort exposed by the Kubernetes Service on the EC2 host."
  type        = number
  default     = 30080

  validation {
    condition     = var.node_port >= 30000 && var.node_port <= 32767
    error_message = "node_port must be in the Kubernetes NodePort range 30000-32767."
  }
}

variable "development_node_port" {
  description = "Development app NodePort exposed by the Kubernetes Service on the EC2 host."
  type        = number
  default     = 30081

  validation {
    condition     = var.development_node_port >= 30000 && var.development_node_port <= 32767 && var.development_node_port != var.node_port
    error_message = "development_node_port must be in the Kubernetes NodePort range 30000-32767 and must not equal node_port."
  }
}

variable "argocd_node_port" {
  description = "NodePort exposed by the Argo CD server Service on the EC2 host."
  type        = number
  default     = 30443

  validation {
    condition     = var.argocd_node_port >= 30000 && var.argocd_node_port <= 32767 && var.argocd_node_port != var.node_port && var.argocd_node_port != var.development_node_port
    error_message = "argocd_node_port must be in the Kubernetes NodePort range 30000-32767 and must not equal node_port or development_node_port."
  }
}

variable "kubernetes_api_port" {
  description = "Host port used to expose the minikube Kubernetes API."
  type        = number
  default     = 8443
}

variable "kubeconfig_ssm_parameter_name" {
  description = "SSM SecureString parameter name where cloud-init writes the generated kubeconfig."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to AWS resources managed directly by this root module."
  type        = map(string)
  default     = {}
}
