terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 8.4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "bootstrap" {
  source = "../../modules/byoc-bootstrap"

  project_id                        = var.project_id
  project_number                    = var.project_number
  region                            = var.region
  bootstrap_id                      = var.bootstrap_id
  braintrust_bridge_service_account = var.braintrust_bridge_service_account
  enable_diagnostics                = var.enable_diagnostics
  labels                            = var.labels
  request_quotas                    = var.request_quotas
  quota_contact_email               = var.quota_contact_email
  quota_preferences                 = var.quota_preferences
}

output "bootstrap" {
  description = "Candidate metadata for later registration."
  value       = module.bootstrap.bootstrap
}

output "quota_preferences" {
  description = "Requested and granted quota values with pending approval status."
  value       = module.bootstrap.quota_preferences
}
