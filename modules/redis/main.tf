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
# Redis instance
#----------------------------------------------------------------------------------------------
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
  customer_managed_key    = var.redis_kms_cmek_id
  labels                  = local.common_labels

  depends_on = [
    google_kms_crypto_key_iam_member.redis_sa_cmek
  ]
}

#----------------------------------------------------------------------------------------------
# Redis KMS CMEK
#----------------------------------------------------------------------------------------------
locals {
  redis_service_account_email = "service-${data.google_project.current.number}@cloud-redis.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "redis_sa_cmek" {

  crypto_key_id = var.redis_kms_cmek_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  member = "serviceAccount:${local.redis_service_account_email}"

}
