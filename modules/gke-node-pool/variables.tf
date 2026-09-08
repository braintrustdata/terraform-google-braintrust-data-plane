variable "deployment_name" {
  type        = string
  description = "Deployment name for resource labels."
}

variable "custom_labels" {
  type        = map(string)
  description = "Labels for resources that support GCP resource labels."
  default     = {}
}

variable "name" {
  type        = string
  description = "GKE node pool name."

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,38}[a-z0-9])?$", var.name))
    error_message = "`name` must contain 1 through 40 lowercase letters, numbers, or hyphens."
  }
}

variable "project_id" {
  type        = string
  description = "GCP project ID for the GKE node pool."
}

variable "location" {
  type        = string
  description = "GKE cluster location."
}

variable "cluster_id" {
  type        = string
  description = "GKE cluster resource ID."
}

variable "service_account_email" {
  type        = string
  description = "Email address of the node service account."
}

variable "boot_disk_kms_key" {
  type        = string
  description = "Cloud KMS key ID for node boot disks."
}

variable "machine_type" {
  type        = string
  description = "Compute Engine machine type for each node. GKE configures the fixed Local SSD count for `-lssd` machine types."
}

variable "image_type" {
  type        = string
  description = "GKE node image type."
  default     = "COS_CONTAINERD"
}

variable "disk_type" {
  type        = string
  description = "Boot disk type for each node."
  default     = "hyperdisk-balanced"
}

variable "disk_size_gb" {
  type        = number
  description = "Boot disk size in GiB for each node."
  default     = 100

  validation {
    condition     = var.disk_size_gb >= 10
    error_message = "`disk_size_gb` must be at least 10."
  }
}

variable "spot" {
  type        = bool
  description = "Whether the node pool uses Spot VMs."
  default     = false
}

variable "total_min_node_count" {
  type        = number
  description = "Minimum total node count across all zones."

  validation {
    condition     = var.total_min_node_count >= 0
    error_message = "`total_min_node_count` must be zero or greater."
  }
}

variable "total_max_node_count" {
  type        = number
  description = "Maximum total node count across all zones."

  validation {
    condition     = var.total_max_node_count >= var.total_min_node_count
    error_message = "`total_max_node_count` must equal or exceed `total_min_node_count`."
  }
}

variable "location_policy" {
  type        = string
  description = "Autoscaler location policy. Valid values are `BALANCED` and `ANY`."
  default     = "BALANCED"

  validation {
    condition     = contains(["BALANCED", "ANY"], var.location_policy)
    error_message = "`location_policy` must be `BALANCED` or `ANY`."
  }
}

variable "node_locations" {
  type        = list(string)
  description = "Optional zones for the node pool. GKE uses the cluster node locations when this value is null."
  default     = null

  validation {
    condition     = var.node_locations == null ? true : length(var.node_locations) > 0 && alltrue([for location in var.node_locations : trimspace(location) != ""])
    error_message = "`node_locations` must be null or a list of non-empty zone names."
  }
}

variable "labels" {
  type        = map(string)
  description = "Kubernetes labels for each node."
  default     = {}
}

variable "taints" {
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  description = "Kubernetes taints for each node."
  default     = []

  validation {
    condition = alltrue([
      for taint in var.taints : contains(["NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE"], taint.effect)
    ])
    error_message = "Each taint effect must be `NO_SCHEDULE`, `PREFER_NO_SCHEDULE`, or `NO_EXECUTE`."
  }
}

variable "auto_repair" {
  type        = bool
  description = "Whether GKE repairs unhealthy nodes."
  default     = true
}

variable "max_surge" {
  type        = number
  description = "Maximum additional nodes during an upgrade."
  default     = 1
}

variable "max_unavailable" {
  type        = number
  description = "Maximum unavailable nodes during an upgrade."
  default     = 0
}

variable "enable_secure_boot" {
  type        = bool
  description = "Whether Shielded GKE Nodes use Secure Boot."
  default     = true
}

variable "enable_integrity_monitoring" {
  type        = bool
  description = "Whether Shielded GKE Nodes use integrity monitoring."
  default     = true
}
