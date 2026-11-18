mock_provider "google" {
  override_during = plan
  mock_data "google_project" {
    defaults = { project_id = "customer-project", number = "123456789012" }
  }
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/customer-project/serviceAccounts/deployment@customer-project.iam.gserviceaccount.com"
      email = "deployment@customer-project.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_project_iam_custom_role" {
    defaults = { name = "projects/customer-project/roles/mockRole" }
  }
}
mock_provider "google-beta" {
  override_during = plan
}

override_resource {
  override_during = plan
  target          = module.bootstrap.google_project_service_identity.required["gke"]
  values = {
    email  = "service-123456789012@container-engine-robot.iam.gserviceaccount.com"
    member = "serviceAccount:service-123456789012@container-engine-robot.iam.gserviceaccount.com"
  }
}
override_resource {
  override_during = plan
  target          = module.bootstrap.google_project_service_identity.required["redis"]
  values = {
    email  = "service-123456789012@cloud-redis.iam.gserviceaccount.com"
    member = "serviceAccount:service-123456789012@cloud-redis.iam.gserviceaccount.com"
  }
}
override_resource {
  override_during = plan
  target          = module.bootstrap.google_project_service_identity.required["networking"]
  values = {
    email  = "service-123456789012@service-networking.iam.gserviceaccount.com"
    member = "serviceAccount:service-123456789012@service-networking.iam.gserviceaccount.com"
  }
}
override_resource {
  override_during = plan
  target          = module.bootstrap.google_project_service_identity.required["dns"]
  values = {
    email  = "service-123456789012@gcp-sa-dns.iam.gserviceaccount.com"
    member = "serviceAccount:service-123456789012@gcp-sa-dns.iam.gserviceaccount.com"
  }
}

variables {
  project_id                        = "customer-project"
  project_number                    = "123456789012"
  region                            = "us-central1"
  bootstrap_id                      = "bsp_019d1234-8abc-7def-8123-456789abc111"
  braintrust_bridge_service_account = "bootstrap-bridge@braintrust-byoc-staging.iam.gserviceaccount.com"
}

run "customer_handoff" {
  command = plan

  variables {
    enable_diagnostics = false
    state_storage      = { location = "us-east1" }
    evidence_storage   = { location = "US" }
    labels             = { environment = "customer" }
  }

  assert {
    condition = (
      output.bootstrap.project_id == var.project_id &&
      output.bootstrap.project_number == var.project_number &&
      output.bootstrap.id == var.bootstrap_id &&
      output.bootstrap.region == var.region &&
      output.bootstrap.braintrust_bridge_service_account == var.braintrust_bridge_service_account
    )
    error_message = "The customer root must preserve the exact Braintrust handoff identity."
  }

  assert {
    condition = (
      output.bootstrap.state.location == "US-EAST1" &&
      output.bootstrap.evidence.location == "US" &&
      output.bootstrap.diagnostics_service_account == null &&
      !output.bootstrap.enable_diagnostics &&
      length(output.quota_preferences) == 0 &&
      !output.bootstrap.issuable
    )
    error_message = "The customer root must preserve storage choices, diagnostics opt-out, and capability limits."
  }
}
