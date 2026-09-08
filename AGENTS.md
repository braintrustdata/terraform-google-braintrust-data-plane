# Braintrust GCP Data Plane - Terraform Module

This is a Terraform module that provisions GCP infrastructure for the Braintrust hybrid data plane on Google Kubernetes Engine.

## Module Structure

```
├── main.tf, variables.tf, outputs.tf, versions.tf   # Root module - orchestrates submodules
├── modules/
│   ├── database/       # Cloud SQL (PostgreSQL)
│   ├── gke-cluster/    # GKE cluster (Standard or Autopilot)
│   ├── gke-node-pool/  # User-managed node pools for GKE Standard
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

### GKE Cluster Mode

Treat `gke_cluster_mode` as immutable after the initial deployment.
Do not instruct users to switch between Autopilot and Standard modes.
State that a mode change replaces the cluster and causes data-plane downtime.
State that the replacement cluster requires redeployment of the Braintrust Helm release.

### Node Pool Defaults

The Standard node pool defaults use the Arm C4A machine series (`c4a-standard-16` and `c4a-standard-48-lssd`).
The node pool module always sets `node_config.taint_config.architecture_taint_behavior` to `NONE`.
This value disables the `kubernetes.io/arch=arm64:NoSchedule` taint that GKE applies to Arm nodes.
Braintrust images support Arm and x86, and the cluster is dedicated to Braintrust workloads.
Do not expose the architecture taint behavior as a module input.
GKE manages that taint, so it never belongs in the `taints` input.
Recommend the x86 C4 equivalents only when C4A is unavailable in the deployment region.

### Node Pool Updates

Machine type, disk type, and disk size changes use the GKE node upgrade strategy.
The default surge configuration uses `max_surge = 1` and `max_unavailable = 0`.
GKE creates a surge node and waits for Ready state before it removes an old node.
If GCP cannot create the surge node, the update waits or fails without an intentional capacity reduction.
An Arm-to-x86 architecture change requires a separate node pool migration.
All Standard node pools use generated names and `create_before_destroy` for resource replacements.
Each node has a stable `braintrust/node-pool` label for Helm node selectors.
`create_before_destroy` does not verify the capacity of a replacement resource.
A resource replacement can interrupt workloads.

### Brainstore Local SSD

The `brainstore` node pool in Standard mode must use a machine type with bundled Local SSD (`lssd` in the machine type name).
Do not add a Local SSD count input. The count is a fixed property of the machine type.
Do not add a table of machine types and Local SSD counts.
GKE selects the fixed count when it creates the node pool.
The module ignores `node_config[0].ephemeral_storage_local_ssd_config` because GKE populates that block.
Node auto-upgrade is hardcoded to `true`, because clusters enrolled in a release channel reject node pools that disable it.

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
mise run test       # Run Terraform tests
```

Pre-commit hooks run automatically on commit. Run `mise run lint` to check before committing.
