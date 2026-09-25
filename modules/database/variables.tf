#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

variable "custom_labels" {
  type        = map(string)
  description = "Optional labels to apply to all resources that support labels."
  default     = {}
}

#----------------------------------------------------------------------------------------------
# Cloud SQL for PostgreSQL
#----------------------------------------------------------------------------------------------
variable "postgres_version" {
  type        = string
  description = "PostgreSQL version to use."
  default     = "POSTGRES_17"
}

variable "postgres_deletion_protection" {
  type        = bool
  description = "Whether to protect the Cloud SQL for PostgreSQL instance from deletion."
  default     = true
}

variable "postgres_availability_type" {
  type        = string
  description = "Availability type of Cloud SQL for PostgreSQL instance."
  default     = "REGIONAL"
}

variable "postgres_machine_type" {
  type        = string
  description = "Enterprise Plus machine type from the N2, C4A, or C4 series. The machine type selects compatible storage settings."
  default     = "db-perf-optimized-N-8"

  validation {
    condition     = can(regex("^db-(perf-optimized-(N|C4)|c4a-highmem)-[0-9]+$", var.postgres_machine_type))
    error_message = "Use an Enterprise Plus machine type from the N2, C4A, or C4 series."
  }

  validation {
    condition     = !contains(["db-c4a-highmem-2", "db-perf-optimized-C4-2"], var.postgres_machine_type)
    error_message = "C4A and C4 machine types require at least four vCPUs."
  }
}

variable "postgres_disk_provisioned_iops" {
  type        = number
  description = "Hyperdisk IOPS. Null uses the Cloud SQL default for the disk size and machine type."
  default     = null

  validation {
    condition     = var.postgres_disk_provisioned_iops == null ? true : var.postgres_disk_provisioned_iops >= 3000 && floor(var.postgres_disk_provisioned_iops) == var.postgres_disk_provisioned_iops
    error_message = "Hyperdisk IOPS must be an integer of at least 3000."
  }

  validation {
    condition     = var.postgres_disk_provisioned_iops == null || can(regex("^db-(c4a-highmem|perf-optimized-C4)-[0-9]+$", var.postgres_machine_type))
    error_message = "Custom IOPS require a C4A or C4 machine type with Hyperdisk Balanced."
  }
}

variable "postgres_disk_provisioned_throughput" {
  type        = number
  description = "Hyperdisk throughput in MiB/s. Null uses the Cloud SQL default for the disk size and machine type."
  default     = null

  validation {
    condition     = var.postgres_disk_provisioned_throughput == null ? true : var.postgres_disk_provisioned_throughput >= 140 && floor(var.postgres_disk_provisioned_throughput) == var.postgres_disk_provisioned_throughput
    error_message = "Hyperdisk throughput must be an integer of at least 140 MiB/s."
  }

  validation {
    condition     = var.postgres_disk_provisioned_throughput == null || can(regex("^db-(c4a-highmem|perf-optimized-C4)-[0-9]+$", var.postgres_machine_type))
    error_message = "Custom throughput requires a C4A or C4 machine type with Hyperdisk Balanced."
  }
}

variable "postgres_disk_size" {
  type        = number
  description = "Initial PostgreSQL disk size in GB. Terraform ignores later changes to this value."
  default     = 1000
  nullable    = false

  validation {
    condition     = var.postgres_disk_size >= 10 && floor(var.postgres_disk_size) == var.postgres_disk_size
    error_message = "The initial disk size must be an integer of at least 10 GB."
  }

  validation {
    condition     = !can(regex("^db-(c4a-highmem|perf-optimized-C4)-[0-9]+$", var.postgres_machine_type)) || var.postgres_disk_size >= 20
    error_message = "Hyperdisk Balanced requires a disk size of at least 20 GB."
  }
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

variable "postgres_ssl_mode" {
  type        = string
  description = "Indicates whether to enforce TLS/SSL connections to the Cloud SQL for PostgreSQL instance."
  default     = "ENCRYPTED_ONLY"
}

variable "postgres_network" {
  type        = string
  description = "Name of the VPC network to connect to the Cloud SQL for PostgreSQL instance."
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

variable "postgres_insights_config" {
  type = object({
    query_insights_enabled  = bool
    query_plans_per_minute  = number
    query_string_length     = number
    record_application_tags = bool
    record_client_address   = bool
  })
  description = "Configuration settings for Cloud SQL for PostgreSQL insights."
  default = {
    query_insights_enabled  = true
    query_plans_per_minute  = 5
    query_string_length     = 1024
    record_application_tags = true
    record_client_address   = true
  }
}

variable "postgres_kms_cmek_id" {
  type        = string
  description = "ID of Cloud KMS customer managed encryption key (CMEK) to use for Cloud SQL for PostgreSQL database instance. If this is not provided, the database will be encrypted with a Google-managed key."
}
