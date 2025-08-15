variable "project_id" {
  type        = string
  description = "The ID of the project to deploy resources to."
}

variable "region" {
  type        = string
  description = "The region to deploy resources to."
}

variable "deployment_name" {
  type        = string
  description = "The name of the deployment."
}

variable "brainstore_license_key_secret_name" {
  type        = string
  description = "The name of the secret to store the Brainstore license key."
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

variable "cloud_run_deletion_protection" {
  description = "Whether to protect the Cloud Run service from deletion."
  type        = bool
  default     = true
}