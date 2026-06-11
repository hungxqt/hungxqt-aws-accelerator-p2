# AWS VPC Networking Module

Reusable local wrapper for [`terraform-aws-modules/vpc/aws`](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest). It is pinned to upstream version `6.6.1` so every project can use the same VPC module contract without editing this folder.

## Requirements

| Name | Version |
|------|---------|
| Terraform | `>= 1.0` |
| AWS provider | `>= 6.28, < 7.0` |
| Upstream module | `terraform-aws-modules/vpc/aws` `6.6.1` |

## Usage

Use this module from a project root and put project-specific values in that root module, not in `modules/vpc/`.

```hcl
module "networking" {
  source = "../modules/vpc"

  name = "my-project-dev"
  cidr = "10.20.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]
  private_subnets = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]

  tags = {
    Environment = "dev"
    Project     = "my-project"
    ManagedBy   = "Terraform"
  }
}
```

## Local Documentation

- [Usage guide](docs/usage.md)
- [Scenario guide](docs/scenarios.md)
- [Security notes](docs/security.md)
- [Upgrade guide](docs/upgrades.md)

## Upgrade Checklist

Before changing the upstream VPC module version, read the full
[upgrade guide](docs/upgrades.md). Keep the upstream `version` in `main.tf` as a
literal exact string, refresh mirrored `variables.tf` and `outputs.tf` from the
same upstream tag, update provider constraints only when upstream requirements
changed, then validate the wrapper, every example, and every consuming project
plan.

## Examples

The examples under `examples/` are small root modules that can be used as starting points:

- `minimal`
- `public-private`
- `private-nat`
- `database-intra`
- `endpoints`

## Module Contract

Inputs are mirrored from the official upstream module in `variables.tf`. Outputs are re-exposed from `module.vpc` in `outputs.tf`.

Per-project configuration belongs in the consuming project root. Only change this folder when upgrading the upstream module version or intentionally changing the shared module contract.
