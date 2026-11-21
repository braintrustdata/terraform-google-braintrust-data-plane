variable "deployment_name" { type = string }
variable "region" { type = string }
variable "cluster" {
  type = object({ id = string, endpoint = string })
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
