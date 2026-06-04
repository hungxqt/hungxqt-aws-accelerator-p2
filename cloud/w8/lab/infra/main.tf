module "vpc" {
  source = "../modules/vpc"

  name = local.name_prefix
  cidr = var.vpc_cidr_block

  azs                     = local.availability_zones
  public_subnets          = local.public_subnets
  map_public_ip_on_launch = true

  enable_nat_gateway     = false
  create_egress_only_igw = false

  tags = local.tags
}

module "kind_host" {
  source = "../modules/ec2-instance"

  name                        = "${local.name_prefix}-kind-host"
  ami_ssm_parameter           = var.ami_ssm_parameter
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.kind_host.id]
  create_security_group       = false

  create_iam_instance_profile = true
  iam_role_name               = "${local.name_prefix}-kind-host"
  iam_role_use_name_prefix    = true
  iam_role_policies = {
    ssm_core          = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    kubeconfig_writer = aws_iam_policy.kubeconfig_writer.arn
  }

  metadata_options = {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  root_block_device = {
    encrypted = true
    size      = var.root_volume_size
    type      = "gp3"
  }

  user_data = templatefile("${path.module}/templates/kind-user-data.sh.tftpl", {
    aws_region                    = var.aws_region
    kind_cluster_name             = var.kind_cluster_name
    kind_node_image               = var.kind_node_image
    kind_version                  = var.kind_version
    kubeconfig_ssm_parameter_name = local.kubeconfig_ssm_parameter_name
    kubectl_version               = var.kubectl_version
    kubernetes_api_port           = var.kubernetes_api_port
    node_port                     = var.node_port
  })
  user_data_replace_on_change = true

  tags        = local.tags
  volume_tags = local.tags
}

module "alb" {
  source = "../modules/alb"

  name                       = local.alb_name
  load_balancer_type         = "application"
  internal                   = false
  enable_deletion_protection = false

  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.public_subnets
  security_groups            = [aws_security_group.alb.id]
  create_security_group      = false
  drop_invalid_header_fields = true

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "app"
      }
    }
  }

  target_groups = {
    app = {
      name              = local.target_group_name
      protocol          = "HTTP"
      port              = var.node_port
      target_type       = "instance"
      vpc_id            = module.vpc.vpc_id
      create_attachment = false

      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200-399"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 3
      }
    }
  }

  additional_target_group_attachments = {
    kind_host = {
      target_group_key = "app"
      target_id        = module.kind_host.id
      port             = var.node_port
    }
  }

  tags = local.tags
}
