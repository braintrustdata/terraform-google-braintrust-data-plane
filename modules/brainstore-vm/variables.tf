#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

#----------------------------------------------------------------------------------------------
# Brainstore Reader and Writer
#----------------------------------------------------------------------------------------------

variable "brainstore_license_key_secret_name" {
  description = "Secret name for Brainstore license key."
  type        = string
}

variable "image_project" {
  type        = string
  description = "ID of project in which the base image belongs."
  default     = "ubuntu-os-cloud"
}

variable "image_name" {
  type        = string
  description = "VM image for Brainstore instance(s)."
  default     = "ubuntu-2404-noble-arm64-v20250722"
}

variable "brainstore_network" {
  description = "Network for Brainstore instances."
  type        = string
}

variable "brainstore_subnet" {
  description = "Subnet for Brainstore instances."
  type        = string
}


variable "brainstore_port" {
  description = "Port for Brainstore instances."
  type        = number
  default     = 4000
}

variable "brainstore_gcs_bucket" {
  description = "GCS bucket for Brainstore instances."
  type        = string
}

variable "redis_host" {
  description = "Redis host for Brainstore instances."
  type        = string
}

variable "redis_port" {
  description = "Redis port for Brainstore instances."
  type        = number
  default     = 6379
}

variable "database_host" {
  description = "Database host for Brainstore instances."
  type        = string
}

variable "database_port" {
  description = "Database port for Brainstore instances."
  type        = number
  default     = 5432
}

variable "database_secret_name" {
  description = "Database secret name for Brainstore instances."
  type        = string
}

variable "brainstore_disable_optimization_worker" {
  description = "Whether to disable the optimization worker in Brainstore"
  type        = bool
  default     = false
}

variable "brainstore_vacuum_all_objects" {
  description = "Whether to vacuum all objects in Brainstore"
  type        = bool
  default     = false
}

variable "internal_observability_api_key" {
  description = "Support for internal observability agent. Do not set this unless instructed by support."
  type        = string
  default     = ""
}

variable "internal_observability_env_name" {
  description = "Support for internal observability agent. Do not set this unless instructed by support."
  type        = string
  default     = ""
}

variable "internal_observability_region" {
  description = "Support for internal observability agent. Do not set this unless instructed by support."
  type        = string
  default     = "us5"
}

variable "brainstore_version_override" {
  description = "Lock Brainstore on a specific version. Don't set this unless instructed by Braintrust."
  type        = string
  default     = ""
}

variable "initial_delay_sec" {
  description = "Initial delay for Brainstore instances."
  type        = number
  default     = 120
}

variable "cidr_allow_ingress_vm_ssh" {
  description = "Allow SSH ingress to Brainstore instances from specified CIDR ranges."
  type        = list(string)
  default     = null
}

variable "allow_ingress_vm_ssh_from_iap" {
  description = "Allow SSH ingress to Brainstore instances from IAP."
  type        = bool
  default     = true
}

#----------------------------------------------------------------------------------------------
# Brainstore Reader
#----------------------------------------------------------------------------------------------

variable "brainstore_reader_instance_count" {
  description = "Number of Brainstore Reader instances to create."
  type        = number
  default     = 2
}

variable "brainstore_reader_machine_type" {
  description = "Machine type for Brainstore Reader instances."
  type        = string
  default     = "c4a-standard-16-lssd"
}

variable "brainstore_reader_disk_size_gb" {
  description = "Disk size for Brainstore Reader instances."
  type        = number
  default     = 200
}


variable "extra_env_vars_reader" {
  description = "Extra environment variables for Brainstore Reader instances."
  type        = map(string)
  default     = {}
}

#----------------------------------------------------------------------------------------------
# Brainstore Writer
#----------------------------------------------------------------------------------------------
variable "brainstore_writer_instance_count" {
  description = "Number of Brainstore Writer instances to create."
  type        = number
  default     = 1
}

variable "brainstore_writer_machine_type" {
  description = "Machine type for Brainstore Writer instances."
  type        = string
  default     = "c4a-standard-32-lssd"
}

variable "extra_env_vars_writer" {
  description = "Extra environment variables for Brainstore Writer instances."
  type        = map(string)
  default     = {}
}

variable "brainstore_writer_disk_size_gb" {
  description = "Disk size for Brainstore Writer instances."
  type        = number
  default     = 200
}
