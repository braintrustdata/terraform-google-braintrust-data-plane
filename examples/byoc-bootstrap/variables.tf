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

variable "braintrust_bridge_service_account" {
  description = "Exact Braintrust bridge account from the Outpost handoff."
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
  description = "Optional replacement for the v1 Compute quota targets."
  type = map(object({
    quota_id        = string
    preferred_value = number
    dimensions      = optional(map(string), {})
  }))
  default = null
}
