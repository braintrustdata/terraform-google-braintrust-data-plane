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
| [google_container_cluster.braintrust_autopilot](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_kms_crypto_key_iam_member.gke_cluster_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_kms_crypto_key_iam_member.gke_compute_cmek](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_member) | resource |
| [google_project_iam_member.gke_artifact_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_default_node_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_log_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_metric_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_object_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.gke_stackdriver_writer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.gke](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_client_config.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_project.current](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name) | Name of the deployment. Used to prefix resource names. | `string` | n/a | yes |
| <a name="input_gke_cluster_is_private"></a> [gke\_cluster\_is\_private](#input\_gke\_cluster\_is\_private) | Whether to create a private GKE cluster. | `bool` | `false` | no |
| <a name="input_gke_control_plane_authorized_cidrs"></a> [gke\_control\_plane\_authorized\_cidrs](#input\_gke\_control\_plane\_authorized\_cidrs) | List of CIDR blocks authorized to access the GKE control plane. If not provided, allows all IPs (for public clusters). | `list(string)` | `null` | no |
| <a name="input_gke_control_plane_cidr"></a> [gke\_control\_plane\_cidr](#input\_gke\_control\_plane\_cidr) | The CIDR block for the GKE control plane. | `string` | `"10.0.1.0/28"` | no |
| <a name="input_gke_deletion_protection"></a> [gke\_deletion\_protection](#input\_gke\_deletion\_protection) | Whether to protect the GKE cluster from deletion. | `bool` | `true` | no |
| <a name="input_gke_enable_master_global_access"></a> [gke\_enable\_master\_global\_access](#input\_gke\_enable\_master\_global\_access) | Whether to enable global access to the GKE control plane from any region. | `bool` | `false` | no |
| <a name="input_gke_enable_private_endpoint"></a> [gke\_enable\_private\_endpoint](#input\_gke\_enable\_private\_endpoint) | Whether to enable private endpoint for the GKE cluster. | `bool` | `true` | no |
| <a name="input_gke_http_load_balancing_disabled"></a> [gke\_http\_load\_balancing\_disabled](#input\_gke\_http\_load\_balancing\_disabled) | Whether to disable HTTP load balancing for the GKE cluster. | `bool` | `false` | no |
| <a name="input_gke_kms_cmek_id"></a> [gke\_kms\_cmek\_id](#input\_gke\_kms\_cmek\_id) | ID of Cloud KMS customer managed encryption key (CMEK) to use for GKE cluster encryption. | `string` | n/a | yes |
| <a name="input_gke_l4_ilb_subsetting_enabled"></a> [gke\_l4\_ilb\_subsetting\_enabled](#input\_gke\_l4\_ilb\_subsetting\_enabled) | Whether to enable L4 ILB subsetting for the GKE cluster. | `bool` | `true` | no |
| <a name="input_gke_maintenance_window"></a> [gke\_maintenance\_window](#input\_gke\_maintenance\_window) | Optional maintenance window settings for the GKE cluster. | <pre>object({<br/>    day        = number<br/>    start_time = string<br/>  })</pre> | <pre>{<br/>  "day": 1,<br/>  "start_time": "08:00"<br/>}</pre> | no |
| <a name="input_gke_network"></a> [gke\_network](#input\_gke\_network) | The network of the GKE cluster. | `string` | n/a | yes |
| <a name="input_gke_release_channel"></a> [gke\_release\_channel](#input\_gke\_release\_channel) | The release channel of the GKE cluster. | `string` | `"REGULAR"` | no |
| <a name="input_gke_subnetwork"></a> [gke\_subnetwork](#input\_gke\_subnetwork) | The subnetwork of the GKE cluster. | `string` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_gke_autopilot_cluster_endpoint"></a> [gke\_autopilot\_cluster\_endpoint](#output\_gke\_autopilot\_cluster\_endpoint) | Endpoint of the autopilot cluster (null if not enabled) |
| <a name="output_gke_autopilot_cluster_master_version"></a> [gke\_autopilot\_cluster\_master\_version](#output\_gke\_autopilot\_cluster\_master\_version) | Master version of the autopilot cluster (null if not enabled) |
| <a name="output_gke_autopilot_cluster_name"></a> [gke\_autopilot\_cluster\_name](#output\_gke\_autopilot\_cluster\_name) | Name of the autopilot cluster (null if not enabled) |

<!-- END_TF_DOCS -->