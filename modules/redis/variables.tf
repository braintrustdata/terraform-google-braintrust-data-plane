#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

#----------------------------------------------------------------------------------------------
# Redis
#----------------------------------------------------------------------------------------------
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

variable "redis_kms_cmek_id" {
  type        = string
  description = "ID of Cloud KMS customer managed encryption key (CMEK) to use for Braintrust Redis instance."
}

variable "redis_network" {
  type        = string
  description = "Name of the VPC network to connect to the Redis instance."
}
