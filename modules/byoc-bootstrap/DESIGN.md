# Bootstrap design limits

The dedicated GCP project is the resource boundary.
One bootstrap can serve multiple data planes, but separate state prefixes do not provide IAM isolation.
The bootstrap ID and project ID determine resource names. The project number provides an identity check before resource creation.

The customer owns project policy, bootstrap state, and emergency account disablement.
Braintrust owns the bridge identity and later data plane deployment.
The module creates no federation pool, service account keys, application configuration, or audit archive.

## Incomplete acceptance

Local mock tests do not establish these properties:

- Effective workload permissions, custom role support, or denied operations.
- Bootstrap self-protection against project IAM writes and role escalation.
- Customer revocation, account restoration, token expiration, or IAM propagation.
- Kubernetes admission policy authorization and workload RBAC.
- Runtime SQL identity preparation, backup creation, or recovery.
- Service-agent activation and effective access to retained encrypted objects.
- Observer response contents and complete health coverage.
- Effective license access and independent deployment readiness.

Temporary diagnostics activation and destructive data cleanup require separate implementation.
Customer issuance and machine execution remain unsupported in the module outputs.

[Permissions](PERMISSIONS.md), [access control](ACCESS.md), and [retention](README.md#procedure-for-the-retention-handoff) describe the implemented controls.
