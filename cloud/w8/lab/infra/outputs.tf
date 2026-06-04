output "aws_region" {
  description = "AWS region used by this root module."
  value       = var.aws_region
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = module.alb.dns_name
}

output "app_url" {
  description = "HTTP URL for the app through the ALB."
  value       = "http://${module.alb.dns_name}/"
}

output "kind_host_instance_id" {
  description = "EC2 instance ID of the kind host."
  value       = module.kind_host.id
}

output "kind_host_public_ip" {
  description = "Public IPv4 address of the kind host."
  value       = module.kind_host.public_ip
}

output "kubeconfig_ssm_parameter_name" {
  description = "SSM SecureString parameter containing the generated kubeconfig."
  value       = local.kubeconfig_ssm_parameter_name
}

output "kubernetes_api_cidr" {
  description = "IPv4 CIDR allowed to access the kind Kubernetes API."
  value       = local.operator_cidr
}

output "node_port" {
  description = "NodePort exposed on the EC2 host and targeted by the ALB."
  value       = var.node_port
}

