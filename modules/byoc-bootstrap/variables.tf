variable "project_id" {
  description = "Existing dedicated customer project ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "The project ID must contain 6 to 30 lowercase letters, digits, or hyphens."
  }
}

variable "project_number" {
  description = "Expected customer project number, distinct from the project ID."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[1-9][0-9]{0,19}$", var.project_number))
    error_message = "The project number must be a positive decimal string."
  }
}

variable "region" {
  description = "Customer region for bootstrap storage and quota preferences."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+$", var.region))
    error_message = "The region must be a GCP region name, such as us-central1."
  }
}

variable "bootstrap_id" {
  description = "Canonical Bootstrap ID assigned by Outpost. It defines deterministic resource names."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^bsp_[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$", var.bootstrap_id))
    error_message = "The bootstrap ID must be a canonical bsp_ UUIDv7 identifier."
  }
}

variable "braintrust_bridge_service_account" {
  description = "Exact bootstrap-specific Braintrust bridge account assigned by Outpost."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]@[a-z][a-z0-9-]{4,28}[a-z0-9]\\.iam\\.gserviceaccount\\.com$", var.braintrust_bridge_service_account))
    error_message = "The bridge must be one exact GCP service account email."
  }
}

variable "enable_diagnostics" {
  description = "Create the dormant Diagnostics account. This candidate provides no activation mechanism."
  type        = bool
  default     = true
  nullable    = false
}

variable "labels" {
  description = "Customer labels for bootstrap storage. The braintrust_bootstrap label is reserved."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition = length(var.labels) <= 63 && alltrue([
      for key, value in var.labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", key)) && value != null && can(regex("^[a-z0-9_-]{0,63}$", value))
    ]) && !contains(keys(var.labels), "braintrust_bootstrap")
    error_message = "Labels must use valid keys and values and must not override braintrust_bootstrap."
  }
}

variable "request_quotas" {
  description = "Manage quota preferences through customer Terraform apply. Defaults to disabled."
  type        = bool
  default     = false
  nullable    = false
}

variable "quota_contact_email" {
  description = "Customer Google account email for quota communication. It requires quota update permission."
  type        = string
  default     = null

  validation {
    condition     = !var.request_quotas || can(regex("^[^[:space:]@]+@[^[:space:]@]+\\.[^[:space:]@]+$", var.quota_contact_email))
    error_message = "If quota requests are enabled, provide a customer contact email with quota update permission."
  }
}

variable "quota_preferences" {
  description = "Optional replacement for the v1 Compute quota targets. Null selects the v1 baseline."
  type = map(object({
    quota_id        = string
    preferred_value = number
    dimensions      = optional(map(string), {})
  }))
  default = null

  validation {
    condition = var.quota_preferences == null ? true : try(alltrue([
      for key, preference in var.quota_preferences :
      can(regex("^[a-z][a-z0-9-]{0,62}$", key)) &&
      can(regex("^[A-Za-z0-9-]+$", preference.quota_id)) &&
      preference.preferred_value >= 0 && floor(preference.preferred_value) == preference.preferred_value &&
      alltrue([for dimension, value in preference.dimensions :
        !contains(["region", "user", "resource"], dimension) && value != null && trimspace(value) != ""
      ])
    ]), false)
    error_message = "Quota preferences require stable keys, quota IDs, and nonnegative integer values. Region, user, and resource dimensions are reserved."
  }

  validation {
    condition = var.quota_preferences == null ? true : try(length(distinct([
      for preference in values(var.quota_preferences) : jsonencode([
        preference.quota_id,
        { for key, value in preference.dimensions : key => key == "vm_family" ? upper(value) : value }
      ])
    ])) == length(var.quota_preferences), false)
    error_message = "Each quota and dimension combination must appear only once."
  }
}
