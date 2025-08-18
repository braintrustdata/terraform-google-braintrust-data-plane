locals {
  common_labels = {
    braintrustdeploymentname = var.deployment_name
  }
  postgres_username = "postgres"
  postgres_password = random_password.postgres_password.result
}

data "google_client_config" "current" {}

#----------------------------------------------------------------------------------------------
# Google secret manager - Postgres password
#----------------------------------------------------------------------------------------------
resource "random_password" "postgres_password" {
  length           = 24
  special          = true
  override_special = "-_."
}

resource "google_secret_manager_secret" "postgres_password" {
  secret_id = "${var.deployment_name}-postgres-password"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "postgres_password" {
  secret = google_secret_manager_secret.postgres_password.id
  secret_data = jsonencode({
    username = local.postgres_username
    password = local.postgres_password
  })

  lifecycle {
    ignore_changes = [secret_data]
  }
}

#----------------------------------------------------------------------------------------------
# Cloud SQL for PostgreSQL
#----------------------------------------------------------------------------------------------
resource "random_id" "postgres_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "braintrust" {
  name                = "${var.deployment_name}-${random_id.postgres_suffix.hex}"
  database_version    = var.postgres_version
  encryption_key_name = var.postgres_kms_cmek_id
  deletion_protection = var.postgres_deletion_protection

  settings {
    availability_type = var.postgres_availability_type
    tier              = var.postgres_machine_type
    disk_type         = "PD_SSD"
    disk_size         = var.postgres_disk_size
    disk_autoresize   = true

    # database_flags {
    #   name  = "max_client_connections"
    #   value = "1000"
    # } # TODO: check on instance type to find max connections supported

    database_flags {
      name  = "cloudsql.enable_pg_cron"
      value = "on"
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.postgres_network
      ssl_mode        = var.postgres_ssl_mode
    }

    backup_configuration {
      enabled    = true
      start_time = var.postgres_backup_start_time
    }

    maintenance_window {
      day          = var.postgres_maintenance_window.day
      hour         = var.postgres_maintenance_window.hour
      update_track = var.postgres_maintenance_window.update_track
    }

    insights_config {
      query_insights_enabled  = var.postgres_insights_config.query_insights_enabled
      query_plans_per_minute  = var.postgres_insights_config.query_plans_per_minute
      query_string_length     = var.postgres_insights_config.query_string_length
      record_application_tags = var.postgres_insights_config.record_application_tags
      record_client_address   = var.postgres_insights_config.record_client_address
    }

    user_labels = local.common_labels
  }

  depends_on = [
    google_kms_crypto_key_iam_member.cloud_sql_sa_postgres_cmek
  ]
}

resource "google_sql_user" "braintrust" {
  name     = "postgres"
  instance = google_sql_database_instance.braintrust.name
  password = random_password.postgres_password.result
}

resource "google_sql_user" "braintrust_iam" {
  name     = "${var.deployment_name}-braintrust@${data.google_client_config.current.project}.iam"
  instance = google_sql_database_instance.braintrust.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

#----------------------------------------------------------------------------------------------
# Cloud SQL for PostgreSQL KMS CMEK
#----------------------------------------------------------------------------------------------
resource "google_project_service_identity" "cloud_sql_sa" {
  provider = google-beta

  service = "sqladmin.googleapis.com"
}

resource "google_kms_crypto_key_iam_member" "cloud_sql_sa_postgres_cmek" {

  crypto_key_id = var.postgres_kms_cmek_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  member = "serviceAccount:${google_project_service_identity.cloud_sql_sa.email}"

}