variable "primary_cidrs" {
  type        = list(string)
  default     = []
  description = "Known primary network ranges for overlap validation."
}

variable "config" {
  type = object({
    existing_subnet_self_link = optional(string)
    discovery = optional(object({
      external_dns_namespace       = optional(string)
      external_dns_service_account = optional(string, "external-dns")
      dns_name                     = string
      runtime_source_ranges        = set(string)
    }))
    node_cidr          = optional(string)
    pod_cidr           = string
    service_cidr       = string
    control_plane_cidr = string
    ingress_rules = optional(map(object({
      source_ranges = set(string)
      ports         = set(string)
    })), {})
    egress_rules = optional(map(object({
      destination_ranges = set(string)
      ports              = set(string)
    })), {})
  })
  nullable    = false
  description = "Isolated worker network configuration."

  validation {
    condition = var.config.discovery == null ? true : (
      length(var.config.discovery.runtime_source_ranges) > 0 &&
      alltrue([for cidr in var.config.discovery.runtime_source_ranges : can(cidrnetmask(cidr)) && try(tonumber(split("/", cidr)[1]) > 0 && cidrhost(cidr, 0) == split("/", cidr)[0], false)]) &&
      length(var.config.discovery.dns_name) <= 240 &&
      can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z][a-z0-9-]*\\.?$", var.config.discovery.dns_name))
    )
    error_message = "Discovery requires a lowercase DNS domain and explicit canonical IPv4 source ranges without a default route."
  }

  validation {
    condition = alltrue([
      for cidr in compact([var.config.node_cidr, var.config.pod_cidr, var.config.service_cidr, var.config.control_plane_cidr]) :
      can(cidrnetmask(cidr)) && try(cidrhost(cidr, 0) == split("/", cidr)[0], false)
    ]) && can(regex("/28$", var.config.control_plane_cidr))
    error_message = "Worker ranges must be canonical IPv4 CIDRs. The control plane requires a /28."
  }

  validation {
    condition = alltrue(concat(
      flatten([for rule in values(var.config.ingress_rules) : [for cidr in rule.source_ranges : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"]]),
      flatten([for rule in values(var.config.egress_rules) : [for cidr in rule.destination_ranges : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"]])
    ))
    error_message = "Access rules require IPv4 ranges. Worker traffic rules cannot use 0.0.0.0/0."
  }

  validation {
    condition = alltrue(concat(
      [for rule in values(var.config.ingress_rules) : length(rule.source_ranges) > 0 && length(rule.ports) > 0],
      [for rule in values(var.config.egress_rules) : length(rule.destination_ranges) > 0 && length(rule.ports) > 0],
      flatten([for rule in concat(values(var.config.ingress_rules), values(var.config.egress_rules)) : [
        for port in rule.ports : try(tonumber(port) >= 1 && tonumber(port) <= 65535 && floor(tonumber(port)) == tonumber(port), false)
      ]])
    ))
    error_message = "Traffic rules require nonempty ranges and explicit TCP ports from 1 through 65535."
  }
}

variable "custom_labels" {
  type        = map(string)
  default     = {}
  description = "Labels for isolated worker network resources."
}

variable "deployment_name" {
  type        = string
  description = "Deployment name for isolated worker resources."
}
variable "network" {
  type        = string
  description = "VPC self link for isolated workers."
}
variable "primary_subnet" {
  type        = string
  description = "Primary subnet self link. Workers require a different subnet."
}
