output "namespace" {
  description = "Namespace containing the demo app."
  value       = kubernetes_namespace_v1.app.metadata[0].name
}

output "deployment_name" {
  description = "Deployment name for rollout checks."
  value       = kubernetes_deployment_v1.app.metadata[0].name
}

output "service_name" {
  description = "NodePort Service name."
  value       = kubernetes_service_v1.app.metadata[0].name
}

output "node_port" {
  description = "NodePort exposed by the service."
  value       = var.node_port
}

