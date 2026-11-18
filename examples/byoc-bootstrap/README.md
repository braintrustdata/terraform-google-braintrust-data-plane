# GCP BYOC v2 customer bootstrap

This root prepares a dedicated GCP project for Braintrust-managed BYOC v2.
Braintrust supplies the customer tfvars file and deploys the data plane after bootstrap.
The repository root and other examples remain separate data plane entry points.

## Setup

1. Obtain the repository revision and customer tfvars file from Braintrust.
2. Place the file at `examples/byoc-bootstrap/customer.tfvars` in that checkout.
3. Review the project ID, project number, and Braintrust bridge identity.
4. Authenticate with customer-controlled Application Default Credentials.
5. For remote bootstrap state, copy `backend.tf.example` to `backend.tf`.
6. If you use that backend, set its existing bucket and prefix.
7. From the repository root, initialize Terraform and create a plan.

```bash
terraform -chdir=examples/byoc-bootstrap init
terraform -chdir=examples/byoc-bootstrap plan -var-file=customer.tfvars -out=bootstrap.tfplan
```

8. Review the plan.
9. Apply the reviewed plan.

```bash
terraform -chdir=examples/byoc-bootstrap apply bootstrap.tfplan
```

10. Export the outputs for Braintrust.

```bash
terraform -chdir=examples/byoc-bootstrap output -json bootstrap
terraform -chdir=examples/byoc-bootstrap output -json quota_preferences
```

## Configuration

The [example tfvars](customer.tfvars.example) shows the format.
The [module inputs](../../modules/byoc-bootstrap/variables.tf) define all options and defaults.
The file contains resource references, not credentials or license values.
The bridge identity controls Braintrust impersonation access and has no default.

Bootstrap state uses local storage unless you configure a backend.
A remote backend requires an existing customer bucket.
The bucket that this module creates stores later data plane state, not this bootstrap state.

## Limits

Live permission and lifecycle acceptance remain incomplete.
The output reports `issuable = false` and unsupported machine execution and diagnostics activation.
A successful apply does not establish deployment readiness or quota approval.

See the [module guide](../../modules/byoc-bootstrap/README.md) for resources, permissions, and removal requirements.
