mock_provider "google" {
  mock_data "google_client_config" {
    defaults = { region = "us-central1", project = "braintrust-test" }
  }
  mock_data "google_project" {
    defaults = { project_id = "braintrust-test", number = "123456789012" }
  }
}
mock_provider "google-beta" {}
mock_provider "random" {}

variables {
  deployment_name               = "braintrust"
  gcs_kms_cmek_id               = "projects/braintrust-test/locations/us-central1/keyRings/braintrust/cryptoKeys/storage"
  gcs_brainstore_logging_config = {}
  gcs_api_logging_config        = {}
}

run "access_logs_expire_after_90_days_by_default" {
  command = apply
  module { source = "./modules/storage" }

  assert {
    condition = anytrue([
      for rule in google_storage_bucket.access_logs[0].lifecycle_rule :
      one(rule.action).type == "Delete" && one(rule.condition).age == 90
    ])
    error_message = "Access logs must be deleted after 90 days by default."
  }
  assert {
    condition = anytrue([
      for rule in google_storage_bucket.access_logs[0].lifecycle_rule :
      one(rule.action).type == "Delete" && one(rule.condition).days_since_noncurrent_time == 7
    ])
    error_message = "Deleted access log versions must be removed after gcs_bucket_retention_days."
  }
  assert {
    condition     = length(google_storage_bucket.access_logs[0].lifecycle_rule) == 2
    error_message = "The access log bucket must have exactly the age and noncurrent rules."
  }
}

run "access_log_retention_is_configurable" {
  command = apply
  module { source = "./modules/storage" }
  variables {
    gcs_access_log_retention_days = 365
    gcs_bucket_retention_days     = 14
  }

  assert {
    condition = anytrue([
      for rule in google_storage_bucket.access_logs[0].lifecycle_rule :
      one(rule.action).type == "Delete" && one(rule.condition).age == 365
    ])
    error_message = "Access logs must honor a custom retention period."
  }
  assert {
    condition = anytrue([
      for rule in google_storage_bucket.access_logs[0].lifecycle_rule :
      one(rule.action).type == "Delete" && one(rule.condition).days_since_noncurrent_time == 14
    ])
    error_message = "Deleted access log versions must honor gcs_bucket_retention_days."
  }
}

run "null_retention_keeps_access_logs_forever" {
  command = apply
  module { source = "./modules/storage" }
  variables {
    gcs_access_log_retention_days = null
  }

  assert {
    condition = alltrue([
      for rule in google_storage_bucket.access_logs[0].lifecycle_rule :
      one(rule.condition).age == null || one(rule.condition).age == 0
    ])
    error_message = "Null retention must not add an age-based delete rule."
  }
  assert {
    condition = (
      length(google_storage_bucket.access_logs[0].lifecycle_rule) == 1 &&
      one(one(google_storage_bucket.access_logs[0].lifecycle_rule).condition).days_since_noncurrent_time == 7
    )
    error_message = "Null retention must still remove deleted access log versions."
  }
}

run "existing_log_bucket_creates_no_access_log_bucket" {
  command = plan
  module { source = "./modules/storage" }
  variables {
    gcs_brainstore_logging_config = { log_bucket = "customer-logs" }
    gcs_api_logging_config        = null
    gcs_access_log_retention_days = 30
  }

  assert {
    condition     = length(google_storage_bucket.access_logs) == 0
    error_message = "A caller-provided log bucket must not create the dedicated bucket."
  }
}

run "zero_retention_is_rejected" {
  command = plan
  module { source = "./modules/storage" }
  variables {
    gcs_access_log_retention_days = 0
  }
  expect_failures = [var.gcs_access_log_retention_days]
}

run "root_rejects_fractional_retention" {
  command = plan
  variables {
    gcs_access_log_retention_days = 1.5
  }
  expect_failures = [var.gcs_access_log_retention_days]
}
