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

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [google_kms_crypto_key_iam_member.redis_sa_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_redis_instance.braintrust](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance) | resource |
| [google_project.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment. Used to prefix resource names. | `string` | n/a | yes |
| <a name="input_redis_kms_cmek_id"></a> [redis\_kms\_cmek\_id](#input\_redis\_kms\_cmek\_id) | ID of Cloud KMS customer managed encryption key (CMEK) to use for Braintrust Redis instance. | `string` | n/a | yes |
| <a name="input_redis_memory_size_gb"></a> [redis\_memory\_size\_gb](#input\_redis\_memory\_size\_gb) | The size of the Redis instance in GiB. | `number` | `3` | no |
| <a name="input_redis_network"></a> [redis\_network](#input\_redis\_network) | Name of the VPC network to connect to the Redis instance. | `string` | n/a | yes |
| <a name="input_redis_version"></a> [redis\_version](#input\_redis\_version) | The version of Redis software. | `string` | `"REDIS_7_2"` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_redis_auth_string"></a> [redis\_auth\_string](#output\_redis\_auth\_string) | n/a |
| <a name="output_redis_instance_host"></a> [redis\_instance\_host](#output\_redis\_instance\_host) | n/a |
| <a name="output_redis_instance_name"></a> [redis\_instance\_name](#output\_redis\_instance\_name) | n/a |
| <a name="output_redis_instance_port"></a> [redis\_instance\_port](#output\_redis\_instance\_port) | n/a |
| <a name="output_redis_server_ca_certs"></a> [redis\_server\_ca\_certs](#output\_redis\_server\_ca\_certs) | n/a |

<!-- END_TF_DOCS -->