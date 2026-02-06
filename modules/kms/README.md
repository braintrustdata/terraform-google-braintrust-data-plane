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
| [google_kms_crypto_key.kms](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key) | resource |
| [google_kms_key_ring.kms](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring) | resource |
| [random_id.key_ring_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [google_client_config.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment. Used to prefix resource names. | `string` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_kms_key_id"></a> [kms\_key\_id](#output\_kms\_key\_id) | n/a |
| <a name="output_kms_key_name"></a> [kms\_key\_name](#output\_kms\_key\_name) | n/a |
| <a name="output_kms_key_ring_id"></a> [kms\_key\_ring\_id](#output\_kms\_key\_ring\_id) | n/a |
| <a name="output_kms_key_ring_name"></a> [kms\_key\_ring\_name](#output\_kms\_key\_ring\_name) | n/a |

<!-- END_TF_DOCS -->