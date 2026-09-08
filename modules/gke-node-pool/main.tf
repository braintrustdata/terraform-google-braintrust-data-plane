locals {
  common_resource_labels = merge(var.custom_labels, {
    braintrustdeploymentname = var.deployment_name
  })
  node_labels = merge(var.labels, {
    "braintrust/node-pool" = var.name
  })
}

resource "google_container_node_pool" "this" {
  name_prefix = "${substr(var.name, 0, 13)}-"
  project     = var.project_id
  location    = var.location
  cluster     = var.cluster_id

  node_locations = var.node_locations

  autoscaling {
    total_min_node_count = var.total_min_node_count
    total_max_node_count = var.total_max_node_count
    location_policy      = var.location_policy
  }

  management {
    auto_repair  = var.auto_repair
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = var.max_surge
    max_unavailable = var.max_unavailable
  }

  node_config {
    machine_type = var.machine_type
    image_type   = var.image_type
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb
    spot         = var.spot

    service_account = var.service_account_email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    boot_disk_kms_key = var.boot_disk_kms_key
    labels            = local.node_labels
    resource_labels   = local.common_resource_labels

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = var.enable_secure_boot
      enable_integrity_monitoring = var.enable_integrity_monitoring
    }

    taint_config {
      architecture_taint_behavior = "NONE"
    }

    dynamic "taint" {
      for_each = var.taints

      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }
  }

  lifecycle {
    create_before_destroy = true

    ignore_changes = [
      node_config[0].ephemeral_storage_local_ssd_config,
    ]
  }
}
