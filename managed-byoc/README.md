# Managed BYOC

Managed BYOC is an optional Braintrust offering that enables customers to provide a GCP project and have Braintrust deploy and operate the Braintrust Data Plane in that project.

## Project Preparation

Designate a dedicated GCP project exclusively for Braintrust resources. Do not use a project shared with other production infrastructure.

## Setup

Run the provided `setup.sh` script to create the Braintrust deployment and support service accounts and configure the necessary IAM permissions. The script requires the [gcloud CLI](https://cloud.google.com/sdk/docs/install) to be installed and authenticated with an identity that has permission to create service accounts and manage IAM policies in the target project.

```bash
./setup.sh --project <gcp-project-id>
```

If your organization uses Terraform or Terragrunt for project bootstrapping, use this script and the JSON files in this directory as the reference end state. Braintrust does not require Cloud Shell specifically; Braintrust requires the same APIs, service accounts, IAM role bindings, and service-account impersonation grants.

### Setup options

| Flag | Required | Default | Description |
| --- | --- | --- | --- |
| `--project` | Yes | — | GCP project ID to set up |
| `--deploy-sa-name` | No | `braintrust-deploy` | Name for the Braintrust deployment service account |
| `--support-sa-name` | No | `braintrust-support` | Name for the Braintrust support service account |
| `--automation-sa` | No | `serviceAccount:terraform-execution@braintrust-byoc-management.iam.gserviceaccount.com` | Braintrust automation principal allowed to impersonate the deployment service account |
| `--support-group` | No | `byoc-admins@braintrustdata.com` | Braintrust Google group allowed to impersonate the support service account |

### What the script does

1. **Enables required GCP APIs** — Activates all services needed by the Braintrust data plane module (Compute, GKE, Cloud SQL, Redis, KMS, Secret Manager, and others).

2. **Creates Braintrust service accounts** — Creates `braintrust-deploy@<project-id>.iam.gserviceaccount.com` for automation and `braintrust-support@<project-id>.iam.gserviceaccount.com` for approved human support.

3. **Grants IAM roles to the deployment service account** — The following roles are granted at the project level:

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

4. **Grants support roles to the support service account** — Support roles are defined in `support-roles.json` and are intended for approved troubleshooting and support workflows.

5. **Grants impersonation on the support service account to the Braintrust support group** — Allows Braintrust support engineers to use the support identity for approved support events.

6. **Grants impersonation on the deployment service account to Braintrust's automation SA** — Allows Braintrust's automated pipeline to assume the deployment identity to deploy and manage your data plane. The automation SA authenticates to GCP via AWS-to-GCP Workload Identity Federation in Braintrust's management project; no long-lived customer-project credentials are stored.

The script does not create a workload identity pool in the customer project. Braintrust maintains the WIF bridge in the Braintrust-owned `braintrust-byoc-management` project.

Braintrust manages the actual data-plane deployment. Customer-managed Terraform or Terragrunt should only own the project/access bootstrap unless otherwise agreed.

### Reviewing the script

Please review `setup.sh` before running it to confirm the permissions being granted match your organization's requirements.

## Quota Increases

New GCP projects can have low default quotas for newer compute machine families. Run `request-quotas.sh` to inspect current quota values and submit quota increase requests for the GKE node types used by the Braintrust data plane (C3, C3D, C4, C4A, C4D) and their associated local SSD limits. By default we use C4A; if there is limited availability for that family, Braintrust may use an alternate supported family.

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

The quota script uses the Cloud Quotas API through your authenticated `gcloud` identity. Quota increases are reviewed by Google and are not instant - approval typically takes minutes to a few business days. Run this script as early as possible, before deploying the data plane.

You can check the status of pending requests in the Google Cloud console under **IAM & Admin > Quotas & System Limits > Increase Requests**.

## Next Steps

Once both scripts have been run, provide Braintrust with your GCP project ID, region, deployment service account email, and support service account email printed at the end of `setup.sh`. Braintrust will then deploy the data plane into your project.
