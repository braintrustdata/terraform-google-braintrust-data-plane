resource "random_id" "sandbox_filesystems" {
  count       = local.isolated_workers == null ? 0 : 1
  byte_length = 4
}

resource "google_storage_bucket" "sandbox_filesystems" {
  count = local.isolated_workers == null ? 0 : 1

  name                        = "${local.isolated_cluster_prefix}-sandbox-filesystems-${random_id.sandbox_filesystems[0].hex}"
  location                    = data.google_client_config.current.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  deletion_policy             = "ABANDON"
  labels                      = merge(var.custom_labels, { braintrustdeploymentname = var.deployment_name })

  versioning {
    enabled = false
  }

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  encryption {
    default_kms_key_name = module.kms.kms_key_id
  }

  depends_on = [module.storage]
}

resource "google_storage_bucket_iam_member" "sandbox_filesystems_worker" {
  count = local.isolated_workers == null ? 0 : 1

  bucket = google_storage_bucket.sandbox_filesystems[0].name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${module.gke_isolated_workers_cluster[0].gke_node_service_account_email}"
}
