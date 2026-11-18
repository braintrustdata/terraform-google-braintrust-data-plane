variable "project_id" {
  description = "Existing dedicated customer project ID."
  type        = string
}

variable "project_number" {
  description = "Expected customer project number."
  type        = string
}

variable "region" {
  description = "Customer deployment region."
  type        = string
}

variable "bootstrap_id" {
  description = "Exact Bootstrap ID from the Outpost handoff."
  type        = string
}

variable "enable_diagnostics" {
  description = "Create the dormant Diagnostics account."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Customer resource labels."
  type        = map(string)
  default     = {}
}

variable "request_quotas" {
  description = "Submit reviewed quota preferences through Terraform apply."
  type        = bool
  default     = false
}

variable "quota_contact_email" {
  description = "Customer Google account email with quota update permission."
  type        = string
  default     = null
}

variable "quota_preferences" {
  description = "Optional replacement for the default Compute quota targets."
  type = map(object({
    quota_id        = string
    preferred_value = number
    dimensions      = optional(map(string), {})
  }))
  default = null
}

variable "state_storage" {
  description = "State bucket location, optional dual-region pair, and optional existing CryptoKey."
  type = object({
    location       = optional(string)
    data_locations = optional(list(string), [])
    kms_key        = optional(string)
  })
  default  = {}
  nullable = false
}

variable "evidence_storage" {
  description = "Evidence bucket location, optional dual-region pair, and optional existing CryptoKey."
  type = object({
    location       = optional(string)
    data_locations = optional(list(string), [])
    kms_key        = optional(string)
  })
  default  = {}
  nullable = false
}

variable "license_secrets" {
  description = "Exact existing license secrets for read-only Deployment grants."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "braintrust_bridge_service_account" {
  description = "Exact bootstrap-specific Braintrust bridge account from the Braintrust tfvars file."
  type        = string
  nullable    = false
}
