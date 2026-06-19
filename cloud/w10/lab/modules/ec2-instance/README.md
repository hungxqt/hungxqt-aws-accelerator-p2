# AWS ec2-instance Module

Reusable local wrapper for [	erraform-aws-modules/ec2-instance/aws](https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/latest). It is pinned to upstream version $Version so every project can use the same module contract without editing this folder.

## Requirements

| Name | Version |
|------|---------|
| Upstream module | 	erraform-aws-modules/ec2-instance/aws $Version |

## Usage

Use this module from a project root and put project-specific values in that root module, not in this shared wrapper folder.

```hcl
module "ec2_instance" {
  source = "../modules/ec2-instance"
}
```

## Local Documentation

- [Usage guide](docs/usage.md)
- [Scenario guide](docs/scenarios.md)
- [Security notes](docs/security.md)
- [Upgrade guide](docs/upgrades.md)

## Examples

- `minimal`
- `complete`

## Module Contract

Inputs are mirrored from the official upstream module in ariables.tf. Outputs are re-exposed from module.ec2_instance in outputs.tf.
