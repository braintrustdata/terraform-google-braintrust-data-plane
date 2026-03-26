# Braintrust Terraform Google Module

This module is currently beta status. There may be breaking changes that require a complete deletion and re-deployment

This module is used to create the VPC, Databases, Redis, Storage, IAM, and associated resources for the self-hosted Braintrust data plane on Google using Google Kubernetes Engine.

## Module Configuration

Module input variables are defined in [`variables.tf`](variables.tf) and
outputs are defined in [`outputs.tf`](outputs.tf).

## How to use this module

To use this module, **copy the [`examples/braintrust-data-plane`](examples/braintrust-data-plane) directory to a new Terraform directory in your own repository**. Follow the instructions in the [README.md](examples/braintrust-data-plane/README.md) file in that directory to configure the module for your environment.

Please review the README.md in the examples for all Pre-deployment and Post-Deployment steps in order to deploy Braintrust on Google.

The default configuration is a large production-sized deployment. Please consider that when testing and adjust the configuration to use smaller sized resources.

## Development Setup

This section is only relevant if you are a contributor who wants to make changes to this module. All others can skip this section.

1. Clone the repository
2. Install [mise](https://mise.jdx.dev/about.html):

    ```bash
    curl https://mise.run | sh
    echo 'eval "$(mise activate zsh)"' >> "~/.zshrc"
    echo 'eval "$(mise activate zsh --shims)"' >> ~/.zprofile
    exec $SHELL
    ```

3. Run `mise install` to install required tools
4. Run `mise run setup` to install pre-commit hooks

## TODO

- Logging is configured to use the default project log sink, need to determine if a custom log sink will be needed.
- This module will fail the first time it is deployed due to timing issue with the private connection for the VPC. Exploring ways to fix this still without adding a module depends on which causes issues.
- Explore customer support module like AWS module
- Explore optional cloud-run module as front end for braintrust api frontend
- Explore using Terraform to enable google services instead of CLI/GUI
- Test support for GKE auto pilot nodes

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

No providers.

### Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_database"></a> [database](#module\_database) | ./modules/database | n/a |
| <a name="module_gke-cluster"></a> [gke-cluster](#module\_gke-cluster) | ./modules/gke-cluster | n/a |
| <a name="module_gke-iam"></a> [gke-iam](#module\_gke-iam) | ./modules/gke-iam | n/a |
| <a name="module_kms"></a> [kms](#module\_kms) | ./modules/kms | n/a |
| <a name="module_redis"></a> [redis](#module\_redis) | ./modules/redis | n/a |
| <a name="module_storage"></a> [storage](#module\_storage) | ./modules/storage | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./modules/vpc | n/a |

### Resources

No resources.

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_brainstore_kube_svc_account"></a> [brainstore\_kube\_svc\_account](#input\_brainstore\_kube\_svc\_account) | The service account name for Brainstore. | `string` | `"brainstore"` | no |
| <a name="input_braintrust_hmac_key_enabled"></a> [braintrust\_hmac\_key\_enabled](#input\_braintrust\_hmac\_key\_enabled) | Whether to enable HMAC keys for Braintrust API. | `bool` | `true` | no |
| <a name="input_braintrust_kube_namespace"></a> [braintrust\_kube\_namespace](#input\_braintrust\_kube\_namespace) | The namespace name that Braintrust will be deployed into, in the GKE cluster. | `string` | `"braintrust"` | no |
| <a name="input_braintrust_kube_svc_account"></a> [braintrust\_kube\_svc\_account](#input\_braintrust\_kube\_svc\_account) | The service account name for Braintrust API. | `string` | `"braintrust-api"` | no |
| <a name="input_create_vpc"></a> [create\_vpc](#input\_create\_vpc) | Whether to create a new VPC or use an existing one. | `bool` | `true` | no |
| <a name="input_custom_gcs_api_lifecycle_rules"></a> [custom\_gcs\_api\_lifecycle\_rules](#input\_custom\_gcs\_api\_lifecycle\_rules) | Additional lifecycle rules for the API GCS bucket. Allows defining custom object expiration policies for specific prefixes. | <pre>list(object({<br/>    action = object({<br/>      type          = string<br/>      storage_class = optional(string)<br/>    })<br/>    condition = object({<br/>      age                        = optional(number)<br/>      days_since_noncurrent_time = optional(number)<br/>      matches_prefix             = optional(list(string))<br/>      matches_suffix             = optional(list(string))<br/>      with_state                 = optional(string)<br/>    })<br/>  }))</pre> | `[]` | no |
| <a name="input_custom_gcs_brainstore_lifecycle_rules"></a> [custom\_gcs\_brainstore\_lifecycle\_rules](#input\_custom\_gcs\_brainstore\_lifecycle\_rules) | Additional lifecycle rules for the brainstore GCS bucket. Allows defining custom object expiration policies for specific prefixes. | <pre>list(object({<br/>    action = object({<br/>      type          = string<br/>      storage_class = optional(string)<br/>    })<br/>    condition = object({<br/>      age                        = optional(number)<br/>      days_since_noncurrent_time = optional(number)<br/>      matches_prefix             = optional(list(string))<br/>      matches_suffix             = optional(list(string))<br/>      with_state                 = optional(string)<br/>    })<br/>  }))</pre> | `[]` | no |
| <a name="input_deploy_gke_cluster"></a> [deploy\_gke\_cluster](#input\_deploy\_gke\_cluster) | Whether to deploy the GKE cluster. | `bool` | `true` | no |
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment. Used to prefix resource names. | `string` | n/a | yes |
| <a name="input_existing_network_self_link"></a> [existing\_network\_self\_link](#input\_existing\_network\_self\_link) | Self link of an existing VPC network (required when create\_vpc is false). | `string` | `null` | no |
| <a name="input_existing_subnet_self_link"></a> [existing\_subnet\_self\_link](#input\_existing\_subnet\_self\_link) | Self link of an existing subnet (required when create\_vpc is false). | `string` | `null` | no |
| <a name="input_gcs_additional_allowed_origins"></a> [gcs\_additional\_allowed\_origins](#input\_gcs\_additional\_allowed\_origins) | Additional allowed origins for the Braintrust GCS buckets. | `list(string)` | `[]` | no |
| <a name="input_gcs_bucket_retention_days"></a> [gcs\_bucket\_retention\_days](#input\_gcs\_bucket\_retention\_days) | Number of days to retain objects in the Brainstore GCS buckets. | `number` | `7` | no |
| <a name="input_gcs_force_destroy"></a> [gcs\_force\_destroy](#input\_gcs\_force\_destroy) | Whether to force destroy the GCS buckets. | `bool` | `false` | no |
| <a name="input_gcs_soft_delete_retention_days"></a> [gcs\_soft\_delete\_retention\_days](#input\_gcs\_soft\_delete\_retention\_days) | Number of days to retain soft-deleted objects in Braintrust GCS buckets. During this period, deleted objects can be recovered. Set to 0 to disable soft delete policy. This value must be be 0 or between 7 and 90 days. | `number` | `7` | no |
| <a name="input_gcs_storage_class"></a> [gcs\_storage\_class](#input\_gcs\_storage\_class) | Storage class of Braintrust GCS buckets. | `string` | `"STANDARD"` | no |
| <a name="input_gcs_uniform_bucket_level_access"></a> [gcs\_uniform\_bucket\_level\_access](#input\_gcs\_uniform\_bucket\_level\_access) | Boolean to enable uniform bucket level access on Braintrust GCS buckets. | `bool` | `true` | no |
| <a name="input_gcs_versioning_enabled"></a> [gcs\_versioning\_enabled](#input\_gcs\_versioning\_enabled) | Boolean to enable versioning on Braintrust GCS buckets. | `bool` | `true` | no |
| <a name="input_gke_cluster_is_private"></a> [gke\_cluster\_is\_private](#input\_gke\_cluster\_is\_private) | Whether to deploy the GKE cluster in a private network. | `bool` | `false` | no |
| <a name="input_gke_control_plane_authorized_cidrs"></a> [gke\_control\_plane\_authorized\_cidrs](#input\_gke\_control\_plane\_authorized\_cidrs) | List of CIDR blocks authorized to access the GKE control plane. If not provided, allows all IPs (for public clusters). | `list(string)` | `null` | no |
| <a name="input_gke_control_plane_cidr"></a> [gke\_control\_plane\_cidr](#input\_gke\_control\_plane\_cidr) | The CIDR block for the GKE control plane. | `string` | `"10.0.1.0/28"` | no |
| <a name="input_gke_deletion_protection"></a> [gke\_deletion\_protection](#input\_gke\_deletion\_protection) | Whether to protect the GKE cluster from deletion. | `bool` | `true` | no |
| <a name="input_gke_enable_master_global_access"></a> [gke\_enable\_master\_global\_access](#input\_gke\_enable\_master\_global\_access) | Whether to enable global access to the GKE control plane from any region. | `bool` | `false` | no |
| <a name="input_gke_enable_private_endpoint"></a> [gke\_enable\_private\_endpoint](#input\_gke\_enable\_private\_endpoint) | Whether to enable private endpoint for the GKE cluster. | `bool` | `true` | no |
| <a name="input_gke_maintenance_window"></a> [gke\_maintenance\_window](#input\_gke\_maintenance\_window) | Optional maintenance window settings for the GKE cluster. | <pre>object({<br/>    day        = number<br/>    start_time = string<br/>  })</pre> | <pre>{<br/>  "day": 1,<br/>  "start_time": "08:00"<br/>}</pre> | no |
| <a name="input_gke_release_channel"></a> [gke\_release\_channel](#input\_gke\_release\_channel) | The release channel of the GKE cluster. | `string` | `"REGULAR"` | no |
| <a name="input_postgres_availability_type"></a> [postgres\_availability\_type](#input\_postgres\_availability\_type) | Availability type of Cloud SQL for PostgreSQL instance. | `string` | `"REGIONAL"` | no |
| <a name="input_postgres_backup_start_time"></a> [postgres\_backup\_start\_time](#input\_postgres\_backup\_start\_time) | HH:MM time format indicating when daily automatic backups of Cloud SQL for PostgreSQL should run. Defaults to 12 AM (midnight) UTC. | `string` | `"00:30"` | no |
| <a name="input_postgres_deletion_protection"></a> [postgres\_deletion\_protection](#input\_postgres\_deletion\_protection) | Whether to protect the Cloud SQL for PostgreSQL instance from deletion. | `bool` | `true` | no |
| <a name="input_postgres_disk_size"></a> [postgres\_disk\_size](#input\_postgres\_disk\_size) | Size in GB of PostgreSQL disk. | `number` | `1000` | no |
| <a name="input_postgres_enable_seqscan"></a> [postgres\_enable\_seqscan](#input\_postgres\_enable\_seqscan) | Whether to enable seqscan. Setting this to true requires a DB restart. Should only be enabled if directed by Braintrust support team. | `bool` | `false` | no |
| <a name="input_postgres_machine_type"></a> [postgres\_machine\_type](#input\_postgres\_machine\_type) | Machine size of Cloud SQL for PostgreSQL instance. | `string` | `"db-perf-optimized-N-8"` | no |
| <a name="input_postgres_maintenance_window"></a> [postgres\_maintenance\_window](#input\_postgres\_maintenance\_window) | Optional maintenance window settings for the Cloud SQL for PostgreSQL instance. | <pre>object({<br/>    day          = number<br/>    hour         = number<br/>    update_track = string<br/>  })</pre> | <pre>{<br/>  "day": 1,<br/>  "hour": 8,<br/>  "update_track": "stable"<br/>}</pre> | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL version to use. | `string` | `"POSTGRES_17"` | no |
| <a name="input_redis_memory_size_gb"></a> [redis\_memory\_size\_gb](#input\_redis\_memory\_size\_gb) | The size of the Redis instance in GiB. | `number` | `3` | no |
| <a name="input_redis_version"></a> [redis\_version](#input\_redis\_version) | The version of Redis software. | `string` | `"REDIS_7_2"` | no |
| <a name="input_subnet_cidr_range"></a> [subnet\_cidr\_range](#input\_subnet\_cidr\_range) | CIDR range for the subnet to deploy resources to (when create\_vpc is true). | `string` | `"10.0.0.0/24"` | no |
| <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name) | Name of the VPC to deploy resources to (when create\_vpc is true). | `string` | `"braintrust"` | no |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_brainstore_bucket_name"></a> [brainstore\_bucket\_name](#output\_brainstore\_bucket\_name) | n/a |
| <a name="output_brainstore_service_account"></a> [brainstore\_service\_account](#output\_brainstore\_service\_account) | n/a |
| <a name="output_braintrust_api_bucket_name"></a> [braintrust\_api\_bucket\_name](#output\_braintrust\_api\_bucket\_name) | n/a |
| <a name="output_braintrust_hmac_access_id"></a> [braintrust\_hmac\_access\_id](#output\_braintrust\_hmac\_access\_id) | n/a |
| <a name="output_braintrust_hmac_secret"></a> [braintrust\_hmac\_secret](#output\_braintrust\_hmac\_secret) | n/a |
| <a name="output_braintrust_service_account"></a> [braintrust\_service\_account](#output\_braintrust\_service\_account) | ---------------------------------------------------------------------------------------------- Service account ---------------------------------------------------------------------------------------------- |
| <a name="output_postgres_instance_ip"></a> [postgres\_instance\_ip](#output\_postgres\_instance\_ip) | n/a |
| <a name="output_postgres_instance_name"></a> [postgres\_instance\_name](#output\_postgres\_instance\_name) | n/a |
| <a name="output_postgres_password"></a> [postgres\_password](#output\_postgres\_password) | n/a |
| <a name="output_postgres_username"></a> [postgres\_username](#output\_postgres\_username) | n/a |
| <a name="output_redis_auth_string"></a> [redis\_auth\_string](#output\_redis\_auth\_string) | n/a |
| <a name="output_redis_instance_host"></a> [redis\_instance\_host](#output\_redis\_instance\_host) | n/a |
| <a name="output_redis_instance_port"></a> [redis\_instance\_port](#output\_redis\_instance\_port) | n/a |
| <a name="output_redis_server_ca_certs"></a> [redis\_server\_ca\_certs](#output\_redis\_server\_ca\_certs) | n/a |

<!-- END_TF_DOCS -->