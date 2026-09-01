#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([a-z0-9_-]{0,61}[a-z0-9])?$", var.deployment_name))
    error_message = "Deployment name must start with a lowercase letter, be 1-63 characters long, and contain only lowercase letters, numbers, underscores, and hyphens. It cannot end with an underscore or hyphen."
  }

  validation {
    condition     = length(var.deployment_name) >= 1 && length(var.deployment_name) <= 63
    error_message = "Deployment name must be between 1 and 63 characters long."
  }

  validation {
    condition     = var.deployment_name != ""
    error_message = "Deployment name cannot be empty."
  }
}

variable "custom_labels" {
  type        = map(string)
  description = "Optional labels to apply to all resources that support labels."
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.custom_labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "Label keys must start with a lowercase letter and contain only lowercase letters, numbers, underscores, and dashes (max 63 chars). Values must contain only lowercase letters, numbers, underscores, and dashes (max 63 chars)."
  }

  validation {
    condition     = length(var.custom_labels) <= 63
    error_message = "A maximum of 63 custom labels are allowed."
  }
}

#----------------------------------------------------------------------------------------------
# VPC
#----------------------------------------------------------------------------------------------
variable "create_vpc" {
  description = "Whether to create a new VPC or use an existing one."
  type        = bool
  default     = true
}

variable "vpc_name" {
  description = "Name of the VPC to deploy resources to (when create_vpc is true)."
  type        = string
  default     = "braintrust"
}

variable "subnet_cidr_range" {
  description = "CIDR range for the subnet to deploy resources to (when create_vpc is true)."
  type        = string
  default     = "10.0.0.0/24"
}

variable "subnet_flow_logs_config" {
  description = "Optional VPC flow logs configuration for the created subnet (when create_vpc is true). Set to null to disable subnet flow logs."
  type = object({
    aggregation_interval = optional(string)
    flow_sampling        = optional(number)
    metadata             = optional(string)
    metadata_fields      = optional(list(string))
    filter_expr          = optional(string)
  })
  default = null

  validation {
    condition     = var.subnet_flow_logs_config == null || var.create_vpc
    error_message = "`subnet_flow_logs_config` can only be set when `create_vpc` is true because this module only manages subnet flow logs for subnets it creates."
  }

  validation {
    condition = var.subnet_flow_logs_config == null ? true : (
      var.subnet_flow_logs_config.aggregation_interval == null ? true : contains([
        "INTERVAL_5_SEC",
        "INTERVAL_30_SEC",
        "INTERVAL_1_MIN",
        "INTERVAL_5_MIN",
        "INTERVAL_10_MIN",
        "INTERVAL_15_MIN",
      ], var.subnet_flow_logs_config.aggregation_interval)
    )
    error_message = "`subnet_flow_logs_config.aggregation_interval` must be one of INTERVAL_5_SEC, INTERVAL_30_SEC, INTERVAL_1_MIN, INTERVAL_5_MIN, INTERVAL_10_MIN, or INTERVAL_15_MIN."
  }

  validation {
    condition = var.subnet_flow_logs_config == null ? true : (
      var.subnet_flow_logs_config.flow_sampling == null ? true : (
        var.subnet_flow_logs_config.flow_sampling >= 0 &&
        var.subnet_flow_logs_config.flow_sampling <= 1
      )
    )
    error_message = "`subnet_flow_logs_config.flow_sampling` must be between 0 and 1 inclusive."
  }

  validation {
    condition = var.subnet_flow_logs_config == null ? true : (
      var.subnet_flow_logs_config.metadata == null ? true : contains([
        "EXCLUDE_ALL_METADATA",
        "INCLUDE_ALL_METADATA",
        "CUSTOM_METADATA",
      ], var.subnet_flow_logs_config.metadata)
    )
    error_message = "`subnet_flow_logs_config.metadata` must be one of EXCLUDE_ALL_METADATA, INCLUDE_ALL_METADATA, or CUSTOM_METADATA."
  }

  validation {
    condition = var.subnet_flow_logs_config == null ? true : (
      var.subnet_flow_logs_config.metadata_fields == null ? true : var.subnet_flow_logs_config.metadata == "CUSTOM_METADATA"
    )
    error_message = "`subnet_flow_logs_config.metadata_fields` can only be set when `subnet_flow_logs_config.metadata` is `CUSTOM_METADATA`."
  }

  validation {
    condition = var.subnet_flow_logs_config == null ? true : (
      var.subnet_flow_logs_config.metadata != "CUSTOM_METADATA" ? true : (
        var.subnet_flow_logs_config.metadata_fields == null ? false : length(var.subnet_flow_logs_config.metadata_fields) > 0
      )
    )
    error_message = "`subnet_flow_logs_config.metadata_fields` must contain at least one field when `subnet_flow_logs_config.metadata` is `CUSTOM_METADATA`."
  }

  validation {
    condition = var.subnet_flow_logs_config == null ? true : (
      var.subnet_flow_logs_config.filter_expr == null ? true : trimspace(var.subnet_flow_logs_config.filter_expr) != ""
    )
    error_message = "`subnet_flow_logs_config.filter_expr` must be a non-empty string when provided."
  }
}

variable "private_service_access_prefix_length" {
  description = "Prefix length for the Private Service Access range used by Cloud SQL and Memorystore (when create_vpc is true). Valid values are 8 through 24: lower prefix lengths create larger ranges, while higher prefix lengths create smaller ranges. Smaller ranges are supported, but choose the size based on networking requirements after discussing with your Braintrust architecture team because they reduce future expansion headroom. Choose this carefully before first deployment; changing Private Service Access ranges later can require rebuilding dependent resources."
  type        = number
  default     = 16

  validation {
    condition     = var.private_service_access_prefix_length >= 8 && var.private_service_access_prefix_length <= 24
    error_message = "`private_service_access_prefix_length` must be between 8 and 24 inclusive."
  }
}

variable "private_service_access_address" {
  description = "Optional starting address for the Private Service Access range used by Cloud SQL and Memorystore (when create_vpc is true). If null, Google selects an available range. Set this when you need to avoid overlap with existing VPCs, peering, or corporate networks."
  type        = string
  default     = null
}

variable "existing_network_self_link" {
  description = "Self link of an existing VPC network (required when create_vpc is false)."
  type        = string
  default     = null

  validation {
    condition     = var.create_vpc || var.existing_network_self_link != null
    error_message = "existing_network_self_link must be provided when create_vpc is false."
  }
}

variable "existing_subnet_self_link" {
  description = "Self link of an existing subnet (required when create_vpc is false)."
  type        = string
  default     = null

  validation {
    condition     = var.create_vpc || var.existing_subnet_self_link != null
    error_message = "existing_subnet_self_link must be provided when create_vpc is false."
  }
}

#----------------------------------------------------------------------------------------------
# Database
#----------------------------------------------------------------------------------------------
variable "postgres_version" {
  type        = string
  description = "PostgreSQL version to use."
  default     = "POSTGRES_17"
}

variable "postgres_machine_type" {
  type        = string
  description = "Machine size of Cloud SQL for PostgreSQL instance."
  default     = "db-perf-optimized-N-8"
}

variable "postgres_availability_type" {
  type        = string
  description = "Availability type of Cloud SQL for PostgreSQL instance."
  default     = "REGIONAL"
}

variable "postgres_disk_size" {
  type        = number
  description = "Size in GB of PostgreSQL disk."
  default     = 1000
}

variable "postgres_enable_seqscan" {
  type        = bool
  description = "Whether to enable seqscan. Setting this to true requires a DB restart. Should only be enabled if directed by Braintrust support team."
  default     = false
}

variable "postgres_backup_start_time" {
  type        = string
  description = "HH:MM time format indicating when daily automatic backups of Cloud SQL for PostgreSQL should run. Defaults to 12 AM (midnight) UTC."
  default     = "00:30"
}

variable "postgres_maintenance_window" {
  type = object({
    day          = number
    hour         = number
    update_track = string
  })
  description = "Optional maintenance window settings for the Cloud SQL for PostgreSQL instance."
  default = {
    day          = 1 # default to Monday
    hour         = 8 # default to 12 AM
    update_track = "stable"
  }

  validation {
    condition     = var.postgres_maintenance_window.day >= 0 && var.postgres_maintenance_window.day <= 7
    error_message = "`day` must be an integer between 0 and 7 (inclusive)."
  }

  validation {
    condition     = var.postgres_maintenance_window.hour >= 0 && var.postgres_maintenance_window.hour <= 23
    error_message = "`hour` must be an integer between 0 and 23 (inclusive)."
  }

  validation {
    condition     = contains(["stable", "canary", "week5"], var.postgres_maintenance_window.update_track)
    error_message = "`update_track` must be either 'canary', 'stable', or 'week5'."
  }
}

variable "postgres_deletion_protection" {
  description = "Whether to protect the Cloud SQL for PostgreSQL instance from deletion."
  type        = bool
  default     = true
}

#----------------------------------------------------------------------------------------------
# Redis
#----------------------------------------------------------------------------------------------
variable "redis_version" {
  type        = string
  description = "The version of Redis software."
  default     = "REDIS_7_2"
}

variable "redis_memory_size_gb" {
  type        = number
  description = "The size of the Redis instance in GiB."
  default     = 3
}

#----------------------------------------------------------------------------------------------
# Storage
#----------------------------------------------------------------------------------------------
variable "gcs_additional_allowed_origins" {
  type        = list(string)
  description = "Additional allowed origins for the Braintrust GCS buckets."
  default     = []
}

variable "gcs_brainstore_logging_config" {
  description = "Optional access logging configuration for the Brainstore GCS bucket."
  type = object({
    log_bucket        = string
    log_object_prefix = optional(string)
  })
  default = null

  validation {
    condition     = var.gcs_brainstore_logging_config == null ? true : trimspace(var.gcs_brainstore_logging_config.log_bucket) != ""
    error_message = "`gcs_brainstore_logging_config.log_bucket` must be a non-empty bucket name."
  }
}

variable "gcs_api_logging_config" {
  description = "Optional access logging configuration for the API GCS bucket."
  type = object({
    log_bucket        = string
    log_object_prefix = optional(string)
  })
  default = null

  validation {
    condition     = var.gcs_api_logging_config == null ? true : trimspace(var.gcs_api_logging_config.log_bucket) != ""
    error_message = "`gcs_api_logging_config.log_bucket` must be a non-empty bucket name."
  }
}

variable "gcs_bucket_retention_days" {
  type        = number
  description = "Number of days to retain objects in the Brainstore GCS buckets."
  default     = 7
}

variable "gcs_versioning_enabled" {
  type        = bool
  description = "Boolean to enable versioning on Braintrust GCS buckets."
  default     = true
}

variable "gcs_uniform_bucket_level_access" {
  type        = bool
  description = "Boolean to enable uniform bucket level access on Braintrust GCS buckets."
  default     = true
}

variable "gcs_storage_class" {
  type        = string
  description = "Storage class of Braintrust GCS buckets."
  default     = "STANDARD"
}

variable "gcs_force_destroy" {
  description = "Whether to force destroy the GCS buckets."
  type        = bool
  default     = false
}

variable "gcs_soft_delete_retention_days" {
  type        = number
  description = "Number of days to retain soft-deleted objects in Braintrust GCS buckets. During this period, deleted objects can be recovered. Set to 0 to disable soft delete policy. This value must be be 0 or between 7 and 90 days."
  default     = 7

  validation {
    condition     = var.gcs_soft_delete_retention_days == 0 || (var.gcs_soft_delete_retention_days >= 7 && var.gcs_soft_delete_retention_days <= 90)
    error_message = "`gcs_soft_delete_retention_days` must be 0 or between 7 and 90 days."
  }
}

variable "custom_gcs_brainstore_lifecycle_rules" {
  description = "Additional lifecycle rules for the brainstore GCS bucket. Allows defining custom object expiration policies for specific prefixes."
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                        = optional(number)
      days_since_noncurrent_time = optional(number)
      matches_prefix             = optional(list(string))
      matches_suffix             = optional(list(string))
      with_state                 = optional(string)
    })
  }))
  default = []
}

variable "custom_gcs_api_lifecycle_rules" {
  description = "Additional lifecycle rules for the API GCS bucket. Allows defining custom object expiration policies for specific prefixes."
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                        = optional(number)
      days_since_noncurrent_time = optional(number)
      matches_prefix             = optional(list(string))
      matches_suffix             = optional(list(string))
      with_state                 = optional(string)
    })
  }))
  default = []
}

#----------------------------------------------------------------------------------------------
# GKE Cluster (optional)
#----------------------------------------------------------------------------------------------
variable "deploy_gke_cluster" {
  description = "Whether to deploy the GKE cluster."
  type        = bool
  default     = true
}

variable "gke_cluster_mode" {
  type        = string
  description = "GKE cluster mode. This value is immutable after cluster creation. A change replaces the cluster and requires Helm release redeployment."
  default     = "autopilot"

  validation {
    condition     = contains(["autopilot", "standard"], var.gke_cluster_mode)
    error_message = "`gke_cluster_mode` must be `autopilot` or `standard`."
  }
}

variable "gke_standard_node_pools" {
  type = map(object({
    machine_type         = string
    total_min_node_count = number
    total_max_node_count = number
    image_type           = optional(string, "COS_CONTAINERD")
    disk_type            = optional(string, "hyperdisk-balanced")
    disk_size_gb         = optional(number, 100)
    spot                 = optional(bool, false)
    location_policy      = optional(string, "BALANCED")
    node_locations       = optional(list(string))
    labels               = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    ephemeral_storage_local_ssd_count = optional(number)
    auto_repair                       = optional(bool, true)
    auto_upgrade                      = optional(bool, true)
    max_surge                         = optional(number, 1)
    max_unavailable                   = optional(number, 0)
    enable_secure_boot                = optional(bool, true)
    enable_integrity_monitoring       = optional(bool, true)
  }))
  description = "Node pools for a Standard GKE cluster. This value has no effect in Autopilot mode."
  default = {
    api = {
      machine_type         = "c4-standard-16"
      total_min_node_count = 2
      total_max_node_count = 10
    }
    brainstore = {
      machine_type         = "c4-standard-48-lssd"
      total_min_node_count = 5
      total_max_node_count = 10
    }
  }

  validation {
    condition = alltrue([
      for name, pool in var.gke_standard_node_pools :
      can(regex("^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$", name)) &&
      pool.total_min_node_count >= 0 &&
      pool.total_max_node_count >= pool.total_min_node_count &&
      pool.disk_size_gb >= 10 &&
      contains(["BALANCED", "ANY"], pool.location_policy) &&
      (pool.node_locations == null ? true : length(pool.node_locations) > 0 && alltrue([for location in pool.node_locations : trimspace(location) != ""])) &&
      (pool.ephemeral_storage_local_ssd_count == null ? true : pool.ephemeral_storage_local_ssd_count >= 1) &&
      alltrue([
        for taint in pool.taints : contains(["NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE"], taint.effect)
      ])
    ])
    error_message = "Each Standard node pool must use valid names, sizes, autoscaler limits, Local SSD counts, policies, and taints."
  }

  validation {
    condition     = var.gke_cluster_mode != "standard" || length(var.gke_standard_node_pools) > 0
    error_message = "`gke_standard_node_pools` must contain at least one pool in Standard mode."
  }
}

variable "gke_cluster_is_private" {
  description = "Whether to deploy the GKE cluster in a private network."
  type        = bool
  default     = false
}

variable "gke_control_plane_cidr" {
  type        = string
  description = "The CIDR block for the GKE control plane."
  default     = "10.0.1.0/28"
}

variable "gke_pods_ipv4_cidr_block" {
  type        = string
  description = "Optional CIDR block or netmask size for GKE Pod IPs. For example, '10.20.0.0/20' or '/20'. Cannot be set with gke_pods_secondary_range_name. Choose this carefully before first deployment; changing GKE secondary ranges later is disruptive."
  default     = null

  validation {
    condition     = var.gke_pods_ipv4_cidr_block == null || var.gke_pods_secondary_range_name == null
    error_message = "`gke_pods_ipv4_cidr_block` cannot be set when `gke_pods_secondary_range_name` is set."
  }
}

variable "gke_pods_secondary_range_name" {
  type        = string
  description = "Optional name of a secondary range that already exists on the selected subnet for GKE Pod IPs. This variable does not create the range. Cannot be set with gke_pods_ipv4_cidr_block."
  default     = null
}

variable "gke_services_ipv4_cidr_block" {
  type        = string
  description = "Optional CIDR block or netmask size for GKE Service IPs. Most deployments should leave this unset unless they intentionally need a custom Service CIDR. For example, '10.30.0.0/22' or '/22'. Cannot be set with gke_services_secondary_range_name. Choose this carefully before first deployment; changing GKE secondary ranges later is disruptive."
  default     = null

  validation {
    condition     = var.gke_services_ipv4_cidr_block == null || var.gke_services_secondary_range_name == null
    error_message = "`gke_services_ipv4_cidr_block` cannot be set when `gke_services_secondary_range_name` is set."
  }
}

variable "gke_services_secondary_range_name" {
  type        = string
  description = "Optional name of a secondary range that already exists on the selected subnet for GKE Service IPs. This variable does not create the range. Most deployments should leave this unset unless they intentionally need a custom Service CIDR. Cannot be set with gke_services_ipv4_cidr_block."
  default     = null
}

variable "gke_control_plane_authorized_cidrs" {
  description = "List of CIDR blocks authorized to access the GKE control plane. If not provided, allows all IPs (for public clusters)."
  type        = list(string)
  default     = null
}

variable "gke_enable_master_global_access" {
  description = "Whether to enable global access to the GKE control plane from any region."
  type        = bool
  default     = false
}

variable "gke_release_channel" {
  type        = string
  description = "The release channel of the GKE cluster."
  default     = "REGULAR"
}

variable "gke_enable_private_endpoint" {
  type        = bool
  description = "Whether to enable private endpoint for the GKE cluster."
  default     = true
}

variable "gke_deletion_protection" {
  description = "Whether to protect the GKE cluster from deletion."
  type        = bool
  default     = true
}

variable "gke_maintenance_window" {
  type = object({
    day        = number
    start_time = string
  })
  description = "Optional maintenance window settings for the GKE cluster."
  default = {
    day        = 1       # default to Monday (1-7, Monday=1)
    start_time = "08:00" # default to 8:00 AM UTC
  }

  validation {
    condition     = var.gke_maintenance_window.day >= 1 && var.gke_maintenance_window.day <= 7
    error_message = "`day` must be an integer between 1 and 7 (inclusive), where Monday=1."
  }

  validation {
    condition     = can(regex("^([01]?[0-9]|2[0-3]):[0-5][0-9]$", var.gke_maintenance_window.start_time))
    error_message = "`start_time` must be in HH:MM format (24-hour), e.g., '08:00'."
  }
}

#----------------------------------------------------------------------------------------------
# GKE IAM
#----------------------------------------------------------------------------------------------
variable "braintrust_kube_namespace" {
  type        = string
  description = "The namespace name that Braintrust will be deployed into, in the GKE cluster."
  default     = "braintrust"
}

variable "braintrust_kube_svc_account" {
  type        = string
  description = "The service account name for Braintrust API."
  default     = "braintrust-api"
}

variable "brainstore_kube_svc_account" {
  type        = string
  description = "The service account name for Brainstore."
  default     = "brainstore"
}

# With data plane 2.0.0 and later native auth can be used instead of HMAC keys.
variable "braintrust_hmac_key_enabled" {
  type        = bool
  description = "Whether to enable HMAC keys for Braintrust API."
  default     = true
}

variable "brainstore_impersonation_targets" {
  type        = list(string)
  description = "Full resource names of service accounts (same or other projects) that the brainstore service account can impersonate via roles/iam.serviceAccountTokenCreator. Format: projects/{project_id}/serviceAccounts/{email}. Only required if you are not granting IAM access to the brainstore service account yourself. Note: the principal running this Terraform deployment must have permission to manage IAM policies on the target service accounts (e.g. roles/iam.serviceAccountAdmin or roles/resourcemanager.projectIamAdmin)."
  default     = []
}
