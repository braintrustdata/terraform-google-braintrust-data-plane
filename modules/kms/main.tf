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
# KMS
#----------------------------------------------------------------------------------------------

resource "random_id" "key_ring_suffix" {
  byte_length = 4
}
resource "google_kms_key_ring" "kms" {

  name     = "${var.deployment_name}-braintrust-key-ring-${random_id.key_ring_suffix.id}"
  location = data.google_client_config.current.region
}

resource "google_kms_crypto_key" "root" {

  name            = "${var.deployment_name}-braintrust"
  key_ring        = google_kms_key_ring.kms.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "31536000s"
  labels          = local.common_labels

  lifecycle {
    prevent_destroy = false
  }
}