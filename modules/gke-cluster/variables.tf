#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

#----------------------------------------------------------------------------------------------
# GKE Cluster
#----------------------------------------------------------------------------------------------
variable "gke_network" {
  type        = string
  description = "The network of the GKE cluster."
}

variable "gke_subnetwork" {
  type        = string
  description = "The subnetwork of the GKE cluster."
}

variable "gke_release_channel" {
  type        = string
  description = "The release channel of the GKE cluster."
  default     = "REGULAR"
}

variable "gke_deletion_protection" {
  type        = bool
  description = "Whether to protect the GKE cluster from deletion."
  default     = true
}

variable "gke_cluster_is_private" {
  type        = bool
  description = "Whether to create a private GKE cluster."
  default     = false
}

variable "gke_enable_private_endpoint" {
  type        = bool
  description = "Whether to enable private endpoint for the GKE cluster."
  default     = true
}

variable "gke_control_plane_cidr" {
  type        = string
  description = "The CIDR block for the GKE control plane."
  default     = "10.0.1.0/28"
}

variable "gke_control_plane_authorized_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks authorized to access the GKE control plane. If not provided, allows all IPs (for public clusters)."
  default     = null
}

variable "gke_enable_master_global_access" {
  type        = bool
  description = "Whether to enable global access to the GKE control plane from any region."
  default     = false
}

variable "gke_l4_ilb_subsetting_enabled" {
  type        = bool
  description = "Whether to enable L4 ILB subsetting for the GKE cluster."
  default     = true
}

variable "gke_http_load_balancing_disabled" {
  type        = bool
  description = "Whether to disable HTTP load balancing for the GKE cluster."
  default     = false
}

variable "gke_kms_cmek_id" {
  type        = string
  description = "ID of Cloud KMS customer managed encryption key (CMEK) to use for GKE cluster encryption."
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
