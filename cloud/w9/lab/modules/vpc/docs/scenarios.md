# Scenario Guide

These scenarios map common project needs to module variables. Use the examples as starting points, then keep project-specific values in the consuming root module.

## Minimal VPC

Use when a project needs only a dedicated VPC and no subnets yet.

```hcl
module "networking" {
  source = "../modules/vpc"

  name = "sandbox"
  cidr = "10.10.0.0/16"
}
```

Example: `examples/minimal`.

## Public and Private Subnets

Use for standard application networking. NAT stays disabled unless the private subnets need outbound internet.

```hcl
module "networking" {
  source = "../modules/vpc"

  name = "app-dev"
  cidr = "10.20.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]
  private_subnets = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
}
```

Example: `examples/public-private`.

## Private Subnets with NAT

Use when private workloads need outbound internet for package downloads, external APIs, or agent updates.

```hcl
enable_nat_gateway = true
single_nat_gateway = true
```

For production high availability, prefer one NAT per AZ:

```hcl
enable_nat_gateway     = true
one_nat_gateway_per_az = true
single_nat_gateway     = false
```

Example: `examples/private-nat`.

## Database and Intra Subnets

Use database subnets for RDS subnet groups. Use intra subnets for isolated infrastructure that should not receive an internet route.

```hcl
database_subnets                 = ["10.30.21.0/24", "10.30.22.0/24", "10.30.23.0/24"]
create_database_subnet_group     = true
create_database_subnet_route_table = true
intra_subnets                    = ["10.30.31.0/24", "10.30.32.0/24", "10.30.33.0/24"]
```

Example: `examples/database-intra`.

## VPC Endpoints

The root VPC module does not expose endpoint variables. Use the official endpoint submodule in the project root and wire it to this module's outputs.

```hcl
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "6.6.1"

  vpc_id = module.networking.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.networking.private_route_table_ids
    }
  }

  tags = var.tags
}
```

Example: `examples/endpoints`.

## Flow Logs

The upstream root module still supports VPC Flow Logs in `6.6.1`, but upstream marks root-module Flow Logs as deprecated for v7. For new projects, prefer the standalone `terraform-aws-modules/vpc/aws//modules/vpc-flow-logs` module in the project root.
