#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

#------------------------------------------------------------------------------
# Redis
#------------------------------------------------------------------------------
variable "redis_version" {
  type        = string
  description = "The version of Redis software."
  default     = "REDIS_7_2"
}

variable "redis_memory_size_gb" {
  type        = number
  description = "The size of the Redis instance in GiB."
  default     = 3
}

variable "redis_kms_keyring_name" {
  type        = string
  description = "Name of Cloud KMS key ring that contains KMS customer managed encryption key (CMEK) to use for Brainstore Redis instance. Geographic location (region) of key ring must match the location of the Braintrust Redis instance."
  default     = null
}

variable "redis_kms_cmek_name" {
  type        = string
  description = "Name of Cloud KMS customer managed encryption key (CMEK) to use for Braintrust Redis instance."
  default     = null
}

variable "redis_network" {
  type        = string
  description = "Name of the VPC network to connect to the Redis instance."
}
