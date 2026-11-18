# APIs and service agents

Customer credentials enable the APIs in [services.json](data/services.json) and prepare the service agents below.
Cloud Quotas is added only when `request_quotas = true`.
Deployment receives no API enablement or quota administration grant.

| Service agent | Preparation | Project role |
| --- | --- | --- |
| GKE | Explicit identity resource. | `roles/container.serviceAgent` |
| Redis | Explicit identity resource. | `roles/redis.serviceAgent` |
| Service Networking | Explicit identity resource. | `roles/servicenetworking.serviceAgent` |
| Cloud DNS | Explicit identity resource. | `roles/dns.serviceAgent` |
| Compute | API activation. | `roles/compute.serviceAgent` |
| GKE node | API activation. | `roles/container.defaultNodeServiceAgent` |
| Storage | Storage identity lookup. | Selected-key encryption grants only. |

Explicit identities use `google-beta` and require the expected project-specific email and member.
Platform roles bind only to the matching Google-managed principal.
The data plane database module owns the SQL identity and its workload key grant. Bootstrap enables the SQL API only.
Other workload key grants also belong to the data plane module.

The `required_apis` and `service_agents` outputs record configuration, not effective readiness.
Identity resource refresh does not detect every missing identity or revoked grant.
Live readiness requires separate identity, API, and effective-access checks.

APIs remain enabled after removal. Platform grants require the [retention handoff](README.md#procedure-for-the-retention-handoff).
API propagation and Compute/GKE node agent activation still require live tests.

References: [Google service agents](https://docs.cloud.google.com/iam/docs/service-agents), [Storage service agent](https://docs.cloud.google.com/storage/docs/getting-service-agent), [provider identity resource](https://github.com/hashicorp/terraform-provider-google-beta/blob/v8.4.0/google-beta/services/resourcemanager/resource_project_service_identity.go).
