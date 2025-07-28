
#----------------------------------------------------------------------------------------------
# Service Account
#----------------------------------------------------------------------------------------------
data "google_storage_project_service_account" "project" {}

resource "google_service_account" "brainstore" {
  account_id   = "${var.deployment_name}-brainstore"
  display_name = "${var.deployment_name}-brainstore"
  description  = "Service Account allowing Brainstore instance(s) to interact GCP resources and services."
}

resource "google_service_account_key" "brainstore" {
  service_account_id = google_service_account.brainstore.name
}

#----------------------------------------------------------------------------------------------
# Secret Manager - Database
#----------------------------------------------------------------------------------------------
resource "google_secret_manager_secret_iam_member" "database_secret" {

  secret_id = var.database_secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.brainstore.email}"
}

#----------------------------------------------------------------------------------------------
# Secret Manager - Brainstore License Key
#----------------------------------------------------------------------------------------------
resource "google_secret_manager_secret_iam_member" "brainstore_license_key" {

  secret_id = var.brainstore_license_key_secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.brainstore.email}"
}


#----------------------------------------------------------------------------------------------
# Cloud Storage Buckets
#----------------------------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "brainstore_object_admin" {

  bucket = var.brainstore_gcs_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.brainstore.email}"
}

resource "google_storage_bucket_iam_member" "brainstore" {

  bucket = var.brainstore_gcs_bucket
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.brainstore.email}"
}

#----------------------------------------------------------------------------------------------
# Logging and Monitoring
#----------------------------------------------------------------------------------------------
resource "google_project_iam_member" "brainstore_logging" {
  project = data.google_project.current.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.brainstore.email}"
}

resource "google_project_iam_member" "brainstore_monitoring" {
  project = data.google_project.current.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.brainstore.email}"
}

