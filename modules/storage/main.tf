#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------

locals {
  default_origins = [
    "https://braintrust.dev",
    "https://*.braintrust.dev",
    "https://*.preview.braintrust.dev"
  ]

  all_origins = concat(local.default_origins, var.gcs_additional_allowed_origins)

  common_labels = {
    braintrustdeploymentname = var.deployment_name
  }
}

data "google_project" "current" {}

data "google_client_config" "current" {}

resource "random_id" "gcs_suffix" {
  byte_length = 4
}

#----------------------------------------------------------------------------------------------
# Google cloud storage (GCS) bucket - Brainstore
#----------------------------------------------------------------------------------------------

resource "google_storage_bucket" "brainstore" {
  name                        = "${var.deployment_name}-brainstore-${random_id.gcs_suffix.hex}"
  location                    = data.google_client_config.current.region
  storage_class               = var.gcs_storage_class
  uniform_bucket_level_access = var.gcs_uniform_bucket_level_access
  force_destroy               = var.gcs_force_destroy
  public_access_prevention    = "enforced"

  versioning {
    enabled = var.gcs_versioning_enabled
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.gcs_bucket_retention_days
    }
    action {
      type = "Delete"
    }
  }

  dynamic "encryption" {
    for_each = var.gcs_kms_cmek_id != null ? ["encryption"] : []

    content {
      default_kms_key_name = var.gcs_kms_cmek_id
    }
  }

  labels = local.common_labels

  lifecycle {
    ignore_changes = [
      name,
    ]
  }

  depends_on = [
    google_kms_crypto_key_iam_member.gcp_project_gcs_cmek
  ]

}

#----------------------------------------------------------------------------------------------
# Google cloud storage (GCS) bucket - code-bundle
#----------------------------------------------------------------------------------------------

resource "google_storage_bucket" "code_bundle" {
  name                        = "${var.deployment_name}-code-bundle-${random_id.gcs_suffix.hex}"
  location                    = data.google_client_config.current.region
  storage_class               = var.gcs_storage_class
  uniform_bucket_level_access = var.gcs_uniform_bucket_level_access
  force_destroy               = var.gcs_force_destroy
  public_access_prevention    = "enforced"

  versioning {
    enabled = var.gcs_versioning_enabled
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.gcs_bucket_retention_days
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = local.all_origins
    method          = ["PUT"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  dynamic "encryption" {
    for_each = var.gcs_kms_cmek_id != null ? ["encryption"] : []

    content {
      default_kms_key_name = var.gcs_kms_cmek_id
    }
  }

  labels = local.common_labels

  lifecycle {
    ignore_changes = [
      name,
    ]
  }

  depends_on = [
    google_kms_crypto_key_iam_member.gcp_project_gcs_cmek
  ]
}

#----------------------------------------------------------------------------------------------
# Google cloud storage (GCS) bucket - response
#----------------------------------------------------------------------------------------------

resource "google_storage_bucket" "response" {
  name                        = "${var.deployment_name}-response-${random_id.gcs_suffix.hex}"
  location                    = data.google_client_config.current.region
  storage_class               = var.gcs_storage_class
  uniform_bucket_level_access = var.gcs_uniform_bucket_level_access
  force_destroy               = var.gcs_force_destroy
  public_access_prevention    = "enforced"

  versioning {
    enabled = var.gcs_versioning_enabled
  }

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = local.all_origins
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  dynamic "encryption" {
    for_each = var.gcs_kms_cmek_id != null ? ["encryption"] : []

    content {
      default_kms_key_name = var.gcs_kms_cmek_id
    }
  }

  labels = local.common_labels

  lifecycle {
    ignore_changes = [
      name,
    ]
  }

  depends_on = [
    google_kms_crypto_key_iam_member.gcp_project_gcs_cmek
  ]

}

#----------------------------------------------------------------------------------------------
# GCS KMS CMEK
#----------------------------------------------------------------------------------------------
locals {
  gcs_service_account_email = "service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "gcp_project_gcs_cmek" {

  crypto_key_id = var.gcs_kms_cmek_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  member = "serviceAccount:${local.gcs_service_account_email}"
}
