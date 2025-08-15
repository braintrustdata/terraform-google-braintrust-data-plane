#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

#----------------------------------------------------------------------------------------------
# Network
#----------------------------------------------------------------------------------------------
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "subnet_cidr_range" {
  description = "The IP address range of the subnet in CIDR notation"
  type        = string
}

variable "deployment_type" {
  description = "Type of deployment either using gke or cloud run."
  type        = string
  default     = "cloud-run"
  validation {
    condition     = contains(["gke", "cloud-run"], var.deployment_type)
    error_message = "Deployment type must be either 'cloud-run' or 'gke'."
  }
}

variable "vpc_access_connector_ip_cidr_range" {
  description = "IP CIDR range for the VPC access connector."
  type        = string
}