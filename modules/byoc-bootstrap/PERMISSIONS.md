# Bootstrap permissions

Terraform defines every permission explicitly in the files below.
Deployment retains project IAM writes and custom role administration. These permissions can bypass narrower grants and affect bootstrap controls.
The roles do not establish effective isolation or bootstrap self-protection.

| Identity | Grants | Definition |
| --- | --- | --- |
| Deployment | Workload administration for IAM, GKE, Kubernetes, networking, SQL, KMS, Redis, Storage, secrets, DNS, and service status. | [permissions-deployment.tf](permissions-deployment.tf) |
| Deployment | State object access and evidence creation/list access on separate buckets. | [permissions-deployment.tf](permissions-deployment.tf) |
| Deployment | Metadata access on selected keys and external resource projects. | [permissions-deployment.tf](permissions-deployment.tf) |
| Deployment | Read access on exact `license_secrets` references, when supplied. | [permissions-deployment.tf](permissions-deployment.tf) |
| Observer | Cloud health, metrics, and alert metadata. | [permissions-observer.tf](permissions-observer.tf) |
| Diagnostics | None. | [permissions-diagnostics.tf](permissions-diagnostics.tf) |
| Google service agents | Service-specific project roles and Storage key access. | [service-agents.tf](service-agents.tf), [storage.tf](storage.tf) |

The assigned Braintrust bridge can impersonate Deployment.
`group:byoc-support@braintrustdata.com` can impersonate Observer.
Workload runtime grants belong to the data plane module.

## Grant boundaries

- Workload Storage and KMS grants exclude direct administration of bootstrap buckets and their selected keys.
- Evidence permits object creation and list access, without content reads, replacement, or deletion.
- Managed PostgreSQL secret access uses the reserved `-postgres-password` suffix. The suffix does not prove resource ownership.
- License references grant metadata and version reads on exact existing global secrets. Terraform does not fetch their values.
- Selected-key grants permit metadata and policy reads, without cryptographic use or policy changes.
- External resource projects grant only `iam.roles.get` and `resourcemanager.projects.get` for readiness metadata.

Deployment excludes direct token creation, service account keys, HMAC, interactive pod sessions, logs, and general object payload access.
It also excludes API disablement, quota administration, destructive KMS operations, private Artifact Registry administration, and organization administration.
SQL permissions cover initial user creation, not a complete password rotation workflow.
Destructive data cleanup and backup restoration require separate implementation.

Observer excludes Kubernetes workload configuration, logs, secret values, object payloads, Redis AUTH strings, and database access.
Its project-scoped metadata grants do not isolate data planes within one project.

The [design limits](DESIGN.md) describe the live checks that remain incomplete.
