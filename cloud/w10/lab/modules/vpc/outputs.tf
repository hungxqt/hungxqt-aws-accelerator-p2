output "vpc_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_cidr_block
}

output "default_security_group_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_security_group_id
}

output "default_network_acl_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_network_acl_id
}

output "default_route_table_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_route_table_id
}

output "vpc_instance_tenancy" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_instance_tenancy
}

output "vpc_enable_dns_support" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_enable_dns_support
}

output "vpc_enable_dns_hostnames" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_enable_dns_hostnames
}

output "vpc_main_route_table_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_main_route_table_id
}

output "vpc_ipv6_association_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_ipv6_association_id
}

output "vpc_ipv6_cidr_block" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_ipv6_cidr_block
}

output "vpc_secondary_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_secondary_cidr_blocks
}

output "vpc_owner_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_owner_id
}

output "vpc_block_public_access_exclusions" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_block_public_access_exclusions
}

output "dhcp_options_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.dhcp_options_id
}

output "igw_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.igw_id
}

output "igw_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.igw_arn
}

output "public_subnet_objects" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_subnet_objects
}

output "public_subnets" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_subnets
}

output "public_subnet_arns" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_subnet_arns
}

output "public_subnets_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_subnets_cidr_blocks
}

output "public_subnets_ipv6_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_subnets_ipv6_cidr_blocks
}

output "public_route_table_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_route_table_ids
}

output "public_internet_gateway_route_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_internet_gateway_route_id
}

output "public_internet_gateway_ipv6_route_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_internet_gateway_ipv6_route_id
}

output "public_route_table_association_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_route_table_association_ids
}

output "public_network_acl_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_network_acl_id
}

output "public_network_acl_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.public_network_acl_arn
}

output "private_subnet_objects" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_subnet_objects
}

output "private_subnets" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_subnets
}

output "private_subnet_arns" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_subnet_arns
}

output "private_subnets_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_subnets_cidr_blocks
}

output "private_subnets_ipv6_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_subnets_ipv6_cidr_blocks
}

output "private_route_table_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_route_table_ids
}

output "private_nat_gateway_route_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_nat_gateway_route_ids
}

output "private_ipv6_egress_route_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_ipv6_egress_route_ids
}

output "private_route_table_association_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_route_table_association_ids
}

output "private_network_acl_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_network_acl_id
}

output "private_network_acl_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.private_network_acl_arn
}

output "outpost_subnet_objects" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.outpost_subnet_objects
}

output "outpost_subnets" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.outpost_subnets
}

output "outpost_subnet_arns" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.outpost_subnet_arns
}

output "outpost_subnets_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.outpost_subnets_cidr_blocks
}

output "outpost_subnets_ipv6_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.outpost_subnets_ipv6_cidr_blocks
}

output "outpost_network_acl_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.outpost_network_acl_id
}

output "outpost_network_acl_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.outpost_network_acl_arn
}

output "database_subnet_objects" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_subnet_objects
}

output "database_subnets" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_subnets
}

output "database_subnet_arns" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_subnet_arns
}

output "database_subnets_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_subnets_cidr_blocks
}

output "database_subnets_ipv6_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_subnets_ipv6_cidr_blocks
}

output "database_subnet_group" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_subnet_group
}

output "database_subnet_group_name" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_subnet_group_name
}

output "database_route_table_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_route_table_ids
}

output "database_internet_gateway_route_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_internet_gateway_route_id
}

output "database_nat_gateway_route_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_nat_gateway_route_ids
}

output "database_ipv6_egress_route_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_ipv6_egress_route_id
}

output "database_route_table_association_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_route_table_association_ids
}

output "database_network_acl_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_network_acl_id
}

output "database_network_acl_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.database_network_acl_arn
}

output "redshift_subnet_objects" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_subnet_objects
}

output "redshift_subnets" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_subnets
}

output "redshift_subnet_arns" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_subnet_arns
}

output "redshift_subnets_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_subnets_cidr_blocks
}

output "redshift_subnets_ipv6_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_subnets_ipv6_cidr_blocks
}

output "redshift_subnet_group" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_subnet_group
}

output "redshift_route_table_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_route_table_ids
}

output "redshift_route_table_association_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_route_table_association_ids
}

output "redshift_public_route_table_association_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_public_route_table_association_ids
}

output "redshift_network_acl_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_network_acl_id
}

output "redshift_network_acl_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.redshift_network_acl_arn
}

output "elasticache_subnet_objects" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_subnet_objects
}

output "elasticache_subnets" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_subnets
}

output "elasticache_subnet_arns" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_subnet_arns
}

output "elasticache_subnets_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_subnets_cidr_blocks
}

output "elasticache_subnets_ipv6_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_subnets_ipv6_cidr_blocks
}

output "elasticache_subnet_group" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_subnet_group
}

output "elasticache_subnet_group_name" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_subnet_group_name
}

output "elasticache_route_table_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_route_table_ids
}

output "elasticache_route_table_association_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_route_table_association_ids
}

output "elasticache_network_acl_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_network_acl_id
}

output "elasticache_network_acl_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.elasticache_network_acl_arn
}

output "intra_subnet_objects" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.intra_subnet_objects
}

output "intra_subnets" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.intra_subnets
}

output "intra_subnet_arns" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.intra_subnet_arns
}

output "intra_subnets_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.intra_subnets_cidr_blocks
}

output "intra_subnets_ipv6_cidr_blocks" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.intra_subnets_ipv6_cidr_blocks
}

output "intra_route_table_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.intra_route_table_ids
}

output "intra_route_table_association_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.intra_route_table_association_ids
}

output "intra_network_acl_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.intra_network_acl_id
}

output "intra_network_acl_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.intra_network_acl_arn
}

output "nat_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.nat_ids
}

output "nat_public_ips" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.nat_public_ips
}

output "natgw_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.natgw_ids
}

output "natgw_interface_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.natgw_interface_ids
}

output "egress_only_internet_gateway_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.egress_only_internet_gateway_id
}

output "cgw_ids" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.cgw_ids
}

output "cgw_arns" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.cgw_arns
}

output "this_customer_gateway" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.this_customer_gateway
}

output "vgw_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vgw_id
}

output "vgw_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vgw_arn
}

output "default_vpc_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_vpc_id
}

output "default_vpc_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_vpc_arn
}

output "default_vpc_cidr_block" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_vpc_cidr_block
}

output "default_vpc_default_security_group_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_vpc_default_security_group_id
}

output "default_vpc_default_network_acl_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_vpc_default_network_acl_id
}

output "default_vpc_default_route_table_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_vpc_default_route_table_id
}

output "default_vpc_instance_tenancy" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_vpc_instance_tenancy
}

output "default_vpc_enable_dns_support" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_vpc_enable_dns_support
}

output "default_vpc_enable_dns_hostnames" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_vpc_enable_dns_hostnames
}

output "default_vpc_main_route_table_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.default_vpc_main_route_table_id
}

output "vpc_flow_log_id" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_flow_log_id
}

output "vpc_flow_log_destination_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_flow_log_destination_arn
}

output "vpc_flow_log_destination_type" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_flow_log_destination_type
}

output "vpc_flow_log_cloudwatch_iam_role_arn" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_flow_log_cloudwatch_iam_role_arn
}

output "vpc_flow_log_deliver_cross_account_role" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.vpc_flow_log_deliver_cross_account_role
}

output "azs" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.azs
}

output "name" {
  description = "Mirrored $name output from terraform-aws-modules/vpc/aws."
  value       = module.vpc.name
}

