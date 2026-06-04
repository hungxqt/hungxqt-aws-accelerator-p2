variable "kubeconfig_path" {
  description = "Path to the kubeconfig generated from the infra phase."
  type        = string
  default     = "../generated/kubeconfig.yaml"
}

variable "namespace" {
  description = "Kubernetes namespace for the demo app."
  type        = string
  default     = "demo"
}

variable "app_name" {
  description = "Kubernetes app name."
  type        = string
  default     = "demo-app"
}

variable "replicas" {
  description = "Number of app replicas."
  type        = number
  default     = 1

  validation {
    condition     = var.replicas >= 1
    error_message = "replicas must be at least 1."
  }
}

variable "container_image" {
  description = "Small non-root HTTP image to deploy."
  type        = string
  default     = "nginxinc/nginx-unprivileged:1.29-alpine"
}

variable "container_port" {
  description = "HTTP port exposed by the app container."
  type        = number
  default     = 8080
}

variable "service_port" {
  description = "Cluster service port."
  type        = number
  default     = 80
}

variable "node_port" {
  description = "NodePort that must match the ALB target group port from infra."
  type        = number
  default     = 30080

  validation {
    condition     = var.node_port >= 30000 && var.node_port <= 32767
    error_message = "node_port must be in the Kubernetes NodePort range 30000-32767."
  }
}

