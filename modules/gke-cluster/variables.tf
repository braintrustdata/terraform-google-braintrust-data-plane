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

variable "gke_remove_default_node_pool" {
  type        = bool
  description = "Whether to remove the default node pool when creating a new node pool in an existing cluster."
  default     = true
}

variable "gke_deletion_protection" {
  type        = bool
  description = "Whether to protect the GKE cluster from deletion."
  default     = true
}

variable "gke_initial_node_count" {
  type        = number
  description = "The initial number of nodes in the GKE cluster."
  default     = 1
}

variable "gke_cluster_is_private" {
  type        = bool
  description = "Whether to create a private GKE cluster."
  default     = true
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

variable "gke_control_plane_authorized_cidr" {
  type        = string
  description = "The CIDR block for the GKE control plane authorized networks."
  default     = null
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

variable "gke_node_count" {
  type        = number
  description = "The number of nodes in the GKE node pool."
  default     = 1
}

variable "gke_node_type" {
  type        = string
  description = "The type of node in the GKE node pool."
  default     = "c4a-standard-4" 
}
