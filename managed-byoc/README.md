# Managed BYOC

Managed BYOC is an optional Braintrust offering that enables customers to provide a GCP project and have Braintrust deploy and operate the Braintrust Data Plane in that project.

## Project Preparation

Designate a dedicated GCP project exclusively for Braintrust resources. Do not use a project shared with other production infrastructure.

## Setup

Run the provided `setup.sh` script to create the Braintrust management service account and configure the necessary IAM permissions. The script requires the [gcloud CLI](https://cloud.google.com/sdk/docs/install) to be installed and authenticated with an identity that has permission to create service accounts and manage IAM policies in the target project.

```bash
./setup.sh --project <gcp-project-id>
```

### Setup options

| Flag | Required | Default | Description |
| --- | --- | --- | --- |
| `--project` | Yes | — | GCP project ID to set up |
| `--sa-name` | No | `braintrust-mgmt` | Name for the management service account |

### What the script does

1. **Enables required GCP APIs** — Activates all services needed by the Braintrust data plane module (Compute, GKE, Cloud SQL, Redis, KMS, Secret Manager, and others).

2. **Creates a management service account** — A dedicated service account (`<sa-name>@<project-id>.iam.gserviceaccount.com`) used by Braintrust to deploy and manage infrastructure in your project.

3. **Grants IAM roles to the service account** — The following roles are granted at the project level:

   | Role | Purpose |
   | --- | --- |
   | `roles/compute.networkAdmin` | VPC, subnets, Cloud Router, Cloud NAT |
   | `roles/container.admin` | GKE Autopilot cluster |
   | `roles/cloudsql.admin` | Cloud SQL PostgreSQL |
   | `roles/redis.admin` | Redis |
   | `roles/storage.admin` | GCS buckets |
   | `roles/cloudkms.admin` | Customer-managed encryption keys |
   | `roles/secretmanager.admin` | Database credentials |
   | `roles/iam.serviceAccountAdmin` | Workload Identity service accounts |
   | `roles/resourcemanager.projectIamAdmin` | Project-level IAM bindings |
   | `roles/servicenetworking.networksAdmin` | Private VPC peering for Cloud SQL and Redis |
   | `roles/serviceusage.serviceUsageAdmin` | API enablement |
   | `roles/dns.admin` | Cloud DNS private zones |
   | `roles/logging.admin` | Cloud Logging |
   | `roles/monitoring.admin` | Cloud Monitoring |
   | `roles/viewer` | Read-only access across all project resources |
   | `roles/cloudsupport.techSupportEditor` | Open and manage GCP support cases |

4. **Grants the same IAM roles to `byoc-admins@braintrustdata.com`** — Allows Braintrust engineers to operate directly in the project when needed.

5. **Grants impersonation on the service account to `byoc-admins@braintrustdata.com`** — Allows Braintrust's systems to assume the management service account identity to deploy and manage your data plane.

### Reviewing the script

Please review `setup.sh` before running it to confirm the permissions being granted match your organization's requirements.

## Quota Increases

New GCP projects have low default quotas for newer compute machine families. Run `request-quotas.sh` to submit quota increase requests for the GKE node types used by the Braintrust data plane (C3, C3D, C4, C4A, C4D) and their associated local SSD limits. By default we will use C4A however if there is limited availability of these types we will use alternate types.

```bash
# Preview what will be requested
./request-quotas.sh --project <gcp-project-id> --region <gcp-region> list

# Submit the requests
./request-quotas.sh --project <gcp-project-id> --region <gcp-region> request
```

### Quota options

| Flag | Required | Description |
| --- | --- | --- |
| `--project` | Yes | GCP project ID |
| `--region` | Yes | GCP region where the data plane will be deployed (e.g. `us-central1`) |

Desired quota values are configured in `quota-config.json`. To override the defaults without modifying that file, create a `quota-config.override.json` in the same directory.

Quota increases are reviewed by Google and are not instant — approval typically takes minutes to a few business days. Run this script as early as possible, before deploying the data plane.

You can check the status of pending requests with:

```bash
gcloud beta quotas preferences list --project <gcp-project-id>
```

## Next Steps

Once both scripts have been run, provide Braintrust with your GCP project ID and the service account email printed at the end of `setup.sh`. Braintrust will then deploy the data plane into your project.
