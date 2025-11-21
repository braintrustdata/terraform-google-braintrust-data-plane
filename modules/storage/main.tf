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

  dynamic "soft_delete_policy" {
    for_each = var.gcs_soft_delete_retention_days > 0 ? [1] : []

    content {
      retention_duration_seconds = var.gcs_soft_delete_retention_days * 86400
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.gcs_bucket_retention_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  # Lifecycle rule to clean up delete ops from Brainstore index and wal prefixes
  # !IMPORTANT!: do not change this path
  lifecycle_rule {
    condition {
      age            = var.gcs_bucket_retention_days
      matches_prefix = ["brainstore/index/delete_ops/", "brainstore/wal/delete_ops/"]
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
# Google cloud storage (GCS) bucket - api (combines code-bundle and response)
#----------------------------------------------------------------------------------------------
resource "google_storage_bucket" "api" {
  name                        = "${var.deployment_name}-api-${random_id.gcs_suffix.hex}"
  location                    = data.google_client_config.current.region
  storage_class               = var.gcs_storage_class
  uniform_bucket_level_access = var.gcs_uniform_bucket_level_access
  force_destroy               = var.gcs_force_destroy
  public_access_prevention    = "enforced"

  versioning {
    enabled = var.gcs_versioning_enabled
  }

  dynamic "soft_delete_policy" {
    for_each = var.gcs_soft_delete_retention_days > 0 ? [1] : []

    content {
      retention_duration_seconds = var.gcs_soft_delete_retention_days * 86400
    }
  }

  # Lifecycle rule for code-bundle path
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = var.gcs_bucket_retention_days
      matches_prefix             = ["code-bundle/"]
    }
    action {
      type = "Delete"
    }
  }

  # Lifecycle rule for response path
  lifecycle_rule {
    condition {
      age            = 1
      matches_prefix = ["response/"]
    }
    action {
      type = "Delete"
    }
  }

  # Lifecycle rule for incomplete multipart uploads
  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  # Unified CORS configuration (union of both buckets)
  cors {
    origin          = local.all_origins
    method          = ["PUT", "GET", "HEAD"]
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
  member        = "serviceAccount:${local.gcs_service_account_email}"
}
