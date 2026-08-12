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

variable "subnet_flow_logs_config" {
  description = "Optional VPC flow logs configuration for the created subnet. Set to null to disable subnet flow logs."
  type = object({
    aggregation_interval = optional(string)
    flow_sampling        = optional(number)
    metadata             = optional(string)
    metadata_fields      = optional(list(string))
    filter_expr          = optional(string)
  })
  default = null

  validation {
    condition = var.subnet_flow_logs_config == null || try(var.subnet_flow_logs_config.aggregation_interval, null) == null || contains([
      "INTERVAL_5_SEC",
      "INTERVAL_30_SEC",
      "INTERVAL_1_MIN",
      "INTERVAL_5_MIN",
      "INTERVAL_10_MIN",
      "INTERVAL_15_MIN",
    ], try(var.subnet_flow_logs_config.aggregation_interval, null))
    error_message = "`subnet_flow_logs_config.aggregation_interval` must be one of INTERVAL_5_SEC, INTERVAL_30_SEC, INTERVAL_1_MIN, INTERVAL_5_MIN, INTERVAL_10_MIN, or INTERVAL_15_MIN."
  }

  validation {
    condition     = var.subnet_flow_logs_config == null || try(var.subnet_flow_logs_config.flow_sampling, null) == null || (try(var.subnet_flow_logs_config.flow_sampling, null) >= 0 && try(var.subnet_flow_logs_config.flow_sampling, null) <= 1)
    error_message = "`subnet_flow_logs_config.flow_sampling` must be between 0 and 1 inclusive."
  }

  validation {
    condition = var.subnet_flow_logs_config == null || try(var.subnet_flow_logs_config.metadata, null) == null || contains([
      "EXCLUDE_ALL_METADATA",
      "INCLUDE_ALL_METADATA",
      "CUSTOM_METADATA",
    ], try(var.subnet_flow_logs_config.metadata, null))
    error_message = "`subnet_flow_logs_config.metadata` must be one of EXCLUDE_ALL_METADATA, INCLUDE_ALL_METADATA, or CUSTOM_METADATA."
  }

  validation {
    condition     = var.subnet_flow_logs_config == null || try(var.subnet_flow_logs_config.metadata_fields, null) == null || try(var.subnet_flow_logs_config.metadata, null) == "CUSTOM_METADATA"
    error_message = "`subnet_flow_logs_config.metadata_fields` can only be set when `subnet_flow_logs_config.metadata` is `CUSTOM_METADATA`."
  }

  validation {
    condition     = var.subnet_flow_logs_config == null || try(var.subnet_flow_logs_config.metadata, null) != "CUSTOM_METADATA" || try(length(var.subnet_flow_logs_config.metadata_fields), 0) > 0
    error_message = "`subnet_flow_logs_config.metadata_fields` must contain at least one field when `subnet_flow_logs_config.metadata` is `CUSTOM_METADATA`."
  }

  validation {
    condition     = var.subnet_flow_logs_config == null || try(var.subnet_flow_logs_config.filter_expr, null) == null || try(trimspace(var.subnet_flow_logs_config.filter_expr), "") != ""
    error_message = "`subnet_flow_logs_config.filter_expr` must be a non-empty string when provided."
  }
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
