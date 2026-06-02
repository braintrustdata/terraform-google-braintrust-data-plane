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

variable "private_service_access_prefix_length" {
  description = "Prefix length for the Private Service Access range used by Cloud SQL and Memorystore. Valid values are 8 through 24: lower prefix lengths create larger ranges, while higher prefix lengths create smaller ranges. Smaller ranges are supported, but choose the size based on the customer's networking requirements because they reduce future expansion headroom. Choose this carefully before first deployment; changing Private Service Access ranges later can require rebuilding dependent resources."
  type        = number

  validation {
    condition     = var.private_service_access_prefix_length >= 8 && var.private_service_access_prefix_length <= 24
    error_message = "`private_service_access_prefix_length` must be between 8 and 24 inclusive."
  }
}

variable "private_service_access_address" {
  description = "Optional starting address for the Private Service Access range used by Cloud SQL and Memorystore. If null, Google selects an available range. Set this when you need to avoid overlap with existing VPCs, peering, or corporate networks."
  type        = string
  default     = null
}
