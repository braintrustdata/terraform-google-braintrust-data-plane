# Braintrust GCP Data Plane - Terraform Module

This is a Terraform module that provisions GCP infrastructure for the Braintrust hybrid data plane on Google Kubernetes Engine.

## Module Structure

```
├── main.tf, variables.tf, outputs.tf, versions.tf   # Root module - orchestrates submodules
├── modules/
│   ├── database/       # Cloud SQL (PostgreSQL)
│   ├── gke-cluster/    # GKE cluster (Standard or Autopilot)
│   ├── gke-iam/        # IAM, Workload Identity, HMAC keys
│   ├── kms/            # Cloud KMS encryption keys
│   ├── redis/          # Memorystore (Redis)
│   ├── storage/        # GCS buckets
│   └── vpc/            # VPC, subnets, private service connections
├── examples/
│   └── braintrust-data-plane/   # Production example
└── mise.toml                    # Tool versions and tasks (terraform, tflint)
```

### Key architecture concepts

- **Pure infrastructure module.** This module creates VPC, GKE, Cloud SQL, Redis, GCS, and IAM resources. It does not manage application-level configuration (environment variables, image tags, etc.). All application config lives in the Helm chart deployed on top of this infrastructure.
- **`deployment_name`** prefixes all resource names and must be unique per deployment in the same GCP project.
- **Workload Identity** is used to grant GKE pods access to GCP resources. The `gke-iam` module creates GCP service accounts and binds them to Kubernetes service accounts via `roles/iam.workloadIdentityUser`.

## Critical Safety Constraints

### Workload Identity Bindings

The `gke-iam` module uses `google_service_account_iam_binding`, which is **authoritative** - it sets the complete list of members for the given role. If members are added manually outside Terraform for the same role, they will be removed on the next apply.

Both the `brainstore` and `braintrust-api` Kubernetes service accounts must be bound to the brainstore GCP service account. The API pod accesses GCS directly for endpoints like `/brainstore/object-data-exists`.

### First-Deploy Timing Issue

The module may fail on the first `terraform apply` due to a timing issue with the VPC private service connection. Re-running `terraform apply` typically resolves it.

## Development

Tool versions are managed via `mise.toml`:

```bash
mise install        # Install terraform, tflint
mise run setup      # Install pre-commit hooks
mise run lint       # terraform fmt + tflint
mise run validate   # terraform init + validate
```

Pre-commit hooks run automatically on commit. Run `mise run lint` to check before committing.
