output "bootstrap" {
  description = "Non-secret bootstrap metadata for later Outpost registration. It does not establish readiness."
  value = {
    id                                = var.bootstrap_id
    project_id                        = data.google_project.customer.project_id
    project_number                    = tostring(data.google_project.customer.number)
    region                            = var.region
    license_secrets                   = sort(tolist(var.license_secrets))
    issuable                          = false
    machine_execution_supported       = false
    diagnostics_activation_supported  = false
    enable_diagnostics                = var.enable_diagnostics
    deployment_service_account        = google_service_account.bootstrap["deployment"].email
    observer_service_account          = google_service_account.bootstrap["observer"].email
    diagnostics_service_account       = try(google_service_account.bootstrap["diagnostics"].email, null)
    braintrust_bridge_service_account = var.braintrust_bridge_service_account
    storage_service_account           = data.google_storage_project_service_account.customer.email_address
    required_apis                     = sort(tolist(local.services))
    service_agents = merge({
      for name, agent in local.platform_service_agents : name => {
        service       = agent.service
        email         = agent.email
        project_roles = [agent.role]
      }
      }, {
      storage = {
        service       = "storage.googleapis.com"
        email         = data.google_storage_project_service_account.customer.email_address
        project_roles = []
      }
    })
    state = {
      bucket          = google_storage_bucket.state.name
      location        = google_storage_bucket.state.location
      data_locations  = [for location in local.storage["state"].data_locations : upper(location)]
      kms_key         = local.storage_keys["state"]
      kms_key_created = local.storage["state"].kms_key == null
      prefix          = "braintrust-byoc/${var.bootstrap_id}/data-planes/"
    }
    evidence = {
      bucket          = google_storage_bucket.evidence.name
      location        = google_storage_bucket.evidence.location
      data_locations  = [for location in local.storage["evidence"].data_locations : upper(location)]
      kms_key         = local.storage_keys["evidence"]
      kms_key_created = local.storage["evidence"].kms_key == null
      prefix          = "braintrust-byoc/${var.bootstrap_id}/operations/"
    }
  }
}
