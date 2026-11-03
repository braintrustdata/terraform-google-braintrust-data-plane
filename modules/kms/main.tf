#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
locals {
  common_labels = merge(var.custom_labels, {
    braintrustdeploymentname = var.deployment_name
  })
}

data "google_client_config" "current" {}

#----------------------------------------------------------------------------------------------
# KMS
#----------------------------------------------------------------------------------------------

resource "random_id" "key_ring_suffix" {
  byte_length = 4
}
resource "google_kms_key_ring" "kms" {
  name     = "${var.deployment_name}-braintrust-key-ring-${random_id.key_ring_suffix.id}"
  location = data.google_client_config.current.region
}

resource "google_kms_crypto_key" "kms" {
  name            = "${var.deployment_name}-braintrust"
  key_ring        = google_kms_key_ring.kms.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "31536000s"
  labels          = local.common_labels

  lifecycle {
    prevent_destroy = false
  }
}

# Both clusters use the deployment key and the same project service agents.
resource "google_kms_crypto_key_iam_member" "gke_cluster_cmek" {
  count         = var.grant_gke_access ? 1 : 0
  crypto_key_id = google_kms_crypto_key.kms.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@container-engine-robot.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "gke_compute_cmek" {
  count         = var.grant_gke_access ? 1 : 0
  crypto_key_id = google_kms_crypto_key.kms.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@compute-system.iam.gserviceaccount.com"
}
