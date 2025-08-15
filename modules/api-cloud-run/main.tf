locals {
  common_labels = {
    braintrustdeploymentname = var.deployment_name
  }
  api_release_version = jsondecode(file("${path.module}/VERSIONS.json"))["api"]

  api_version = var.api_version_override == null ? local.api_release_version : var.api_version_override

}

data "google_client_config" "current" {}

data "google_project" "current" {}

resource "google_cloud_run_v2_service" "braintrust_api" {
  name                = "${var.deployment_name}-api"
  location            = var.region
  project             = data.google_project.current.project_id
  ingress             = var.enable_public_access ? "INGRESS_TRAFFIC_ALL" : "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = var.deletion_protection

  template {
    encryption_key        = var.kms_key_name
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"
    containers {
      # This should be set to a shared braintrust google artifact registry image and optional override, using my test GAR for now
      image = "us-central1-docker.pkg.dev/braintrust-sandbox/jeff-testing-us-central/braintrust-standalone-api:${local.api_version}"

      ports {
        container_port = 8000
      }

      env {
        name  = "BRAINTRUST_API_URL"
        value = "http://127.0.0.1:8000"
      }

      env {
        name  = "PG_URL"
        value = "postgresql://${var.database_username}:${var.database_password}@${var.database_host}:${var.database_port}/${var.database_name}?sslmode=require"
      }

      env {
        name  = "REDIS_URL"
        value = "redis://${var.redis_host}:${var.redis_port}"
      }

      env {
        name  = "ALLOW_CODE_FUNCTION_EXECUTION"
        value = "false"
      }

      env {
        name  = "ORG_NAME"
        value = var.org_name
      }

      env {
        name  = "STANDALONE_MODE"
        value = "true"
      }

      env {
        name  = "DISABLE_AUTH"
        value = "true"
      }

      env {
        name  = "BRAINSTORE_ENABLED"
        value = "true"
      }

      env {
        name  = "BRAINSTORE_ENABLE_HISTORICAL_FULL_BACKFILL"
        value = "true"
      }

      env {
        name  = "BRAINSTORE_BACKFILL_HISTORICAL_BATCH_SIZE"
        value = "40000"
      }

      env {
        name  = "BRAINSTORE_BACKFILL_NEW_OBJECTS"
        value = "true"
      }

      env {
        name  = "BRAINSTORE_URL"
        value = "http://${var.brainstore_reader_url}:${var.brainstore_reader_port}"
      }

      env {
        name  = "BRAINSTORE_WRITER_URL"
        value = "http://${var.brainstore_writer_url}:${var.brainstore_writer_port}"
      }

      env {
        name  = "BRAINSTORE_DEFAULT"
        value = "force"
      }

      env {
        name  = "INSERT_LOGS2"
        value = "true"
      }

      env {
        name  = "BRAINSTORE_INSERT_ROW_REFS"
        value = "true"
      }

      resources {
        limits = {
          cpu    = var.api_cpu_limit
          memory = var.api_memory_limit
        }
      }
    }

    service_account = google_service_account.api_sa.email

    max_instance_request_concurrency = var.api_container_concurrency
    timeout                          = "${var.api_timeout_seconds}s"

    scaling {
      max_instance_count = var.api_max_instances
      min_instance_count = var.api_min_instances
    }

    vpc_access {
      connector = var.vpc_access_connector
      egress    = "ALL_TRAFFIC"
    }

    labels = local.common_labels
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
}

resource "google_service_account" "api_sa" {
  account_id   = "${var.deployment_name}-api"
  display_name = "Braintrust API Service Account"
  project      = data.google_project.current.project_id
}

# Cloud Run service agent needs KMS permissions for encryption
resource "google_project_service_identity" "cloud_run_sa" {
  provider = google-beta
  project  = data.google_project.current.project_id
  service  = "run.googleapis.com"
}

resource "google_kms_crypto_key_iam_member" "cloud_run_sa_cmek" {
  crypto_key_id = var.kms_key_name
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.cloud_run_sa.email}"
}

resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = var.enable_public_access ? 1 : 0

  name     = google_cloud_run_v2_service.braintrust_api.name
  location = google_cloud_run_v2_service.braintrust_api.location
  project  = data.google_project.current.project_id
  role     = "roles/run.invoker"
  member   = "allUsers"
}


