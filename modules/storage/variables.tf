#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

#----------------------------------------------------------------------------------------------
# GCS
#----------------------------------------------------------------------------------------------
variable "gcs_storage_class" {
  type        = string
  description = "Storage class of Braintrust GCS buckets."
  default     = "STANDARD"
}

variable "gcs_uniform_bucket_level_access" {
  type        = bool
  description = "Boolean to enable uniform bucket level access on Braintrust GCS buckets."
  default     = true
}

variable "gcs_force_destroy" {
  type        = bool
  description = "Boolean indicating whether to allow force destroying the Braintrust GCS buckets. GCS buckets can be destroyed if it is not empty when `true`."
  default     = false
}

variable "gcs_versioning_enabled" {
  type        = bool
  description = "Boolean to enable versioning on Braintrust GCS buckets."
  default     = true
}

variable "gcs_bucket_retention_days" {
  type        = number
  description = "Number of days to retain objects in the Brainstore GCS buckets."
  default     = 7
}

variable "gcs_additional_allowed_origins" {
  type        = list(string)
  description = "Additional allowed origins for the Braintrust GCS buckets."
  default     = []
}

variable "gcs_kms_cmek_id" {
  type        = string
  description = "ID of Cloud KMS customer managed encryption key (CMEK) to use for Braintrust GCS buckets encryption."
  default     = null
}

variable "gcs_soft_delete_retention_days" {
  type        = number
  description = "Number of days to retain soft-deleted objects in Braintrust GCS buckets. During this period, deleted objects can be recovered. Set to 0 to disable soft delete policy. This value must be be 0 or between 7 and 90 days."
  default     = 7

  validation {
    condition     = var.gcs_soft_delete_retention_days == 0 || (var.gcs_soft_delete_retention_days >= 7 && var.gcs_soft_delete_retention_days <= 90)
    error_message = "`gcs_soft_delete_retention_days` must be 0 or between 7 and 90 days."
  }
}

variable "custom_gcs_brainstore_lifecycle_rules" {
  description = "Additional lifecycle rules for the brainstore GCS bucket. Allows defining custom object expiration policies for specific prefixes."
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                        = optional(number)
      days_since_noncurrent_time = optional(number)
      matches_prefix             = optional(list(string))
      matches_suffix             = optional(list(string))
      with_state                 = optional(string)
    })
  }))
  default = []
}

variable "custom_gcs_api_lifecycle_rules" {
  description = "Additional lifecycle rules for the API GCS bucket. Allows defining custom object expiration policies for specific prefixes."
  type = list(object({
    action = object({
      type          = string
      storage_class = optional(string)
    })
    condition = object({
      age                        = optional(number)
      days_since_noncurrent_time = optional(number)
      matches_prefix             = optional(list(string))
      matches_suffix             = optional(list(string))
      with_state                 = optional(string)
    })
  }))
  default = []
}

