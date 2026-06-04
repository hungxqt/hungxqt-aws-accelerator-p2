# Security Notes

This wrapper does not include AWS credentials, backend configuration, real account IDs, real ARNs, secrets, or `.tfvars` files. Keep those in project roots or CI secret stores.

## Guardrails

- Do not hardcode credentials, account-specific secrets, private keys, tokens, or real ARNs in this shared wrapper.
- Keep project-specific policies, principals, CIDRs, names, and retention settings in the consuming root module.

## State

Use a remote backend for real environments. Do not keep production state in local files, and always review a saved plan before apply.
