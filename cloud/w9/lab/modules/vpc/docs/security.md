# Security Notes

This wrapper does not include AWS credentials, backend configuration, real account IDs, real ARNs, secrets, or `.tfvars` files. Keep those in project roots or CI secret stores.

## Defaults

- `enable_nat_gateway` defaults to `false` to avoid surprise cost and unnecessary internet egress.
- `map_public_ip_on_launch` defaults to `false`; enable it only for subnets that intentionally launch public instances.
- `manage_default_security_group` defaults to the upstream behavior, with no ingress or egress rules unless configured.
- `manage_default_vpc` defaults to `false`; create dedicated VPCs rather than relying on AWS default VPCs.

## State

Use a remote backend for real environments. Do not keep production state in local files.

For Terraform `>= 1.10`, S3 native locking is a good AWS default:

```hcl
terraform {
  backend "s3" {
    bucket       = "my-terraform-state"
    key          = "prod/networking/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

## Public Access

Only create public subnets when the project needs internet-facing resources such as public app endpoints, NAT Gateway, or bastion-style access. Keep application instances in private subnets where possible.

## Flow Logs

If enabling Flow Logs, set retention and encryption on the CloudWatch log group or S3 destination. New projects should prefer the standalone upstream Flow Logs submodule because root-module Flow Logs are deprecated upstream for the next major version.
