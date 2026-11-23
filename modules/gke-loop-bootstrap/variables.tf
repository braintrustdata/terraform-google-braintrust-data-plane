variable "deployment_name" { type = string }
variable "region" { type = string }
variable "endpoint" { type = string }
variable "deploy_service_account_email" {
  type        = string
  default     = null
  description = "Existing deployment service account. Null creates an installer with project Kubernetes administration."
  validation {
    condition     = var.deploy_service_account_email == null || can(regex("^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\\.gserviceaccount\\.com$", var.deploy_service_account_email))
    error_message = "The deployment identity must be a Google service account email, or null to create an installer automatically."
  }
}
variable "runtime_service_account" { type = string }
variable "workers" {
  type = object({
    checkpoint_store = string
    discovery = object({
      hostname                = string
      external_dns_namespace  = string
      external_dns_extra_args = list(string)
    })
  })
}
variable "options" {
  type = object({
    services_version               = optional(string)
    worker_replicas                = optional(number, 1)
    worker_helm_values             = optional(string, "")
    brainstore_license_secret_name = optional(string, "brainstore-license-key")
    control_plane_telemetry        = optional(string, "status,metrics,usage")
  })
  default  = {}
  nullable = false
  validation {
    condition     = var.options.worker_replicas >= 0 && floor(var.options.worker_replicas) == var.options.worker_replicas
    error_message = "Worker replicas must be a non-negative integer."
  }
  validation {
    condition     = var.options.worker_helm_values == "" || can(keys(yamldecode(var.options.worker_helm_values)))
    error_message = "Worker Helm values must be valid YAML."
  }
}
