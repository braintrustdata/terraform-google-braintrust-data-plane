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

resource "random_id" "gcs_suffix" {
  byte_length = 4
}

#------------------------------------------------------------------------------
# Google cloud storage (GCS) bucket - Brainstore
#------------------------------------------------------------------------------

resource "google_storage_bucket" "brainstore" {
  name                        = "${var.deployment_name}-brainstore-${random_id.gcs_suffix.hex}"
  location                    = var.gcs_location
  storage_class               = var.gcs_storage_class
  uniform_bucket_level_access = var.gcs_uniform_bucket_level_access
  force_destroy               = var.gcs_force_destroy

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
    for_each = var.gcs_kms_cmek_name != null ? ["encryption"] : []

    content {
      default_kms_key_name = data.google_kms_crypto_key.braintrust_gcs_cmek[0].id
    }
  }

  labels = local.common_labels

  lifecycle {
    ignore_changes = [
      name,
    ]
  }

  depends_on = [google_kms_crypto_key_iam_binding.gcp_project_gcs_cmek]
}

#------------------------------------------------------------------------------
# Google cloud storage (GCS) bucket - api - code-bundle
#------------------------------------------------------------------------------

resource "google_storage_bucket" "api_code_bundle" {
  name                        = "${var.deployment_name}-api-code-bundle-${random_id.gcs_suffix.hex}"
  location                    = var.gcs_location
  storage_class               = var.gcs_storage_class
  uniform_bucket_level_access = var.gcs_uniform_bucket_level_access
  force_destroy               = var.gcs_force_destroy

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
    for_each = var.gcs_kms_cmek_name != null ? ["encryption"] : []

    content {
      default_kms_key_name = data.google_kms_crypto_key.braintrust_gcs_cmek[0].id
    }
  }

  labels = local.common_labels

  lifecycle {
    ignore_changes = [
      name,
    ]
  }

  depends_on = [google_kms_crypto_key_iam_binding.gcp_project_gcs_cmek]
}

#------------------------------------------------------------------------------
# Google cloud storage (GCS) bucket - api - lambda response
#------------------------------------------------------------------------------

resource "google_storage_bucket" "lambda_response" {
  name                        = "${var.deployment_name}-lambda-response-${random_id.gcs_suffix.hex}"
  location                    = var.gcs_location
  storage_class               = var.gcs_storage_class
  uniform_bucket_level_access = var.gcs_uniform_bucket_level_access
  force_destroy               = var.gcs_force_destroy

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
    for_each = var.gcs_kms_cmek_name != null ? ["encryption"] : []

    content {
      default_kms_key_name = data.google_kms_crypto_key.braintrust_gcs_cmek[0].id
    }
  }

  labels = local.common_labels

  lifecycle {
    ignore_changes = [
      name,
    ]
  }

  depends_on = [google_kms_crypto_key_iam_binding.gcp_project_gcs_cmek]
}


#------------------------------------------------------------------------------
# KMS Google cloud storage (GCS) customer managed encryption key (CMEK)
#------------------------------------------------------------------------------
data "google_kms_key_ring" "braintrust_gcs_cmek" {
  count = var.gcs_kms_keyring_name != null ? 1 : 0

  name     = var.gcs_kms_keyring_name
  location = lower(var.gcs_location)
}

data "google_kms_crypto_key" "braintrust_gcs_cmek" {
  count = var.gcs_kms_cmek_name != null ? 1 : 0

  name     = var.gcs_kms_cmek_name
  key_ring = data.google_kms_key_ring.braintrust_gcs_cmek[0].id
}

#------------------------------------------------------------------------------
# GCS KMS CMEK
#------------------------------------------------------------------------------
locals {
  gcs_service_account_email = "service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_binding" "gcp_project_gcs_cmek" {
  count = var.gcs_kms_cmek_name != null ? 1 : 0

  crypto_key_id = data.google_kms_crypto_key.braintrust_gcs_cmek[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${local.gcs_service_account_email}",
  ]
}
