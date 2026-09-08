#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
locals {
  common_labels = merge(var.custom_labels, {
    braintrustdeploymentname = var.deployment_name
  })
  cluster_name = coalesce(var.gke_cluster_name, "${var.deployment_name}-gke-${var.gke_cluster_mode}")
}

data "google_client_config" "current" {}

data "google_project" "current" {}

#----------------------------------------------------------------------------------------------
# GKE cluster
#----------------------------------------------------------------------------------------------
resource "google_container_cluster" "braintrust" {
  name    = local.cluster_name
  project = data.google_project.current.project_id

  enable_autopilot         = var.gke_cluster_mode == "autopilot" ? true : null
  remove_default_node_pool = var.gke_cluster_mode == "standard" ? true : null
  initial_node_count       = var.gke_cluster_mode == "standard" ? 1 : null

  dynamic "node_config" {
    for_each = var.gke_cluster_mode == "standard" ? [1] : []

    content {
      service_account = google_service_account.gke.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
      ]
    }
  }

  release_channel {
    channel = var.gke_release_channel
  }

  # Location and network configuration
  location   = data.google_client_config.current.region
  network    = var.gke_network
  subnetwork = var.gke_subnetwork

  deletion_protection = var.gke_deletion_protection

  resource_labels = local.common_labels

  dynamic "ip_allocation_policy" {
    for_each = (
      var.gke_pods_ipv4_cidr_block != null ||
      var.gke_pods_secondary_range_name != null ||
      var.gke_services_ipv4_cidr_block != null ||
      var.gke_services_secondary_range_name != null
    ) ? [1] : []

    content {
      cluster_ipv4_cidr_block       = var.gke_pods_ipv4_cidr_block
      cluster_secondary_range_name  = var.gke_pods_secondary_range_name
      services_ipv4_cidr_block      = var.gke_services_ipv4_cidr_block
      services_secondary_range_name = var.gke_services_secondary_range_name
    }
  }

  # Private cluster configuration
  dynamic "private_cluster_config" {
    for_each = var.gke_cluster_is_private ? [1] : []

    content {
      enable_private_nodes    = true
      enable_private_endpoint = var.gke_enable_private_endpoint
      master_ipv4_cidr_block  = var.gke_control_plane_cidr

      master_global_access_config {
        enabled = var.gke_enable_master_global_access
      }
    }
  }

  # Master authorized networks
  dynamic "master_authorized_networks_config" {
    for_each = var.gke_control_plane_authorized_cidrs == null ? [] : [1]

    content {
      gcp_public_cidrs_access_enabled = false

      dynamic "cidr_blocks" {
        for_each = var.gke_control_plane_authorized_cidrs

        content {
          cidr_block = cidr_blocks.value
        }
      }
    }
  }

  enable_l4_ilb_subsetting = var.gke_l4_ilb_subsetting_enabled

  addons_config {
    http_load_balancing {
      disabled = var.gke_http_load_balancing_disabled
    }
  }

  workload_identity_config {
    workload_pool = "${data.google_project.current.project_id}.svc.id.goog"
  }

  logging_service = "logging.googleapis.com/kubernetes"

  database_encryption {
    state    = "ENCRYPTED"
    key_name = var.gke_kms_cmek_id
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = var.gke_maintenance_window.start_time
    }
  }

  dynamic "cluster_autoscaling" {
    for_each = var.gke_cluster_mode == "autopilot" ? [1] : []

    content {
      auto_provisioning_defaults {
        service_account   = google_service_account.gke.email
        boot_disk_kms_key = var.gke_kms_cmek_id
      }
    }
  }

  depends_on = [
    google_project_iam_member.gke_default_node_sa,
    google_kms_crypto_key_iam_member.gke_cluster_cmek,
    google_kms_crypto_key_iam_member.gke_compute_cmek
  ]
}

#----------------------------------------------------------------------------------------------
# GKE cluster service account
#----------------------------------------------------------------------------------------------
resource "google_service_account" "gke" {
  account_id   = "${var.deployment_name}-gke-cluster"
  display_name = "${var.deployment_name}-gke-cluster"
  description  = "Service account for GKE cluster."
}

resource "google_project_iam_member" "gke_default_node_sa" {
  project = data.google_project.current.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_log_writer" {
  project = data.google_project.current.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_metric_writer" {
  project = data.google_project.current.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_stackdriver_writer" {
  project = data.google_project.current.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_object_viewer" {
  project = data.google_project.current.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_artifact_reader" {
  project = data.google_project.current.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

#----------------------------------------------------------------------------------------------
# GKE KMS CMEK
#----------------------------------------------------------------------------------------------
locals {
  # Container Engine Robot service account for cluster-level encryption
  gke_cluster_service_account_email = "service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
  # Compute Engine service account for node boot disk encryption
  gke_compute_service_account_email = "service-${data.google_project.current.number}@compute-system.iam.gserviceaccount.com"
}

# KMS permissions for GKE cluster (etcd/secrets encryption)
resource "google_kms_crypto_key_iam_member" "gke_cluster_cmek" {
  crypto_key_id = var.gke_kms_cmek_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${local.gke_cluster_service_account_email}"
}

# KMS permissions for GKE node boot disks
resource "google_kms_crypto_key_iam_member" "gke_compute_cmek" {
  crypto_key_id = var.gke_kms_cmek_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${local.gke_compute_service_account_email}"
}
