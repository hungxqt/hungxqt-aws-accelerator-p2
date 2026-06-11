# Usage Guide

This folder is a reusable local wrapper for 	erraform-aws-modules/ec2-instance/aws. A project should call it from its own root module and keep account, region, environment, policy, naming, and tagging decisions outside this folder.

## Standard Project Shape

```text
my-project/
  environments/
    dev/
      main.tf
      variables.tf
      backend.tf
      terraform.tfvars.example
```

## Operating Rule

Do not edit $Name/main.tf, $Name/variables.tf, or $Name/outputs.tf for a single project. Configure use cases by setting variables in the consuming project root.
