# Upgrade Guide

This wrapper is pinned to `terraform-aws-modules/vpc/aws` version `6.6.1`.
Upgrades are manual by design so consuming projects get reproducible module
behavior until this shared wrapper is intentionally changed.

## Upgrade Rules

- Keep the upstream module version in `main.tf` as an exact literal string, for
  example `version = "6.6.1"`.
- Do not use a project variable, local value, or loose constraint for the module
  `version`. Terraform installs child modules before normal expression
  evaluation, and exact pins keep every consuming project on the same contract.
- Do not mix an upstream VPC module upgrade with unrelated networking changes.
- Refresh mirrored files from the same upstream tag as the pinned module version.
- Run wrapper validation, example validation, and saved plans in every consuming
  project before applying.

## Choose the Target Version

1. Review the upstream Registry page for `terraform-aws-modules/vpc/aws` and
   select the exact version to test.
2. Read the upstream release notes and migration notes for every version between
   the current pin and the target pin.
3. Prefer a smaller version step when a release includes renamed variables,
   changed defaults, provider requirement changes, or resource replacement risks.
4. Record the current pin, target pin, and expected breaking changes in the
   upgrade PR or change ticket.

## Update the Upstream Pin

Edit only the upstream child module version in `main.tf`:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "x.y.z"
}
```

Keep `version` as a quoted, exact version. Do not change it to `var.*`, `local.*`,
`~>`, `>=`, or an omitted version.

## Refresh Mirrored Files

`variables.tf` mirrors the upstream module input contract. `outputs.tf`
re-exposes upstream outputs from `module.vpc`. Refresh both from the same
upstream Git tag as the version selected above.

From `modules/vpc/`, replace `x.y.z` with the target version:

```powershell
$Version = "x.y.z"
$Tag = "v$Version"
$BaseUrl = "https://raw.githubusercontent.com/terraform-aws-modules/terraform-aws-vpc/$Tag"

Invoke-WebRequest "$BaseUrl/variables.tf" -OutFile "variables.tf"
Invoke-WebRequest "$BaseUrl/outputs.tf" -OutFile "outputs.tf"
```

If the upstream release uses a different tag name, use the tag shown in the
upstream release page. Do not download from `master`, `main`, or another moving
branch.

After refreshing `variables.tf`, reconcile the wrapper module call in `main.tf`:

- Add pass-through arguments for new upstream variables that should be part of
  this wrapper contract.
- Remove arguments for upstream variables that no longer exist.
- Rename arguments only when upstream renamed the input, and document the impact
  in the upgrade PR or change ticket.
- Keep project-specific values out of this module. Consuming projects should set
  values in their own root modules.

After refreshing `outputs.tf`, make sure each output reads from `module.vpc` and
has a useful description. Mark outputs as sensitive only when upstream exposes
sensitive data.

## Check Provider Constraints

Open the upstream `versions.tf` from the same tag and compare its
`required_providers` block with this wrapper's `versions.tf`.

Update this wrapper's provider constraints only when upstream requirements
changed or when the selected upstream version cannot validate with the current
constraints. Keep provider upgrades visible in the change review because they can
alter plans even when the VPC module inputs are unchanged.

Do not loosen provider constraints just to get the latest provider. If a provider
upgrade is needed, run `terraform init -upgrade`, review the lock file changes in
consuming projects, and save a plan artifact before apply.

## Validate the Wrapper

Run these commands from the repository root:

```powershell
terraform fmt -check -recursive

cd modules/vpc
terraform init -backend=false -upgrade
terraform validate
```

## Validate Examples

Validate every example because each one covers a different part of the wrapper
contract.

```powershell
cd examples/minimal
terraform init -backend=false -upgrade
terraform validate
```

Repeat the same `init` and `validate` commands for:

- `examples/public-private`
- `examples/private-nat`
- `examples/database-intra`
- `examples/endpoints`

## Validate Consuming Projects

For every real project that uses this wrapper, run a saved plan before apply:

```powershell
terraform init -upgrade
terraform plan -out=tfplan
```

Review the saved plan for replacements, route table changes, subnet changes,
security group changes, network ACL changes, and flow log changes. Never apply
directly to production without reviewing the plan artifact and getting the
required approval.

## Rollback

Rollback is the reverse of the upgrade:

1. Change the upstream version in `main.tf` back to the previous exact pin.
2. Restore `variables.tf` and `outputs.tf` from the previous upstream tag.
3. Restore `versions.tf` provider constraints if they changed only for the
   failed upgrade.
4. Run wrapper and example validation again.
5. In each consuming project, run `terraform init -upgrade` and create a new
   saved plan.
6. Review the rollback plan before any apply.

Keep the failed upgrade plan, rollback plan, and notes about the observed issue
with the change record.
