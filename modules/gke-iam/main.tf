#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
locals {
  common_labels = {
    braintrustdeploymentname = var.deployment_name
  }
}

data "google_client_config" "current" {}

data "google_project" "current" {}

#----------------------------------------------------------------------------------------------
# Braintrust service account
#----------------------------------------------------------------------------------------------
resource "google_service_account" "braintrust" {
  account_id   = "${var.deployment_name}-braintrust"
  display_name = "${var.deployment_name}-braintrust"
  description  = "Service account for Braintrust for GCP GKE workload identity."
}

resource "google_service_account_key" "braintrust" {
  service_account_id = google_service_account.braintrust.name
}

resource "google_service_account_iam_binding" "braintrust_workload_identity" {
  service_account_id = google_service_account.braintrust.id
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${data.google_project.current.project_id}.svc.id.goog[${var.braintrust_kube_namespace}/${var.braintrust_kube_svc_account}]"
  ]
}

resource "google_storage_bucket_iam_member" "braintrust_api_gcs_object_admin" {
  bucket = var.braintrust_api_bucket_id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.braintrust.email}"
}

resource "google_storage_bucket_iam_member" "braintrust_api_gcs_reader" {
  bucket = var.braintrust_api_bucket_id
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.braintrust.email}"
}

# #----------------------------------------------------------------------------------------------
# # Cloud SQL IAM permissions for braintrust service account
# #----------------------------------------------------------------------------------------------
# Only username / password auth is supported for now, but future support for IAM auth is planned.
# resource "google_project_iam_member" "braintrust_cloudsql_client" {
#   project = data.google_project.current.project_id
#   role    = "roles/cloudsql.client"
#   member  = "serviceAccount:${google_service_account.braintrust.email}"
# }

# resource "google_project_iam_member" "braintrust_cloudsql_instance_user" {
#   project = data.google_project.current.project_id
#   role    = "roles/cloudsql.instanceUser"
#   member  = "serviceAccount:${google_service_account.braintrust.email}"
# }

#----------------------------------------------------------------------------------------------
# Brainstore service account
#----------------------------------------------------------------------------------------------
resource "google_service_account" "brainstore" {
  account_id   = "${var.deployment_name}-brainstore"
  display_name = "${var.deployment_name}-brainstore"
  description  = "Service account for Brainstore for GCP GKE workload identity."
}

resource "google_service_account_key" "brainstore" {
  service_account_id = google_service_account.brainstore.name
}

resource "google_service_account_iam_binding" "brainstore_workload_identity" {
  service_account_id = google_service_account.brainstore.id
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${data.google_project.current.project_id}.svc.id.goog[${var.braintrust_kube_namespace}/${var.brainstore_kube_svc_account}]"
  ]
}

resource "google_storage_bucket_iam_member" "brainstore_gcs_object_admin" {
  bucket = var.brainstore_gcs_bucket_id
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.brainstore.email}"
}

resource "google_storage_bucket_iam_member" "brainstore_gcs_reader" {
  bucket = var.brainstore_gcs_bucket_id
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.brainstore.email}"
}
