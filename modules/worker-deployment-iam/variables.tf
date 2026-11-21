variable "deployment_name" {
  type        = string
  description = "Deployment name used to isolate the firewall role within the project."
}

variable "project_id" {
  type        = string
  description = "Project containing the deployment account and worker firewalls."
}

variable "deploy_service_account_email" {
  type        = string
  description = "Existing service account to grant the narrow worker firewall role."
}
