# Customer Bootstrap Reference

This document summarizes the customer-project end state required for Braintrust managed BYOC on GCP. Customers may run `setup.sh` directly or reproduce the same resources and IAM bindings with Terraform, Terragrunt, or another approved internal workflow.

## Boundary

The customer owns the dedicated GCP project, billing, organization policies, audit logs, and project-level monitoring.

Braintrust owns the Braintrust data-plane deployment and ongoing data-plane operation. Customer-managed Terraform or Terragrunt should manage only the project/access bootstrap unless Braintrust explicitly agrees otherwise.

## Customer Project Resources

Create two service accounts in the dedicated customer project:

- `braintrust-deploy@<project-id>.iam.gserviceaccount.com`
- `braintrust-support@<project-id>.iam.gserviceaccount.com`

Enable the APIs listed in `services.json`.

Grant the roles in `deployment-roles.json` to the `braintrust-deploy` service account.

Grant the roles in `support-roles.json` to the `braintrust-support` service account.

Grant `roles/iam.serviceAccountTokenCreator` on the `braintrust-deploy` service account to:

```text
serviceAccount:terraform-execution@braintrust-byoc-management.iam.gserviceaccount.com
```

Grant `roles/iam.serviceAccountTokenCreator` on the `braintrust-support` service account to:

```text
group:byoc-admins@braintrustdata.com
```

## WIF Boundary

Do not create a workload identity pool in the customer project for the standard Braintrust managed BYOC pattern.

Braintrust maintains the AWS-to-GCP Workload Identity Federation bridge in the Braintrust-owned `braintrust-byoc-management` project. Braintrust automation uses that bridge to become the `terraform-execution` service account, then impersonates the customer-project `braintrust-deploy` service account.

## Handoff Values

Provide Braintrust with:

- Customer GCP project ID
- Deployment region
- Deployment service account email
- Support service account email
- Any organization policies or IAM Deny policies that may affect GKE, Cloud SQL, Redis, GCS, IAM, DNS, or load balancing

