locals {
  common_resource_labels = merge(var.custom_labels, {
    braintrustdeploymentname = var.deployment_name
  })
  initial_node_count = ceil(var.total_min_node_count / length(coalesce(var.node_locations, var.cluster_node_locations)))

  node_labels = merge(var.labels, {
    "braintrust/node-pool" = var.name
  })
}

# Preserve the existing trigger state during the protection rollout.
resource "terraform_data" "lssd_machine_type" {
  triggers_replace = endswith(var.machine_type, "-lssd") ? var.machine_type : null
}

resource "terraform_data" "machine_type" {
  triggers_replace = var.enable_nested_virtualization || var.raw_local_ssd ? jsonencode([var.machine_type, var.enable_nested_virtualization, var.raw_local_ssd]) : var.machine_type
}

resource "google_container_node_pool" "this" {
  # Machine changes use replacement for both architecture and bundled SSD changes.
  name_prefix = "${substr(var.name, 0, 13)}-"
  project     = var.project_id
  location    = var.location
  cluster     = var.cluster_id

  node_locations     = var.node_locations
  initial_node_count = local.initial_node_count

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

  dynamic "node_drain_config" {
    for_each = var.respect_pdb_on_delete ? [true] : []

    content {
      respect_pdb_during_node_pool_deletion = true
    }
  }

  node_config {
    dynamic "advanced_machine_features" {
      for_each = var.enable_nested_virtualization ? [true] : []
      content {
        threads_per_core             = 2
        enable_nested_virtualization = true
      }
    }

    dynamic "local_nvme_ssd_block_config" {
      for_each = var.raw_local_ssd ? [true] : []
      content {
        # Zero is omitted from the API object. GKE derives the bundled count.
        local_ssd_count = 0
      }
    }

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
    tags              = var.network_tags

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

    replace_triggered_by = [
      terraform_data.lssd_machine_type,
      terraform_data.machine_type,
    ]

    ignore_changes = [
      # Autoscaler minimum changes must not replace an existing pool.
      initial_node_count,
      node_config[0].local_nvme_ssd_block_config[0].local_ssd_count,
      node_config[0].ephemeral_storage_local_ssd_config,
    ]
  }
}
