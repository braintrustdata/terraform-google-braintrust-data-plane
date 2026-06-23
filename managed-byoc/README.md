# Managed BYOC Bootstrap for GCP

This directory contains the customer-project bootstrap reference for Braintrust
managed BYOC on GCP. It prepares the access envelope Braintrust needs before
Braintrust deploys the data plane.

## Boundary

- Customer owns the dedicated GCP project, billing, organization policies,
  project IAM controls, audit logs, SIEM exports, and project-level monitoring.
- Braintrust manages the Braintrust data-plane deployment and platform
  operation.
- Customer-managed automation should own only the project/access bootstrap
  unless otherwise agreed.

## Deployment Flow

1. Customer designates a dedicated GCP project and target region.
2. Customer runs `setup.sh`, or implements the same end state with an approved
   internal provisioning process.
3. Customer reviews quota readiness with `request-quotas.sh`.
4. Braintrust applies the infra root using
   `terraform-google-braintrust-data-plane`.
5. Braintrust applies the app root using
   `terraform-google-braintrust-gke-app`, consuming the infra-root outputs.

## Bootstrap End State

The standard bootstrap creates or mirrors:

- APIs enabled from `services.json`.
- Cloud Storage service agent initialized for CMEK-backed GCS buckets.
- Deployment service account:
  `braintrust-deploy@<project-id>.iam.gserviceaccount.com`.
- Support service account:
  `braintrust-support@<project-id>.iam.gserviceaccount.com`.
- Secret Manager secret containing the Brainstore license key:
  `brainstore-license-key`.
- Project roles in `deployment-roles.json` granted to the deployment service
  account.
- Project roles in `support-roles.json` granted to the support service account.
  These roles allow approved Braintrust support engineers to inspect and operate
  the cluster and surrounding managed services. They intentionally do not include
  GCS object-read roles.
- `roles/iam.serviceAccountTokenCreator` on the deployment service account for:

  ```text
  serviceAccount:braintrust-byoc-deploy-bridge@braintrust-byoc-management.iam.gserviceaccount.com
  ```

- `roles/iam.serviceAccountTokenCreator` on the support service account for:

  ```text
  group:byoc-support@braintrustdata.com
  ```

Do not create a workload identity pool in the customer project for the standard
Braintrust managed BYOC pattern. Braintrust maintains the AWS-to-GCP Workload
Identity Federation bridge in the Braintrust-owned
`braintrust-byoc-management` project.

## Setup Script

Run from Cloud Shell or an approved workstation with `gcloud` and `jq`
installed. The caller must be allowed to enable APIs, create service accounts,
and manage IAM policies in the target project.

```bash
./setup.sh \
  --project <gcp-project-id> \
  --license-key <brainstore-license-key>
```

Preview the project changes without creating resources or changing IAM:

```bash
./setup.sh \
  --project <gcp-project-id> \
  --license-key <brainstore-license-key> \
  --dry-run
```

Options:

| Flag | Default | Purpose |
| --- | --- | --- |
| `--project` | Required | Target GCP project ID |
| `--deploy-sa-name` | `braintrust-deploy` | Deployment service account name |
| `--support-sa-name` | `braintrust-support` | Support service account name |
| `--automation-sa` | `serviceAccount:braintrust-byoc-deploy-bridge@braintrust-byoc-management.iam.gserviceaccount.com` | Braintrust automation principal |
| `--support-group` | `byoc-support@braintrustdata.com` | Braintrust support group |
| `--license-key` | unset | Brainstore license key to store in the customer project Secret Manager |
| `--license-secret` | `brainstore-license-key` | Secret Manager secret name for the Brainstore license key |
| `--dry-run` | `false` | Print the API, service account, IAM, and impersonation changes without applying them |

If the customer mirrors bootstrap with their own provisioning process, use
`setup.sh`, `services.json`, `deployment-roles.json`, and `support-roles.json`
as the source of truth for the required end state. The provisioning process must
also initialize the Cloud Storage service agent for the project; `setup.sh` does
this with:

```bash
gcloud storage service-agent --project <gcp-project-id>
```

The script is safe to re-run. It skips existing service accounts, re-applies IAM
bindings idempotently, and only adds a new Brainstore license secret version if
the latest version differs from the provided `--license-key` value.

## Quota Review

New GCP projects may need quota increases for the recommended GKE Autopilot
Brainstore machine family and Local SSD. Review quotas before deployment:

```bash
./request-quotas.sh --project <gcp-project-id> --region <gcp-region> list
./request-quotas.sh --project <gcp-project-id> --region <gcp-region> request
```

Desired values live in `quota-config.json`. The default config follows the
recommended Braintrust GKE app setting. To review a different machine family,
create `quota-config.override.json` in this directory.

## App-Root Contract

This module now exports the values expected by
`terraform-google-braintrust-gke-app`, including:

- project, region, deployment name, labels, and namespace
- GCS bucket names
- GKE workload identity service accounts
- GCS HMAC credentials
- Postgres and Redis connection URLs
- GKE cluster name and endpoint metadata

The app root should read these outputs from the infra root state and pass them
directly into `terraform-google-braintrust-gke-app`.

## Handoff Values

After bootstrap, provide Braintrust:

- GCP project ID
- target deployment region
- deployment service account email
- support service account email
- relevant organization policies or IAM Deny policies that may affect GKE, Cloud
  SQL, Redis, GCS, IAM, DNS, load balancing, or support access
