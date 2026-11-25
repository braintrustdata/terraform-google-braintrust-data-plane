# Loop workers on an existing GKE cluster

Call this module from your own Terraform when your platform already provisions
the worker cluster, networking, DNS, checkpoint storage and runtime identity.
It installs Sandbox Service, manages persistent mTLS and returns the complete
Loop Helm configuration. The data-plane module calls this same installer with
`enable_loop_runtime = true`.

```hcl
module "loop" {
  source = "github.com/braintrustdata/terraform-google-braintrust-data-plane//modules/gke-loop-bootstrap"

  deployment_name              = var.deployment_name
  region                       = var.region
  endpoint                     = module.platform.worker_api_dns_endpoint
  runtime_service_account      = module.platform.loop_runtime_service_account
  deploy_service_account_email = var.deploy_service_account_email
  workers                      = module.platform.workers
}

output "loop_runtime_helm_values_yaml" {
  value = module.loop.helm_values_yaml
}
```

Here `module.platform` represents your existing infrastructure, not another
Braintrust module. `endpoint` is its IAM-authenticated GKE DNS API URL, including
`https://`. `workers` has the same shape as the data-plane `gke_isolated_workers`
output: `checkpoint_store`, `discovery` and `loop_egress`. `discovery` supplies the worker `hostname`, HTTPS `endpoint`, and
`external_dns_extra_args` selecting the project and private zone; the namespace
defaults to `braintrust-sandbox` and the DNS service account is `external-dns`.
`loop_egress` supplies the Git proxy's `address`, `url` and worker `source_ranges`.

Workers need the documented [KVM, storage and network configuration](../../ISOLATED_WORKERS.md).
The supplied runtime identity needs Workload Identity and API/Brainstore bucket
access; the module adds client-bundle access only. The installer account needs
Kubernetes administration and the Terraform caller must be able to act as it;
omitting that account creates a project Kubernetes administrator automatically.
The Terraform caller needs `roles/run.developer` to create the installer job.
Managed bootstrap deployment roles include it; grant it separately for other callers.

After apply, pass `loop_runtime_helm_values_yaml` after your existing Helm values,
or pass `module.loop.loop_runtime` to the GKE app module. Existing placement,
Cloud SQL Proxy and organization settings remain in your primary Helm values.
Use `options` for worker image, capacity and Helm overrides, as described in the
[Loop configuration guide](../../ISOLATED_WORKERS.md#enable-loop).

Failed executions block ready outputs. After fixing the cause, retry with
`terraform apply -replace=module.loop.terraform_data.execution`; the worker
cluster and TLS remain in place. See [retrying a failed install](../../ISOLATED_WORKERS.md#retrying-a-failed-install).
