#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

#----------------------------------------------------------------------------------------------
# Cloud Run API
#----------------------------------------------------------------------------------------------
variable "region" {
  description = "Region to deploy resources to."
  type        = string
}

variable "org_name" {
  description = "Name of the organization."
  type        = string
  default     = "*"
}

variable "api_version_override" {
  description = "Version of the API to use."
  type        = string
  default     = null
}

variable "database_username" {
  description = "Username for the PostgreSQL instance."
  type        = string
  default     = "postgres"
}

variable "database_password" {
  description = "Password for the PostgreSQL instance."
  type        = string
}

variable "database_host" {
  description = "Host for the PostgreSQL instance."
  type        = string
}

variable "database_port" {
  description = "Port for the PostgreSQL instance."
  type        = string
  default     = "5432"
}

variable "database_name" {
  description = "Database for the PostgreSQL instance."
  type        = string
  default     = "postgres"
}

variable "redis_host" {
  description = "Host for the Redis instance."
  type        = string
}
variable "redis_port" {
  description = "Port for the Redis instance."
  type        = string
}

variable "brainstore_reader_url" {
  description = "URL of the Brainstore reader instance."
  type        = string
}

variable "brainstore_writer_url" {
  description = "URL of the Brainstore writer instance."
  type        = string
}

variable "brainstore_reader_port" {
  description = "Port for the Brainstore reader instance."
  type        = number
}

variable "brainstore_writer_port" {
  description = "Port for the Brainstore writer instance."
  type        = number
}

variable "api_cpu_limit" {
  description = "CPU limit for the API container."
  type        = number
  default     = 8
}

variable "api_memory_limit" {
  description = "Memory limit for the API container."
  type        = string
  default     = "32Gi"
}

variable "api_container_concurrency" {
  description = "Container concurrency for the API container."
  type        = number
  default     = 1000
}

variable "api_timeout_seconds" {
  description = "Timeout for the API container."
  type        = number
  default     = 300
}

variable "api_max_instances" {
  description = "Maximum number of instances for the API container."
  type        = number
  default     = 100
}

variable "api_min_instances" {
  description = "Minimum number of instances for the API container."
  type        = number
  default     = 2
}

variable "enable_public_access" {
  description = "Whether to enable public access to the API container."
  type        = bool
  default     = true
}

variable "vpc_access_connector" {
  description = "VPC access connector for the API container."
  type        = string
}

variable "kms_key_name" {
  description = "KMS key for encrypting Cloud Run service."
  type        = string
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection for the Cloud Run service."
  type        = bool
  default     = true
}