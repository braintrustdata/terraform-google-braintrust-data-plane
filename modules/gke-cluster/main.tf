#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
locals {
  common_labels = {
    braintrustdeploymentname = var.deployment_name
  }
  available_zones = [
    for zone_name, machine_types in data.google_compute_machine_types.gke_node_type :
    zone_name if length(machine_types.machine_types) > 0
  ]
  requires_explicit_ssd = can(regex(
    "^(n1-|n2-|n2d-|c2-|c2d-|a2-highgpu-|a2-megagpu-|g2-|m1-|m3-)",
    var.gke_node_type
  ))
  
  # Lookup table for machine types with built-in local SSD counts
  gke_local_ssd_counts = {
    # C3 Series
    "c3-standard-4-lssd"   = 1
    "c3-standard-8-lssd"   = 2
    "c3-standard-22-lssd"  = 6
    "c3-standard-44-lssd"  = 12
    "c3-standard-88-lssd"  = 24
    "c3-standard-176-lssd" = 32
    
    # C4 Series
    "c4-standard-4-lssd"   = 1
    "c4-standard-8-lssd"   = 1
    "c4-standard-16-lssd"  = 2
    "c4-standard-32-lssd"  = 4
    "c4-standard-48-lssd"  = 8
    "c4-standard-96-lssd"  = 16
    "c4-standard-144-lssd" = 24
    "c4-standard-192-lssd" = 32
    "c4-standard-288-lssd" = 48
    
    # C4A Series (Axion Processor)
    "c4a-standard-4-lssd"  = 1
    "c4a-standard-8-lssd"  = 2
    "c4a-standard-16-lssd" = 4
    "c4a-standard-24-lssd" = 6
    "c4a-standard-32-lssd" = 8
    "c4a-standard-48-lssd" = 12
    "c4a-standard-72-lssd" = 16
    
    # C4D Series (AMD EPYC Turin)
    "c4d-standard-8-lssd"   = 1
    "c4d-standard-16-lssd"  = 2
    "c4d-standard-32-lssd"  = 4
    "c4d-standard-48-lssd"  = 6
    "c4d-standard-96-lssd"  = 12
    "c4d-standard-144-lssd" = 18
    "c4d-standard-192-lssd" = 24
    "c4d-standard-288-lssd" = 32
    "c4d-standard-384-lssd" = 32
    
    # A2 Series (GPU Optimized)
    "a2-highgpu-1g-lssd"  = 1
    "a2-highgpu-2g-lssd"  = 2
    "a2-highgpu-4g-lssd"  = 4
    "a2-highgpu-8g-lssd"  = 8
    "a2-megagpu-16g-lssd" = 8
    
    # A3 Series (Latest GPU Optimized)
    "a3-highgpu-2g-lssd"  = 2
    "a3-highgpu-4g-lssd"  = 4
    "a3-highgpu-8g-lssd"  = 8
    "a3-megagpu-8g-lssd"  = 16
    
    # A4 Series (GPU Optimized - Fixed 32 disks)
    "a4-highgpu-4g"   = 32
    "a4-highgpu-8g"   = 32
    "a4-highgpu-16g"  = 32
    "a4-highgpu-32g"  = 32
    "a4-highgpu-48g"  = 32
    "a4-highgpu-64g"  = 32
    "a4-highgpu-96g"  = 32
    "a4-highgpu-128g" = 32
    
    # A4X Series (GPU Optimized - Fixed 4 disks)
    "a4x-standard-4"   = 4
    "a4x-standard-8"   = 4
    "a4x-standard-16"  = 4
    "a4x-standard-32"  = 4
    "a4x-standard-48"  = 4
    "a4x-standard-64"  = 4
    "a4x-standard-96"  = 4
    "a4x-standard-128" = 4
    
    # Z3 Series (Storage Optimized - 3TB Titanium SSD per disk)
    "z3-standard-4-standardlssd"    = 1
    "z3-standard-8-standardlssd"    = 2
    "z3-standard-16-standardlssd"   = 4
    "z3-standard-32-standardlssd"   = 8
    "z3-highmem-22-standardlssd"    = 6
    "z3-highmem-44-standardlssd"    = 12
    "z3-highmem-88-standardlssd"    = 24
    "z3-standard-4-highlssd"        = 1
    "z3-standard-8-highlssd"        = 2
    "z3-standard-16-highlssd"       = 4
    "z3-standard-32-highlssd"       = 8
    "z3-highmem-22-highlssd"        = 6
    "z3-highmem-44-highlssd"        = 12
    "z3-highmem-88-highlssd"        = 24
  }
  
  # Automatically determine local SSD count based on machine type
  local_ssd_count = lookup(local.gke_local_ssd_counts, var.gke_node_type, 0)
}

data "google_client_config" "current" {}

data "google_project" "current" {}

data "google_compute_zones" "up" {
  project = data.google_project.current.project_id
  status  = "UP"
}

# Data source to get machine types available in each zone
data "google_compute_machine_types" "gke_node_type" {
  for_each = toset(data.google_compute_zones.up.names)
  zone     = each.value
  filter   = "name = ${var.gke_node_type}"
}

#----------------------------------------------------------------------------------------------
# GKE cluster
#----------------------------------------------------------------------------------------------

resource "google_container_cluster" "braintrust" {
  name    = "${var.deployment_name}-gke"
  project = data.google_project.current.project_id

  release_channel {
    channel = var.gke_release_channel
  }

  node_locations = local.available_zones

  remove_default_node_pool = var.gke_remove_default_node_pool
  initial_node_count       = 1
  deletion_protection      = var.gke_deletion_protection

  network    = var.gke_network
  subnetwork = var.gke_subnetwork

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

  depends_on = [
    google_kms_crypto_key_iam_member.gke_cluster_cmek,
    google_kms_crypto_key_iam_member.gke_compute_cmek
  ]
}

#----------------------------------------------------------------------------------------------
# GKE node pool
#----------------------------------------------------------------------------------------------
resource "google_container_node_pool" "braintrust" {
  name       = "${var.deployment_name}-gke-node-pool"
  cluster    = google_container_cluster.braintrust.id
  node_count = var.gke_node_count

  node_config {
    preemptible       = false
    machine_type      = var.gke_node_type
    service_account   = google_service_account.gke.email
    boot_disk_kms_key = var.gke_kms_cmek_id

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    ephemeral_storage_local_ssd_config {
      local_ssd_count = local.local_ssd_count
    }
  }

  upgrade_settings {
    max_surge       = 2
    max_unavailable = 0
  }
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
