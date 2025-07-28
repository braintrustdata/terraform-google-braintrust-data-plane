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
  default     = null
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