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

variable "org_name" {
  description = "Name of the braintrust organization."
  type        = string
  default     = "*"
}

variable "region" {
  description = "Region to deploy resources to."
  type        = string
  default     = "us-central1"
}

variable "deployment_type" {
  description = "Type of deployment either using gke or cloud run."
  type        = string
  default     = "cloud-run"
  validation {
    condition     = contains(["gke", "cloud-run"], var.deployment_type)
    error_message = "Deployment type must be either 'cloud-run' or 'gke'."
  }
}

variable "vpc_name" {
  description = "Name of the VPC to deploy resources to."
  type        = string
  default     = "braintrust"
}

variable "subnet_cidr_range" {
  description = "CIDR range for the subnet to deploy resources to."
  type        = string
  default     = "10.0.0.0/24"
}

variable "vpc_access_connector_ip_cidr_range" {
  description = "IP CIDR range for the VPC access connector."
  type        = string
  default     = "10.8.0.0/28"
}

variable "postgres_deletion_protection" {
  description = "Whether to protect the Cloud SQL for PostgreSQL instance from deletion."
  type        = bool
  default     = true
}

variable "gcs_force_destroy" {
  description = "Whether to force destroy the GCS buckets."
  type        = bool
  default     = false
}

variable "brainstore_license_key_secret_name" {
  description = "Secret name for Brainstore license key."
  type        = string
  default     = null
}

variable "enable_brainstore_vm" {
  description = "Whether to enable the Brainstore VM."
  type        = bool
  default     = false
}

variable "deploy_gke_cluster" {
  description = "Whether to deploy the GKE cluster."
  type        = bool
  default     = true
}

variable "gke_deletion_protection" {
  description = "Whether to protect the GKE cluster from deletion."
  type        = bool
  default     = true
}

variable "gke_control_plane_authorized_cidr" {
  description = "The CIDR block for the GKE control plane authorized networks."
  type        = string
  default     = null
}

variable "cloud_run_enable_public_access" {
  description = "Whether to enable public access to the Cloud Run API."
  type        = bool
  default     = true
}

variable "cloud_run_deletion_protection" {
  description = "Whether to protect the Cloud Run service from deletion."
  type        = bool
  default     = true
}
