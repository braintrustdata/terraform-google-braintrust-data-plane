output "bootstrap" {
  description = "Non-secret candidate metadata for later Outpost registration. It does not establish readiness."
  value = {
    id                                = var.bootstrap_id
    project_id                        = data.google_project.customer.project_id
    project_number                    = tostring(data.google_project.customer.number)
    region                            = var.region
    contract_status                   = "draft"
    issuable                          = false
    machine_execution_supported       = false
    diagnostics_activation_supported  = false
    enable_diagnostics                = var.enable_diagnostics
    deployment_service_account        = google_service_account.bootstrap["deployment"].email
    observer_service_account          = google_service_account.bootstrap["observer"].email
    diagnostics_service_account       = try(google_service_account.bootstrap["diagnostics"].email, null)
    braintrust_bridge_service_account = var.braintrust_bridge_service_account
    storage_service_account           = data.google_storage_project_service_account.customer.email_address
    state = {
      bucket = google_storage_bucket.state.name
      prefix = "braintrust-byoc/${var.bootstrap_id}/data-planes/"
    }
    evidence = {
      bucket = google_storage_bucket.evidence.name
      prefix = "braintrust-byoc/${var.bootstrap_id}/operations/"
    }
  }
}
