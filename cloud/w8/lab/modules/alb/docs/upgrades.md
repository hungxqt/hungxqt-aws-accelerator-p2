# Upgrade Guide

This wrapper is pinned to 	erraform-aws-modules/alb/aws version $Version. Upgrades are manual by design so consuming projects get reproducible behavior until this shared wrapper is intentionally changed.

## Upgrade Rules

- Keep the upstream module version in `main.tf` as an exact literal string.
- Do not mix an upstream module upgrade with unrelated infrastructure changes.
- Refresh mirrored files from the same upstream Git tag as the selected version.
- Run wrapper validation, example validation, and saved plans in consuming projects before applying.

## Rollback

Rollback by restoring the previous exact version, mirrored `variables.tf`, `outputs.tf`, and `versions.tf`, then rerunning validation and saved plans in consuming projects.
