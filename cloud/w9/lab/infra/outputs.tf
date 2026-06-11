output "aws_region" {
  description = "AWS region used by this root module."
  value       = var.aws_region
}

output "app_cidr" {
  description = "IPv4 CIDR allowed to access app NodePorts."
  value       = local.app_cidr
}

output "app_url" {
  description = "HTTP URL for the production app through the EC2 public IP and NodePort."
  value       = "http://${module.minikube_host.public_ip}:${var.node_port}/"
}

output "development_app_url" {
  description = "HTTP URL for the development app through the EC2 public IP and NodePort."
  value       = "http://${module.minikube_host.public_ip}:${var.development_node_port}/"
}

output "production_app_url" {
  description = "HTTP URL for the production app through the EC2 public IP and NodePort."
  value       = "http://${module.minikube_host.public_ip}:${var.node_port}/"
}

output "argocd_url" {
  description = "HTTPS URL for the Argo CD UI through the EC2 public IP and NodePort."
  value       = "https://${module.minikube_host.public_ip}:${var.argocd_node_port}/"
}

output "argocd_node_port" {
  description = "NodePort exposed for the Argo CD server."
  value       = var.argocd_node_port
}

output "instance_id" {
  description = "EC2 instance ID of the minikube host."
  value       = module.minikube_host.id
}

output "instance_public_ip" {
  description = "Public IPv4 address of the minikube host."
  value       = module.minikube_host.public_ip
}

output "kubeconfig_ssm_parameter_name" {
  description = "SSM SecureString parameter containing the generated kubeconfig."
  value       = local.kubeconfig_ssm_parameter_name
}

output "kubernetes_api_cidr" {
  description = "IPv4 CIDR allowed to access the minikube Kubernetes API."
  value       = local.operator_cidr
}

output "kubernetes_api_port" {
  description = "Host port exposed for the minikube Kubernetes API."
  value       = var.kubernetes_api_port
}

output "node_port" {
  description = "Production app NodePort exposed on the EC2 host."
  value       = var.node_port
}

output "development_node_port" {
  description = "Development app NodePort exposed on the EC2 host."
  value       = var.development_node_port
}
