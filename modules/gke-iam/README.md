<!-- BEGIN_TF_DOCS -->

## Reference

### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.45 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | ~> 6.45 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7.2 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 6.45 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [google_service_account.brainstore](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account.braintrust](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.brainstore_workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_binding.braintrust_workload_identity](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_storage_bucket_iam_member.brainstore_brainstore_gcs_object_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.brainstore_brainstore_gcs_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.braintrust_api_api_bucket_gcs_object_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.braintrust_api_api_bucket_gcs_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.braintrust_api_brainstore_gcs_object_admin](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_bucket_iam_member.braintrust_api_brainstore_gcs_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_member) | resource |
| [google_storage_hmac_key.braintrust](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_hmac_key) | resource |
| [google_project.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_brainstore_gcs_bucket_id"></a> [brainstore\_gcs\_bucket\_id](#input\_brainstore\_gcs\_bucket\_id) | The ID of the GCS bucket for Brainstore. | `string` | n/a | yes |
| <a name="input_brainstore_kube_svc_account"></a> [brainstore\_kube\_svc\_account](#input\_brainstore\_kube\_svc\_account) | The service account of the Brainstore in the GKE cluster. | `string` | `"brainstore"` | no |
| <a name="input_braintrust_api_bucket_id"></a> [braintrust\_api\_bucket\_id](#input\_braintrust\_api\_bucket\_id) | The ID of the GCS bucket for Braintrust API (contains code-bundle/ and response/ paths). | `string` | n/a | yes |
| <a name="input_braintrust_hmac_key_enabled"></a> [braintrust\_hmac\_key\_enabled](#input\_braintrust\_hmac\_key\_enabled) | Whether to enable HMAC keys for Braintrust API. | `bool` | `true` | no |
| <a name="input_braintrust_kube_namespace"></a> [braintrust\_kube\_namespace](#input\_braintrust\_kube\_namespace) | The namespace of the Braintrust service account in the GKE cluster. | `string` | `"braintrust"` | no |
| <a name="input_braintrust_kube_svc_account"></a> [braintrust\_kube\_svc\_account](#input\_braintrust\_kube\_svc\_account) | The service account of the Braintrust API in the GKE cluster. | `string` | `"braintrust-api"` | no |
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment. Used to prefix resource names. | `string` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_brainstore_service_account"></a> [brainstore\_service\_account](#output\_brainstore\_service\_account) | n/a |
| <a name="output_braintrust_hmac_access_id"></a> [braintrust\_hmac\_access\_id](#output\_braintrust\_hmac\_access\_id) | n/a |
| <a name="output_braintrust_hmac_secret"></a> [braintrust\_hmac\_secret](#output\_braintrust\_hmac\_secret) | n/a |
| <a name="output_braintrust_service_account"></a> [braintrust\_service\_account](#output\_braintrust\_service\_account) | n/a |

<!-- END_TF_DOCS -->