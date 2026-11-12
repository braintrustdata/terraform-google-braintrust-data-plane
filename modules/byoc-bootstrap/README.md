# Braintrust GCP BYOC bootstrap

This Terraform module prepares an existing dedicated customer project for Braintrust Outpost.
One bootstrap supports multiple data planes with separate state locations.

The current candidate is draft and non-issuable.
It creates the bootstrap foundation without infrastructure deployment permissions or temporary Diagnostics access.
Its outputs explicitly report those unsupported capabilities.
Live permission and lifecycle acceptance remain pending.

Permissions reside directly in [permissions.tf](permissions.tf) during internal iteration.
This branch uses no exported access definition or contract manifest.
Customer release still requires an accepted compatibility check between Outpost and the bootstrap.

## Resources

The module creates:

- Deployment and Observer service accounts with deterministic names.
- An optional dormant Diagnostics account, enabled by default.
- Exact bridge-to-Deployment and support-group-to-Observer trust grants.
- A limited Observer role for project, service, and metric metadata.
- Separate private, versioned buckets for data plane state and operation evidence.
- Bucket-scoped Deployment grants for state access and evidence creation.
- The v1 service API baseline and the Cloud Storage service identity.
- Optional Terraform quota preferences with the v1 target values.

The module creates no data plane infrastructure, application resources, or Datadog resources.
The module creates no customer WIF pool, service account keys, or audit configuration.
Braintrust owns the separate bridge project and bootstrap-specific bridge identity.
The customer retains project, billing, organization policy, and emergency revocation control.

## Inputs and handoff

| Input | Owner | Purpose |
| --- | --- | --- |
| `project_id` | Customer | Existing dedicated project. |
| `project_number` | Customer and Outpost | Exact project identity check. |
| `region` | Customer | Storage location and quota request region. |
| `labels` | Customer | Additional resource labels. |
| `enable_diagnostics` | Customer | Dormant account creation, default `true`. |
| `bootstrap_id` | Outpost | Canonical bootstrap identity and deterministic resource names. |
| `braintrust_bridge_service_account` | Outpost | Exact assigned Braintrust bridge identity. |
| `request_quotas` | Customer | Quota preference management, default `false`. |
| `quota_contact_email` | Customer | Google account for quota communication, required when requests are enabled. |
| `quota_preferences` | Customer | Optional replacement for the v1 quota targets. |

Outpost will provide a pinned root and a customer-specific tfvars file.
The example root uses `modules/byoc-bootstrap` and does not call the workload module.
The later package generator will pin the repository commit and the `modules/byoc-bootstrap` subdirectory.
The tfvars file contains no credentials or license values.
The project number must match the project ID before resource creation.

## Bootstrap state

The customer chooses the backend for this bootstrap root.
Remote bootstrap state requires an existing customer bucket with customer-controlled location and access permissions.
Backend configuration remains separate from module tfvars.
The example uses local state unless the customer configures the optional backend.
Remote state is preferred.

The module's state bucket serves later Outpost data plane operations.
It is separate from the backend for this bootstrap root.
The module does not create state objects for individual data planes.

Run the following example commands from the repository root.

## Example plan procedure

1. Review the candidate limitations in [DESIGN.md](DESIGN.md).
2. Select the customer project and its existing billing configuration.
3. Authenticate with customer-controlled Application Default Credentials.
4. Verify that Service Usage and Cloud Resource Manager APIs are available for the initial project lookup.
5. Copy `examples/byoc-bootstrap/customer.tfvars.example` to `examples/byoc-bootstrap/customer.tfvars`.
6. Replace the placeholders with the reviewed handoff values.
7. Select the bootstrap backend before initialization.
8. Initialize the example root.
9. Review its plan.

```bash
terraform -chdir=examples/byoc-bootstrap init
terraform -chdir=examples/byoc-bootstrap plan -var-file=customer.tfvars
```

## Optional remote backend procedure

1. Supply an existing customer bucket with the required access controls.
2. Copy `examples/byoc-bootstrap/backend.tf.example` to `examples/byoc-bootstrap/backend.tf`.
3. Copy `examples/byoc-bootstrap/bootstrap.backend.hcl.example` to `examples/byoc-bootstrap/bootstrap.backend.hcl`.
4. Set the bucket and prefix in `bootstrap.backend.hcl`.
5. Initialize the backend before the first bootstrap plan.

```bash
terraform -chdir=examples/byoc-bootstrap init -backend-config=bootstrap.backend.hcl
```

The backend file does not set bucket location or IAM.
The customer controls those properties on the existing bucket.

## Quota review

Quota preferences use the native `google_cloud_quotas_quota_preference` resource.
The module includes no quota shell helper.
Requests default to disabled and require `request_quotas = true`.
The customer reviews the requests in the Terraform plan and authorizes them through apply.

The baseline preserves the v1 C4 targets in `data/quota-defaults.json`:

- 500 vCPUs in the selected region.
- 22,500 GB of Local SSD in the selected region.

The contact email must identify a customer Google account with quota update permission.
The customer Terraform credentials require quota administration authority.
The module grants no quota administration role to Outpost.

Terraform manages declared preferences, including requested decreases after configuration edits.
A successful apply can leave a request pending Google approval.
The `quota_preferences` output separates requested values, granted values, and pending status.
It does not establish effective deployment capacity.

## Quota review procedure

1. Set `request_quotas = true` in the customer tfvars file.
2. Set `quota_contact_email` to the authorized customer contact.
3. If different targets are necessary, set `quota_preferences` in the customer tfvars file.
4. Review the requested values in the Terraform plan.
5. If a plan requests a decrease, review its effect before apply.
6. After an authorized apply, inspect the quota output.
7. Verify effective capacity before data plane deployment.

```bash
terraform -chdir=examples/byoc-bootstrap plan -var-file=customer.tfvars
terraform -chdir=examples/byoc-bootstrap output -json quota_preferences
```

## Existing quota preferences

Google permits only one preference for each quota and dimension combination.
Existing preferences require import before Terraform can manage them.
The module leaves preference names to Google, so an imported name remains valid.

## Quota adoption procedure

1. Set the intended quota inputs in `customer.tfvars`.
2. Identify the existing preference's resource name.
3. Import the preference into its matching module resource.
4. Review the subsequent Terraform plan before apply.

```bash
terraform -chdir=examples/byoc-bootstrap import -var-file=customer.tfvars \
  'module.bootstrap.google_cloud_quotas_quota_preference.requested["c4-vcpus"]' \
  'projects/<project-number>/locations/global/quotaPreferences/<preference-name>'
```

## Removal and revocation

Both buckets use `deletion_policy = "ABANDON"` and `force_destroy = false`.
Bootstrap removal retains the buckets and their contents, including empty buckets.
The customer controls their later deletion through a separate explicit action.
The module leaves enabled APIs active on removal.
Managed trust and access grants are removed with their Terraform resources.

The pinned provider removes quota preferences from Terraform state without deleting them from Google Cloud.
Disabling quota requests or removing the bootstrap does not reset the granted quota.
Later Terraform adoption requires import of the preserved preferences.

Customers can disable service accounts directly for emergency revocation.
The module ignores subsequent changes to their `disabled` property and does not re-enable them on reapply.
An out-of-band IAM grant removal remains Terraform drift.
A customer Terraform reapply can restore declared IAM grants.
The final revocation contract requires further review before customer issuance.

## Local verification

The tests use a mocked Google provider and make no cloud changes.
The checked-in lockfiles pin Google `8.4.0` for repository tests and the example root.
Live creation, convergence, denied access, and removal remain unverified.

## Local verification procedure

1. Use Terraform `1.15.8` for the pinned test baseline.
2. Run the local checks without cloud credentials.

```bash
bash scripts/check-byoc-bootstrap.sh
```
