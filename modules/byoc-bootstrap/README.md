# GCP BYOC v2 bootstrap module

This module prepares an existing dedicated customer project for Braintrust-managed data planes.
It creates access identities, API configuration, and encrypted storage. It creates no data plane resources.

The [customer root](../../examples/byoc-bootstrap/README.md) accepts the Braintrust tfvars file.
A standalone root can reference this public module through an approved immutable commit:

```hcl
source = "git::https://github.com/braintrustdata/terraform-google-braintrust-data-plane.git//modules/byoc-bootstrap?ref=<approved-commit-sha>"
```

## Inputs and handoff

| Required input | Purpose |
| --- | --- |
| `project_id`, `project_number` | Existing project and expected numeric identity. |
| `region` | Deployment region and default bucket location. |
| `bootstrap_id` | Braintrust-assigned `bsp_` UUIDv7 identifier. |
| `braintrust_bridge_service_account` | Exact Braintrust account with deployment impersonation access. No default. |

Optional inputs control labels, diagnostics account creation, bucket placement, existing keys, license secret references, and quota requests.
[variables.tf](variables.tf) defines validation and defaults.
The `bootstrap` output contains resource references for Braintrust, without credentials or secret values.
One bootstrap can serve multiple data planes in the dedicated project.

## Resources and access

| Resource | Access |
| --- | --- |
| Deployment account | Workload administration and separate state, evidence, key metadata, and optional license grants. |
| Observer account | Cloud health and metrics. The Braintrust support group can impersonate it. |
| Diagnostics account | Created by default, without permissions or impersonation grants. |
| State bucket | Private, versioned, encrypted storage for later data plane operations. |
| Evidence bucket | Separate private, versioned, encrypted storage. Deployment can create and list objects. |
| APIs and service agents | Required services and Google-managed identities for later deployment. |

The customer credentials require API, service account, custom role, project IAM, bucket, and KMS administration for the declared resources.
Service Usage and Resource Manager access must exist before the first apply.
External key or license projects also require custom role and project IAM access, plus policy access on the selected resources.
License secrets and external project APIs must already exist.

[Permissions](PERMISSIONS.md) describes the grants and their limits.
[Service agents](SERVICE_AGENTS.md) describes API preparation and resource ownership.

## Storage

`state_storage` and `evidence_storage` independently accept `location`, `data_locations`, and `kms_key`.
Location defaults to `region`. Configurable dual-region placement requires two supported regions.
The [location catalog](data/storage-locations.json) defines accepted combinations.

Each bucket uses a separate module-created KMS key unless an existing key is supplied.
An existing key requires a full CryptoKey reference, symmetric encryption, and an enabled primary version.
Its location must match the bucket location. `EU` maps to `europe`. Global keys are unsupported.
The Storage service agent receives encryption access. Deployment receives key metadata access only.
Existing objects still require their original keys after a default key change.

The customer controls this bootstrap root's backend separately from these buckets.
The [customer setup](../../examples/byoc-bootstrap/README.md#setup) covers the optional backend.

## Quotas

Quota requests default to disabled.
`request_quotas = true` requires a customer `quota_contact_email` with quota update permission.
Default regional targets are 500 C4 vCPUs and 22,500 GB of Local SSD.
`quota_preferences` replaces those targets.

Terraform can request decreases after input changes.
The output separates requested values, granted values, and pending status. Apply success does not guarantee capacity.
Existing preferences require import before management.
The customer provider pins version `8.4.0`, which retains quota preferences in Google Cloud after Terraform removal.

## Procedure for the retention handoff

Buckets and module-created keys use `ABANDON`. APIs remain enabled after removal.
Key and platform IAM grants use `prevent_destroy` while their resource configuration remains present.
Module removal removes those guards, so retained resources require an explicit grant handoff.

1. Stop Braintrust operations for this bootstrap.
2. Record the retained buckets, keys, historical key dependencies, and platform grants.
3. Preserve the bootstrap state and its history.
4. From the repository root, review the grant addresses below.

```bash
terraform -chdir=examples/byoc-bootstrap state rm -dry-run \
  'module.bootstrap.google_kms_crypto_key_iam_member.storage_service_agent' \
  'module.bootstrap.google_project_iam_member.service_agents'
```

5. Remove those grants from Terraform state without a cloud revocation.

```bash
terraform -chdir=examples/byoc-bootstrap state rm \
  'module.bootstrap.google_kms_crypto_key_iam_member.storage_service_agent' \
  'module.bootstrap.google_project_iam_member.service_agents'
terraform -chdir=examples/byoc-bootstrap plan -destroy -var-file=customer.tfvars
```

6. Review the destroy plan before module removal.
7. Retain the encryption keys and grants that retained objects require.

Other roots require their actual module addresses.
A later apply can manage the grants again. Retained resources require import before reuse.
[Access control](ACCESS.md) covers revocation without bootstrap removal.

## Validation status

Local tests use mock providers. Live permission, revocation, and lifecycle acceptance remain incomplete.
The output reports `issuable = false`, `machine_execution_supported = false`, and `diagnostics_activation_supported = false`.
Project IAM writes can bypass narrower grants. The module does not establish bootstrap self-protection.
[Design limits](DESIGN.md) lists the remaining checks.

```bash
mise run lint
mise run validate
mise run test
```
