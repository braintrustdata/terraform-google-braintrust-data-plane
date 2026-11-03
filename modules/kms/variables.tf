#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

variable "custom_labels" {
  type        = map(string)
  description = "Optional labels to apply to all resources that support labels."
  default     = {}
}

variable "grant_gke_access" {
  type        = bool
  default     = false
  description = "Grant the project GKE and Compute service agents access to this key."
}
variable "project_number" {
  type        = string
  default     = null
  description = "Project number for Google service-agent identities."
  validation {
    condition     = !var.grant_gke_access || can(regex("^[0-9]+$", var.project_number))
    error_message = "GKE key access requires a numeric project number."
  }
}
