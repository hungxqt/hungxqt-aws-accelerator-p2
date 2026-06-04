variable "aws_region" {
  description = "AWS region where all resources are created."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Short name prefix used for created resources."
  type        = string
  default     = "tf-kind-demo"

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

variable "allowed_http_cidr" {
  description = "IPv4 CIDR allowed to reach the public ALB listener."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.allowed_http_cidr, 0))
    error_message = "allowed_http_cidr must be a valid IPv4 CIDR block."
  }
}

variable "allowed_kubernetes_api_cidr" {
  description = "IPv4 CIDR allowed to reach the kind Kubernetes API on the EC2 host. When null, the caller public IPv4 is detected."
  type        = string
  default     = null

  validation {
    condition     = var.allowed_kubernetes_api_cidr == null || can(cidrhost(var.allowed_kubernetes_api_cidr, 0))
    error_message = "allowed_kubernetes_api_cidr must be null or a valid IPv4 CIDR block."
  }
}

variable "ami_ssm_parameter" {
  description = "SSM public parameter for the Amazon Linux AMI used by the kind host."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "instance_type" {
  description = "EC2 instance type for Docker and the single-node kind cluster."
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB for the kind host."
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size >= 20
    error_message = "root_volume_size must be at least 20 GiB."
  }
}

variable "kind_version" {
  description = "kind CLI version installed on the EC2 host."
  type        = string
  default     = "v0.30.0"
}

variable "kubectl_version" {
  description = "kubectl version installed on the EC2 host."
  type        = string
  default     = "v1.34.0"
}

variable "kind_node_image" {
  description = "Pinned kind node image used to create the cluster."
  type        = string
  default     = "kindest/node:v1.34.0@sha256:7416a61b42b1662ca6ca89f02028ac133a309a2a30ba309614e8ec94d976dc5a"
}

variable "kind_cluster_name" {
  description = "Name of the kind cluster created on the EC2 host."
  type        = string
  default     = "terraform-demo"
}

variable "node_port" {
  description = "NodePort exposed by the Kubernetes Service and forwarded to by the ALB target group."
  type        = number
  default     = 30080

  validation {
    condition     = var.node_port >= 30000 && var.node_port <= 32767
    error_message = "node_port must be in the Kubernetes NodePort range 30000-32767."
  }
}

variable "kubernetes_api_port" {
  description = "Host port used to expose the kind Kubernetes API."
  type        = number
  default     = 6443
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

