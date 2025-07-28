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
variable "gcs_location" {
  type        = string
  description = "Location of Braintrust GCS buckets to create. We only recommend using single region buckets due performance and cost considerations."
}

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

variable "gcs_kms_keyring_name" {
  type        = string
  description = "Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for Braintrust GCS buckets encryption. Geographic location (region) of the key ring must match the location of the Braintrust GCS buckets."
  default     = null
}

variable "gcs_kms_cmek_name" {
  type        = string
  description = "Name of Cloud KMS customer managed encryption key (CMEK) to use for Braintrust GCS buckets encryption."
  default     = null
}

