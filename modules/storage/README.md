<!-- BEGIN_TF_DOCS -->

## Reference

### Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 6.45 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.7.2 |

### Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | ~> 6.45 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.7.2 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [google_kms_crypto_key_iam_member.gcp_project_gcs_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_storage_bucket.api](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket.brainstore](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [random_id.gcs_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_client_config.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_project.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_custom_gcs_api_lifecycle_rules"></a> [custom\_gcs\_api\_lifecycle\_rules](#input\_custom\_gcs\_api\_lifecycle\_rules) | Additional lifecycle rules for the API GCS bucket. Allows defining custom object expiration policies for specific prefixes. | <pre>list(object({<br/>    action = object({<br/>      type          = string<br/>      storage_class = optional(string)<br/>    })<br/>    condition = object({<br/>      age                        = optional(number)<br/>      days_since_noncurrent_time = optional(number)<br/>      matches_prefix             = optional(list(string))<br/>      matches_suffix             = optional(list(string))<br/>      with_state                 = optional(string)<br/>    })<br/>  }))</pre> | `[]` | no |
| <a name="input_custom_gcs_brainstore_lifecycle_rules"></a> [custom\_gcs\_brainstore\_lifecycle\_rules](#input\_custom\_gcs\_brainstore\_lifecycle\_rules) | Additional lifecycle rules for the brainstore GCS bucket. Allows defining custom object expiration policies for specific prefixes. | <pre>list(object({<br/>    action = object({<br/>      type          = string<br/>      storage_class = optional(string)<br/>    })<br/>    condition = object({<br/>      age                        = optional(number)<br/>      days_since_noncurrent_time = optional(number)<br/>      matches_prefix             = optional(list(string))<br/>      matches_suffix             = optional(list(string))<br/>      with_state                 = optional(string)<br/>    })<br/>  }))</pre> | `[]` | no |
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment. Used to prefix resource names. | `string` | n/a | yes |
| <a name="input_gcs_additional_allowed_origins"></a> [gcs\_additional\_allowed\_origins](#input\_gcs\_additional\_allowed\_origins) | Additional allowed origins for the Braintrust GCS buckets. | `list(string)` | `[]` | no |
| <a name="input_gcs_bucket_retention_days"></a> [gcs\_bucket\_retention\_days](#input\_gcs\_bucket\_retention\_days) | Number of days to retain objects in the Brainstore GCS buckets. | `number` | `7` | no |
| <a name="input_gcs_force_destroy"></a> [gcs\_force\_destroy](#input\_gcs\_force\_destroy) | Boolean indicating whether to allow force destroying the Braintrust GCS buckets. GCS buckets can be destroyed if it is not empty when `true`. | `bool` | `false` | no |
| <a name="input_gcs_kms_cmek_id"></a> [gcs\_kms\_cmek\_id](#input\_gcs\_kms\_cmek\_id) | ID of Cloud KMS customer managed encryption key (CMEK) to use for Braintrust GCS buckets encryption. | `string` | `null` | no |
| <a name="input_gcs_soft_delete_retention_days"></a> [gcs\_soft\_delete\_retention\_days](#input\_gcs\_soft\_delete\_retention\_days) | Number of days to retain soft-deleted objects in Braintrust GCS buckets. During this period, deleted objects can be recovered. Set to 0 to disable soft delete policy. This value must be be 0 or between 7 and 90 days. | `number` | `7` | no |
| <a name="input_gcs_storage_class"></a> [gcs\_storage\_class](#input\_gcs\_storage\_class) | Storage class of Braintrust GCS buckets. | `string` | `"STANDARD"` | no |
| <a name="input_gcs_uniform_bucket_level_access"></a> [gcs\_uniform\_bucket\_level\_access](#input\_gcs\_uniform\_bucket\_level\_access) | Boolean to enable uniform bucket level access on Braintrust GCS buckets. | `bool` | `true` | no |
| <a name="input_gcs_versioning_enabled"></a> [gcs\_versioning\_enabled](#input\_gcs\_versioning\_enabled) | Boolean to enable versioning on Braintrust GCS buckets. | `bool` | `true` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_bucket_name"></a> [api\_bucket\_name](#output\_api\_bucket\_name) | n/a |
| <a name="output_api_bucket_self_link"></a> [api\_bucket\_self\_link](#output\_api\_bucket\_self\_link) | n/a |
| <a name="output_brainstore_bucket_name"></a> [brainstore\_bucket\_name](#output\_brainstore\_bucket\_name) | n/a |
| <a name="output_brainstore_bucket_self_link"></a> [brainstore\_bucket\_self\_link](#output\_brainstore\_bucket\_self\_link) | n/a |

<!-- END_TF_DOCS -->