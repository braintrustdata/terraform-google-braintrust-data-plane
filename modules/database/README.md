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
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | ~> 6.45 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.7.2 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [google-beta_google_project_service_identity.cloud_sql_sa](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_project_service_identity) | resource |
| [google_kms_crypto_key_iam_member.cloud_sql_sa_postgres_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_secret_manager_secret.postgres_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret) | resource |
| [google_secret_manager_secret_version.postgres_password](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version) | resource |
| [google_sql_database_instance.braintrust](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance) | resource |
| [google_sql_user.braintrust](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |
| [google_sql_user.braintrust_iam](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user) | resource |
| [random_id.postgres_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.postgres_password](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [google_client_config.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment. Used to prefix resource names. | `string` | n/a | yes |
| <a name="input_postgres_availability_type"></a> [postgres\_availability\_type](#input\_postgres\_availability\_type) | Availability type of Cloud SQL for PostgreSQL instance. | `string` | `"REGIONAL"` | no |
| <a name="input_postgres_backup_start_time"></a> [postgres\_backup\_start\_time](#input\_postgres\_backup\_start\_time) | HH:MM time format indicating when daily automatic backups of Cloud SQL for PostgreSQL should run. Defaults to 12 AM (midnight) UTC. | `string` | `"00:30"` | no |
| <a name="input_postgres_deletion_protection"></a> [postgres\_deletion\_protection](#input\_postgres\_deletion\_protection) | Whether to protect the Cloud SQL for PostgreSQL instance from deletion. | `bool` | `true` | no |
| <a name="input_postgres_disk_size"></a> [postgres\_disk\_size](#input\_postgres\_disk\_size) | Size in GB of PostgreSQL disk. | `number` | `1000` | no |
| <a name="input_postgres_enable_seqscan"></a> [postgres\_enable\_seqscan](#input\_postgres\_enable\_seqscan) | Whether to enable seqscan. Setting this to true requires a DB restart. Should only be enabled if directed by Braintrust support team. | `bool` | `false` | no |
| <a name="input_postgres_insights_config"></a> [postgres\_insights\_config](#input\_postgres\_insights\_config) | Configuration settings for Cloud SQL for PostgreSQL insights. | <pre>object({<br/>    query_insights_enabled  = bool<br/>    query_plans_per_minute  = number<br/>    query_string_length     = number<br/>    record_application_tags = bool<br/>    record_client_address   = bool<br/>  })</pre> | <pre>{<br/>  "query_insights_enabled": true,<br/>  "query_plans_per_minute": 5,<br/>  "query_string_length": 1024,<br/>  "record_application_tags": true,<br/>  "record_client_address": true<br/>}</pre> | no |
| <a name="input_postgres_kms_cmek_id"></a> [postgres\_kms\_cmek\_id](#input\_postgres\_kms\_cmek\_id) | ID of Cloud KMS customer managed encryption key (CMEK) to use for Cloud SQL for PostgreSQL database instance. If this is not provided, the database will be encrypted with a Google-managed key. | `string` | n/a | yes |
| <a name="input_postgres_machine_type"></a> [postgres\_machine\_type](#input\_postgres\_machine\_type) | Machine size of Cloud SQL for PostgreSQL instance. | `string` | `"db-perf-optimized-N-8"` | no |
| <a name="input_postgres_maintenance_window"></a> [postgres\_maintenance\_window](#input\_postgres\_maintenance\_window) | Optional maintenance window settings for the Cloud SQL for PostgreSQL instance. | <pre>object({<br/>    day          = number<br/>    hour         = number<br/>    update_track = string<br/>  })</pre> | <pre>{<br/>  "day": 1,<br/>  "hour": 8,<br/>  "update_track": "stable"<br/>}</pre> | no |
| <a name="input_postgres_network"></a> [postgres\_network](#input\_postgres\_network) | Name of the VPC network to connect to the Cloud SQL for PostgreSQL instance. | `string` | n/a | yes |
| <a name="input_postgres_ssl_mode"></a> [postgres\_ssl\_mode](#input\_postgres\_ssl\_mode) | Indicates whether to enforce TLS/SSL connections to the Cloud SQL for PostgreSQL instance. | `string` | `"ENCRYPTED_ONLY"` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL version to use. | `string` | `"POSTGRES_17"` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_postgres_iam_username"></a> [postgres\_iam\_username](#output\_postgres\_iam\_username) | IAM database user name for Cloud SQL IAM authentication |
| <a name="output_postgres_instance_ip"></a> [postgres\_instance\_ip](#output\_postgres\_instance\_ip) | n/a |
| <a name="output_postgres_instance_name"></a> [postgres\_instance\_name](#output\_postgres\_instance\_name) | n/a |
| <a name="output_postgres_password"></a> [postgres\_password](#output\_postgres\_password) | n/a |
| <a name="output_postgres_password_secret_name"></a> [postgres\_password\_secret\_name](#output\_postgres\_password\_secret\_name) | n/a |
| <a name="output_postgres_username"></a> [postgres\_username](#output\_postgres\_username) | n/a |

<!-- END_TF_DOCS -->