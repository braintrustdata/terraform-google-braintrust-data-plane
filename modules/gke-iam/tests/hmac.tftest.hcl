mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      id    = "projects/test-project/serviceAccounts/bt-test@test-project.iam.gserviceaccount.com"
      email = "bt-test@test-project.iam.gserviceaccount.com"
    }
  }
}

variables {
  deployment_name           = "bt-test"
  braintrust_kube_namespace = "braintrust"
  braintrust_api_bucket_id  = "bt-test-api"
  brainstore_gcs_bucket_id  = "bt-test-brainstore"
  workload_identity_pool    = "test-project.svc.id.goog"
}

run "hmac_enabled_by_default" {
  command = apply

  assert {
    condition     = length(google_storage_hmac_key.braintrust) == 1
    error_message = "HMAC key should be created by default"
  }

  assert {
    condition     = output.braintrust_hmac_access_id != null && output.braintrust_hmac_secret != null
    error_message = "HMAC outputs should be set when enabled"
  }
}

run "hmac_disabled" {
  command = apply

  variables {
    braintrust_hmac_key_enabled = false
  }

  assert {
    condition     = length(google_storage_hmac_key.braintrust) == 0
    error_message = "HMAC key should not be created when disabled"
  }

  assert {
    condition     = output.braintrust_hmac_access_id == null && output.braintrust_hmac_secret == null
    error_message = "HMAC outputs should be null when disabled"
  }
}
