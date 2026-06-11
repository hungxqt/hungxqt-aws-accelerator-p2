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

module "minikube_host" {
  source = "../modules/ec2-instance"

  name                                 = "${local.name_prefix}-minikube-host"
  ami_ssm_parameter                    = local.ami_ssm_parameter
  instance_type                        = var.instance_type
  cpu_credits                          = "standard"
  instance_initiated_shutdown_behavior = "stop"
  subnet_id                            = module.vpc.public_subnets[0]
  associate_public_ip_address          = true
  vpc_security_group_ids               = [aws_security_group.minikube_host.id]
  create_security_group                = false
  create_eip                           = false

  create_iam_instance_profile = true
  iam_role_name               = "${local.name_prefix}-minikube-host"
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

  user_data = templatefile("${path.module}/templates/minikube-user-data.sh.tftpl", {
    aws_region                    = var.aws_region
    kubernetes_version            = var.kubernetes_version
    kubeconfig_ssm_parameter_name = local.kubeconfig_ssm_parameter_name
    kubectl_version               = var.kubectl_version
    kubernetes_api_port           = var.kubernetes_api_port
    minikube_cpus                 = var.minikube_cpus
    minikube_memory_mb            = var.minikube_memory_mb
    minikube_profile              = var.minikube_profile
    minikube_version              = var.minikube_version
    node_port                     = var.node_port
    development_node_port         = var.development_node_port
    argocd_node_port              = var.argocd_node_port
  })
  user_data_replace_on_change = true

  tags        = local.tags
  volume_tags = local.tags
}
