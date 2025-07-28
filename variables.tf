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

variable "region" {
  description = "Region to deploy resources to."
  type        = string
  default     = "us-central1"
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
}

variable "enable_brainstore_vm" {
  description = "Whether to enable the Brainstore VM."
  type        = bool
  default     = false
}