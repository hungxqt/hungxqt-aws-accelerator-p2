resource "aws_security_group" "minikube_host" {
  name_prefix = "${local.name_prefix}-minikube-"
  description = "EC2 host running Docker and minikube"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-minikube-host"
  })
}

resource "aws_vpc_security_group_ingress_rule" "minikube_api_from_operator" {
  security_group_id = aws_security_group.minikube_host.id
  description       = "Allow operator access to the minikube Kubernetes API"

  cidr_ipv4   = local.operator_cidr
  from_port   = var.kubernetes_api_port
  ip_protocol = "tcp"
  to_port     = var.kubernetes_api_port
}

resource "aws_vpc_security_group_ingress_rule" "app_nodeport_from_allowed_cidr" {
  security_group_id = aws_security_group.minikube_host.id
  description       = "Allow direct production app NodePort traffic from the configured CIDR"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = var.node_port
  ip_protocol = "tcp"
  to_port     = var.node_port
}

resource "aws_vpc_security_group_ingress_rule" "development_app_nodeport_from_allowed_cidr" {
  security_group_id = aws_security_group.minikube_host.id
  description       = "Allow direct development app NodePort traffic from the configured CIDR"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = var.development_node_port
  ip_protocol = "tcp"
  to_port     = var.development_node_port
}

resource "aws_vpc_security_group_ingress_rule" "argocd_nodeport_from_allowed_cidr" {
  security_group_id = aws_security_group.minikube_host.id
  description       = "Allow Argo CD UI access from the configured CIDR"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = var.argocd_node_port
  ip_protocol = "tcp"
  to_port     = var.argocd_node_port
}

resource "aws_vpc_security_group_ingress_rule" "prometheus_from_allowed_cidr" {
  security_group_id = aws_security_group.minikube_host.id
  description       = "Allow Prometheus UI access from caller IP"

  cidr_ipv4   = local.operator_cidr
  from_port   = 39090
  ip_protocol = "tcp"
  to_port     = 39090
}

resource "aws_vpc_security_group_egress_rule" "minikube_host_ipv4_egress" {
  security_group_id = aws_security_group.minikube_host.id
  description       = "Allow EC2 host package and image downloads"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
