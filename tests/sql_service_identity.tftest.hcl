mock_provider "google" {
  mock_data "google_project" {
    defaults = { project_id = "customer-project", number = "123456789012" }
  }
  mock_data "google_client_config" {
    defaults = { project = "customer-project", region = "us-central1" }
  }
}
mock_provider "google-beta" {
  mock_resource "google_project_service_identity" {
    defaults = { email = "service-123456789012@gcp-sa-cloud-sql.iam.gserviceaccount.com" }
  }
}
mock_provider "random" {}

variables {
  deployment_name      = "sql-identity-test"
  postgres_network     = "projects/customer-project/global/networks/test"
  postgres_kms_cmek_id = "projects/customer-project/locations/us-central1/keyRings/test/cryptoKeys/test"
}

run "default_keeps_generation" {
  command = plan
  module { source = "./modules/database" }
  assert {
    condition     = length(google_project_service_identity.cloud_sql_sa) == 1 && google_project_service_identity.cloud_sql_sa[0].service == "sqladmin.googleapis.com"
    error_message = "Default callers must retain the SQL identity generation path."
  }
}

run "prepared_identity_skips_generation" {
  command = plan
  module { source = "./modules/database" }
  variables {
    postgres_service_identity_email = "service-123456789012@gcp-sa-cloud-sql.iam.gserviceaccount.com"
  }
  assert {
    condition = (
      length(google_project_service_identity.cloud_sql_sa) == 0 &&
      google_kms_crypto_key_iam_member.cloud_sql_sa_postgres_cmek.member == "serviceAccount:service-123456789012@gcp-sa-cloud-sql.iam.gserviceaccount.com"
    )
    error_message = "The prepared path must omit identity generation and retain the exact workload key grant."
  }
}

run "reject_workload_account_as_agent" {
  command = plan
  module { source = "./modules/database" }
  variables { postgres_service_identity_email = "workload@customer-project.iam.gserviceaccount.com" }
  expect_failures = [var.postgres_service_identity_email]
}

run "root_rejects_foreign_project_agent" {
  command = plan
  variables {
    postgres_service_identity_email = "service-555555555555@gcp-sa-cloud-sql.iam.gserviceaccount.com"
  }
  expect_failures = [var.postgres_service_identity_email]
}

run "root_passes_prepared_identity" {
  command = plan
  variables {
    postgres_service_identity_email = "service-123456789012@gcp-sa-cloud-sql.iam.gserviceaccount.com"
  }
  assert {
    condition     = module.database.postgres_service_identity_email == "service-123456789012@gcp-sa-cloud-sql.iam.gserviceaccount.com"
    error_message = "The root must pass the prepared identity to the database module without identity generation."
  }
}
