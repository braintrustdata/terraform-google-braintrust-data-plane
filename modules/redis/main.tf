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

#------------------------------------------------------------------------------
# Redis instance
#------------------------------------------------------------------------------
resource "google_redis_instance" "braintrust" {
  name                    = "${var.deployment_name}-redis"
  display_name            = "${var.deployment_name}-redis"
  tier                    = "STANDARD_HA"
  redis_version           = var.redis_version
  memory_size_gb          = var.redis_memory_size_gb
  auth_enabled            = false
  transit_encryption_mode = "DISABLED"
  authorized_network      = var.redis_network
  connect_mode            = "PRIVATE_SERVICE_ACCESS"
  customer_managed_key    = var.redis_kms_cmek_name != null ? data.google_kms_crypto_key.redis[0].id : null
  labels                  = local.common_labels

  depends_on = [
    google_kms_crypto_key_iam_binding.redis_sa_cmek
  ]
}

#------------------------------------------------------------------------------
# KMS Redis customer managed encryption key (CMEK)
#------------------------------------------------------------------------------
data "google_kms_key_ring" "redis" {
  count = var.redis_kms_keyring_name != null ? 1 : 0

  name     = var.redis_kms_keyring_name
  location = data.google_client_config.current.region
}

data "google_kms_crypto_key" "redis" {
  count = var.redis_kms_cmek_name != null ? 1 : 0

  name     = var.redis_kms_cmek_name
  key_ring = data.google_kms_key_ring.redis[0].id
}

#------------------------------------------------------------------------------
# Redis KMS CMEK
#------------------------------------------------------------------------------
locals {
  redis_service_account_email = "service-${data.google_project.current.number}@cloud-redis.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_binding" "redis_sa_cmek" {
  count = var.redis_kms_cmek_name != null ? 1 : 0

  crypto_key_id = data.google_kms_crypto_key.redis[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${local.redis_service_account_email}",
  ]
}
