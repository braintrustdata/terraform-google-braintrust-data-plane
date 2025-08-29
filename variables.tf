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

#----------------------------------------------------------------------------------------------
# GKE Cluster (optional)
#----------------------------------------------------------------------------------------------
variable "deploy_gke_cluster" {
  description = "Whether to deploy the GKE cluster."
  type        = bool
  default     = true
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

variable "gke_node_type" {
  description = "The type of node to use for the GKE cluster."
  type        = string
  default     = "c4-standard-16-lssd"
}

#This is required due to https://github.com/hashicorp/terraform-provider-google/issues/17068
variable "gke_local_ssd_count" {
  description = "The number of local SSDs to attach to each GKE node. This value will change depending on the node type."
  type        = number
  default     = 2
}

variable "gke_release_channel" {
  type        = string
  description = "The release channel of the GKE cluster."
  default     = "REGULAR"
}

variable "gke_initial_node_count" {
  type        = number
  description = "The initial number of nodes in the GKE cluster."
  default     = 1
}

variable "gke_enable_private_endpoint" {
  type        = bool
  description = "Whether to enable private endpoint for the GKE cluster."
  default     = true
}

variable "gke_node_count" {
  type        = number
  description = "The number of nodes in the GKE node pool."
  default     = 1
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

# API container doesn't support GCS native storage integration yet, so we use HMAC keys instead. 
variable "braintrust_hmac_key_enabled" {
  type        = bool
  description = "Whether to enable HMAC keys for Braintrust API."
  default     = true
}