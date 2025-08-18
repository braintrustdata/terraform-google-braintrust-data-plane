<!-- BEGIN_TF_DOCS -->
## Required Inputs

The following input variables are required:

### <a name="input_deployment_name"></a> [deployment\_name](#input\_deployment\_name)

Description: Name of the deployment. Used to prefix resource names.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_brainstore_kube_svc_account"></a> [brainstore\_kube\_svc\_account](#input\_brainstore\_kube\_svc\_account)

Description: The service account of the Brainstore in the GKE cluster.

Type: `string`

Default: `"brainstore"`

### <a name="input_braintrust_kube_namespace"></a> [braintrust\_kube\_namespace](#input\_braintrust\_kube\_namespace)

Description: The namespace of the Braintrust service account in the GKE cluster.

Type: `string`

Default: `"braintrust"`

### <a name="input_braintrust_kube_svc_account"></a> [braintrust\_kube\_svc\_account](#input\_braintrust\_kube\_svc\_account)

Description: The service account of the Braintrust API in the GKE cluster.

Type: `string`

Default: `"braintrust-api"`

### <a name="input_deploy_gke_cluster"></a> [deploy\_gke\_cluster](#input\_deploy\_gke\_cluster)

Description: Whether to deploy the GKE cluster.

Type: `bool`

Default: `false`

### <a name="input_gcs_additional_allowed_origins"></a> [gcs\_additional\_allowed\_origins](#input\_gcs\_additional\_allowed\_origins)

Description: Additional allowed origins for the Braintrust GCS buckets.

Type: `list(string)`

Default: `[]`

### <a name="input_gcs_bucket_retention_days"></a> [gcs\_bucket\_retention\_days](#input\_gcs\_bucket\_retention\_days)

Description: Number of days to retain objects in the Brainstore GCS buckets.

Type: `number`

Default: `7`

### <a name="input_gcs_force_destroy"></a> [gcs\_force\_destroy](#input\_gcs\_force\_destroy)

Description: Whether to force destroy the GCS buckets.

Type: `bool`

Default: `false`

### <a name="input_gcs_storage_class"></a> [gcs\_storage\_class](#input\_gcs\_storage\_class)

Description: Storage class of Braintrust GCS buckets.

Type: `string`

Default: `"STANDARD"`

### <a name="input_gcs_uniform_bucket_level_access"></a> [gcs\_uniform\_bucket\_level\_access](#input\_gcs\_uniform\_bucket\_level\_access)

Description: Boolean to enable uniform bucket level access on Braintrust GCS buckets.

Type: `bool`

Default: `true`

### <a name="input_gcs_versioning_enabled"></a> [gcs\_versioning\_enabled](#input\_gcs\_versioning\_enabled)

Description: Boolean to enable versioning on Braintrust GCS buckets.

Type: `bool`

Default: `true`

### <a name="input_gke_cluster_is_private"></a> [gke\_cluster\_is\_private](#input\_gke\_cluster\_is\_private)

Description: Whether to deploy the GKE cluster in a private network.

Type: `bool`

Default: `true`

### <a name="input_gke_control_plane_authorized_cidr"></a> [gke\_control\_plane\_authorized\_cidr](#input\_gke\_control\_plane\_authorized\_cidr)

Description: The CIDR block for the GKE control plane authorized networks.

Type: `string`

Default: `null`

### <a name="input_gke_control_plane_cidr"></a> [gke\_control\_plane\_cidr](#input\_gke\_control\_plane\_cidr)

Description: The CIDR block for the GKE control plane.

Type: `string`

Default: `"10.0.1.0/28"`

### <a name="input_gke_deletion_protection"></a> [gke\_deletion\_protection](#input\_gke\_deletion\_protection)

Description: Whether to protect the GKE cluster from deletion.

Type: `bool`

Default: `true`

### <a name="input_gke_enable_private_endpoint"></a> [gke\_enable\_private\_endpoint](#input\_gke\_enable\_private\_endpoint)

Description: Whether to enable private endpoint for the GKE cluster.

Type: `bool`

Default: `true`

### <a name="input_gke_initial_node_count"></a> [gke\_initial\_node\_count](#input\_gke\_initial\_node\_count)

Description: The initial number of nodes in the GKE cluster.

Type: `number`

Default: `1`

### <a name="input_gke_node_count"></a> [gke\_node\_count](#input\_gke\_node\_count)

Description: The number of nodes in the GKE node pool.

Type: `number`

Default: `1`

### <a name="input_gke_node_type"></a> [gke\_node\_type](#input\_gke\_node\_type)

Description: The type of node to use for the GKE cluster.

Type: `string`

Default: `"c4a-standard-16-lssd"`

### <a name="input_gke_release_channel"></a> [gke\_release\_channel](#input\_gke\_release\_channel)

Description: The release channel of the GKE cluster.

Type: `string`

Default: `"REGULAR"`

### <a name="input_postgres_availability_type"></a> [postgres\_availability\_type](#input\_postgres\_availability\_type)

Description: Availability type of Cloud SQL for PostgreSQL instance.

Type: `string`

Default: `"REGIONAL"`

### <a name="input_postgres_backup_start_time"></a> [postgres\_backup\_start\_time](#input\_postgres\_backup\_start\_time)

Description: HH:MM time format indicating when daily automatic backups of Cloud SQL for PostgreSQL should run. Defaults to 12 AM (midnight) UTC.

Type: `string`

Default: `"00:30"`

### <a name="input_postgres_deletion_protection"></a> [postgres\_deletion\_protection](#input\_postgres\_deletion\_protection)

Description: Whether to protect the Cloud SQL for PostgreSQL instance from deletion.

Type: `bool`

Default: `true`

### <a name="input_postgres_disk_size"></a> [postgres\_disk\_size](#input\_postgres\_disk\_size)

Description: Size in GB of PostgreSQL disk.

Type: `number`

Default: `1000`

### <a name="input_postgres_machine_type"></a> [postgres\_machine\_type](#input\_postgres\_machine\_type)

Description: Machine size of Cloud SQL for PostgreSQL instance.

Type: `string`

Default: `"db-perf-optimized-N-8"`

### <a name="input_postgres_maintenance_window"></a> [postgres\_maintenance\_window](#input\_postgres\_maintenance\_window)

Description: Optional maintenance window settings for the Cloud SQL for PostgreSQL instance.

Type:

```hcl
object({
    day          = number
    hour         = number
    update_track = string
  })
```

Default:

```json
{
  "day": 1,
  "hour": 8,
  "update_track": "stable"
}
```

### <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version)

Description: PostgreSQL version to use.

Type: `string`

Default: `"POSTGRES_17"`

### <a name="input_redis_memory_size_gb"></a> [redis\_memory\_size\_gb](#input\_redis\_memory\_size\_gb)

Description: The size of the Redis instance in GiB.

Type: `number`

Default: `3`

### <a name="input_redis_version"></a> [redis\_version](#input\_redis\_version)

Description: The version of Redis software.

Type: `string`

Default: `"REDIS_7_2"`

### <a name="input_subnet_cidr_range"></a> [subnet\_cidr\_range](#input\_subnet\_cidr\_range)

Description: CIDR range for the subnet to deploy resources to.

Type: `string`

Default: `"10.0.0.0/24"`

### <a name="input_vpc_name"></a> [vpc\_name](#input\_vpc\_name)

Description: Name of the VPC to deploy resources to.

Type: `string`

Default: `"braintrust"`

## Outputs

The following outputs are exported:

### <a name="output_brainstore_bucket_name"></a> [brainstore\_bucket\_name](#output\_brainstore\_bucket\_name)

Description: n/a

### <a name="output_brainstore_service_account"></a> [brainstore\_service\_account](#output\_brainstore\_service\_account)

Description: n/a

### <a name="output_braintrust_code_bundle_bucket_name"></a> [braintrust\_code\_bundle\_bucket\_name](#output\_braintrust\_code\_bundle\_bucket\_name)

Description: n/a

### <a name="output_braintrust_response_bucket_name"></a> [braintrust\_response\_bucket\_name](#output\_braintrust\_response\_bucket\_name)

Description: n/a

### <a name="output_braintrust_service_account"></a> [braintrust\_service\_account](#output\_braintrust\_service\_account)

Description: ---------------------------------------------------------------------------------------------- Service account ----------------------------------------------------------------------------------------------

### <a name="output_postgres_instance_ip"></a> [postgres\_instance\_ip](#output\_postgres\_instance\_ip)

Description: n/a

### <a name="output_postgres_instance_name"></a> [postgres\_instance\_name](#output\_postgres\_instance\_name)

Description: n/a

### <a name="output_postgres_password"></a> [postgres\_password](#output\_postgres\_password)

Description: n/a

### <a name="output_postgres_username"></a> [postgres\_username](#output\_postgres\_username)

Description: n/a

### <a name="output_redis_instance_host"></a> [redis\_instance\_host](#output\_redis\_instance\_host)

Description: n/a

### <a name="output_redis_instance_port"></a> [redis\_instance\_port](#output\_redis\_instance\_port)

Description: n/a

### <a name="output_redis_server_ca_certs"></a> [redis\_server\_ca\_certs](#output\_redis\_server\_ca\_certs)

Description: n/a
<!-- END_TF_DOCS -->