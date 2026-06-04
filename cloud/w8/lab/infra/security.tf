resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  description = "Internet-facing ALB for the kind NodePort app"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb"
  })
}

resource "aws_security_group" "kind_host" {
  name_prefix = "${local.name_prefix}-kind-"
  description = "EC2 host running Docker and kind"
  vpc_id      = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-kind-host"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from the configured public CIDR"

  cidr_ipv4   = var.allowed_http_cidr
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_kind_nodeport" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow ALB to reach the kind NodePort on the EC2 host"

  referenced_security_group_id = aws_security_group.kind_host.id
  from_port                    = var.node_port
  ip_protocol                  = "tcp"
  to_port                      = var.node_port
}

resource "aws_vpc_security_group_ingress_rule" "kind_nodeport_from_alb" {
  security_group_id = aws_security_group.kind_host.id
  description       = "Allow app NodePort traffic from the ALB only"

  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.node_port
  ip_protocol                  = "tcp"
  to_port                      = var.node_port
}

resource "aws_vpc_security_group_ingress_rule" "kind_api_from_operator" {
  security_group_id = aws_security_group.kind_host.id
  description       = "Allow Terraform Kubernetes provider to reach the kind API"

  cidr_ipv4   = local.operator_cidr
  from_port   = var.kubernetes_api_port
  ip_protocol = "tcp"
  to_port     = var.kubernetes_api_port
}

resource "aws_vpc_security_group_egress_rule" "kind_host_ipv4_egress" {
  security_group_id = aws_security_group.kind_host.id
  description       = "Allow EC2 host package and image downloads"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

