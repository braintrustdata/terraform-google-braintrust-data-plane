# Bootstrap candidate design

## Accepted boundary

The module serves the same preparation role as the generated AWS CloudFormation bootstrap.
It prepares a dedicated customer project, exact access paths, and customer-owned state and operation evidence storage.
The customer controls the bootstrap root's backend, including an existing remote bucket or local state.
Audit configuration remains deferred. Quota preferences now use native Terraform resources.

## Resource and authority inventory

| Resource | Module behavior | Authority |
| --- | --- | --- |
| Deployment account | One deterministic service account. | State access and operation evidence creation only in this candidate. |
| Observer account | One deterministic service account. | Project, service, and metric metadata. |
| Diagnostics account | Present by default, absent after explicit opt-out. | No trust grants or resource permissions. |
| Deployment trust | Exact assigned Braintrust bridge account. | Token Creator on Deployment only. |
| Observer trust | `group:byoc-support@braintrustdata.com`. | Token Creator on Observer only. |
| State bucket | Private, uniform IAM, version history, retained on removal. | Deployment can read and update state and backend locks. |
| Evidence bucket | Separate private, versioned bucket, retained on removal. | Deployment can create and list evidence objects. |
| APIs | The pinned v1 service list plus Service Usage. | Customer credentials enable services and preserve them on removal. |
| Storage service identity | Initialized after the API resources. | No additional module grant. |
| Quota preferences | Optional native Terraform resources with the v1 target values. | Customer credentials submit preferences after plan review. |

The custom roles and exact trust grants reside directly in `permissions.tf`.
This module owns the draft permission definitions during internal iteration.
It has no dependency on Outpost's draft exporter or a separate bootstrap repository.
A future integration must define compatibility checks before customer issuance.
The module accepts no arbitrary privileged principal or role list.

The state role applies only to the state bucket.
The evidence role applies only to the evidence bucket and excludes content reads, replacement, and deletion.
Neither role applies across the project.
Observer receives no secret values, application logs, object contents, workload mutation, or IAM administration.
Effective denials still require live acceptance.

The bootstrap ID and project ID determine resource names.
The project number receives an explicit metadata check before resource creation.
Changes to project identity, bootstrap ID, or bucket location require separate replacement review.
Storage preservation does not imply automatic adoption of an abandoned bucket on a later reapply.

## State and evidence layout

The module exports a base prefix for each destination.
Later Outpost work derives data plane and root locations from trusted persisted identities.
The module does not accept caller-selected state object keys or create per-operation objects.
Separate paths and locks do not prove IAM isolation between data planes under the same bootstrap.
The dedicated project remains the customer resource boundary.

The evidence bucket stores Outpost intent and result records.
It is not a cloud audit archive or a shell transcript destination.
No retention lock or immutable audit guarantee is claimed.

## Customer emergency revocation

Direct service account disablement remains customer-controlled.
Terraform ignores the `disabled` property after creation, so routine reapply does not re-enable an account.
The module owns its declared IAM member resources.
Terraform can restore those resources after out-of-band grant removal.
The final design must resolve that restoration behavior before customer issuance.

There is no Outpost retry, readiness, or automatic reconciliation path in this candidate.
Customer revocation requires no Outpost availability or evidence delivery.
Existing token behavior and propagation limits remain part of live acceptance.

## Quota preference boundary

Quota requests default to disabled.
Enabled requests use the customer project number and selected region.
The v1 CPU and Local SSD targets remain the baseline.
Customer overrides replace the baseline map and preserve the selected region.
No Google quota safety check is bypassed.

The provider submits preferences and reads their current status without a guarantee of Google approval.
The output exposes requested values separately from granted values and the `reconciling` status.
Terraform apply success is not deployment capacity acceptance.

The former helper skipped requests when the current limit already exceeded the target.
Native Terraform manages declared preferences and can request decreases after edits.
The customer reviews these changes through Terraform plan and apply.
Existing preferences require import before management.

The pinned provider's delete operation removes preferences from Terraform state only.
Google retains the preferences after module removal or request opt-out.
Re-adoption requires import rather than a duplicate create request.

## Remaining acceptance gates

- Reviewed workload deployment permissions and negative privilege-path tests.
- Complete Observer capability coverage and effective denied-operation tests.
- The INF-870 temporary Diagnostics mechanism and its customer approval contract.
- Final trust removal and restoration semantics under customer Terraform reapply.
- Outpost package generation, registration, and cloud readiness integration.
- Live infrastructure and lifecycle acceptance under the reduced permission model.

The output reports `issuable = false` and unsupported machine execution and Diagnostics activation.
No immutable customer contract revision is assigned.
The module candidate does not complete INF-733 or authorize general customer issuance.

## Mechanism references

The pinned [Google provider reference](https://github.com/hashicorp/terraform-provider-google/blob/v8.4.0/website/docs/r/storage_bucket.html.markdown) defines bucket abandonment behavior.
The [Cloud Storage insertion reference](https://docs.cloud.google.com/storage/docs/json_api/v1/objects/insert) defines object creation and overwrite permissions.
The [quota preference reference](https://github.com/hashicorp/terraform-provider-google/blob/v8.4.0/website/docs/r/cloud_quotas_quota_preference.html.markdown) defines quota inputs and status outputs.
The pinned [quota resource source](https://github.com/hashicorp/terraform-provider-google/blob/v8.4.0/google/services/cloudquotas/resource_cloud_quotas_quota_preference.go) defines request and removal behavior.
