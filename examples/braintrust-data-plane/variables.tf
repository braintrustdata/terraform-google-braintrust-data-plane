variable "project_id" {
  type        = string
  description = "The ID of the project to deploy resources to."
}

variable "region" {
  type        = string
  description = "The region to deploy resources to."
}

variable "brainstore_license_key_secret_name" {
  type        = string
  description = "The name of the secret to store the Brainstore license key."
  default     = null
}