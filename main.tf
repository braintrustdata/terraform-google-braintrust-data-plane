locals {
  isolated_cluster_prefix = length(var.deployment_name) <= 19 ? replace(var.deployment_name, "_", "-") : "${substr(replace(var.deployment_name, "_", "-"), 0, 12)}-${substr(sha256(var.deployment_name), 0, 6)}"
  isolated_cluster_name   = "${local.isolated_cluster_prefix}-gke-isolated-workers"

  isolated_workers_name        = "${substr(replace(var.deployment_name, "_", "-"), 0, 14)}-${substr(sha256(var.deployment_name), 0, 6)}-isolated-workers"
  isolated_services_account_id = "${substr(replace(var.deployment_name, "_", "-"), 0, 13)}-${substr(sha256(var.deployment_name), 0, 6)}-iw-svc"
  isolated_workers_account_id  = "${substr(replace(var.deployment_name, "_", "-"), 0, 13)}-${substr(sha256(var.deployment_name), 0, 6)}-iw-nodes"

  isolated_allocations = var.gke_isolated_workers == null ? [] : try(cidrsubnets(var.gke_isolated_workers.network_cidr, 2, 8, 6, 12), [])
  isolated_network_config = var.gke_isolated_workers == null ? null : merge(var.gke_isolated_workers, {
    node_cidr          = var.gke_isolated_workers.existing_subnet_self_link != null ? var.gke_isolated_workers.node_cidr : try(coalesce(var.gke_isolated_workers.node_cidr, try(local.isolated_allocations[1], null)), null)
    pod_cidr           = try(coalesce(var.gke_isolated_workers.pod_cidr, try(local.isolated_allocations[0], null)), null)
    service_cidr       = try(coalesce(var.gke_isolated_workers.service_cidr, try(local.isolated_allocations[2], null)), null)
    control_plane_cidr = try(coalesce(var.gke_isolated_workers.control_plane_cidr, try(local.isolated_allocations[3], null)), null)
    discovery = var.gke_isolated_workers.discovery == null ? null : merge(var.gke_isolated_workers.discovery, {
      runtime_source_ranges = var.gke_isolated_workers.discovery.runtime_source_ranges != null ? var.gke_isolated_workers.discovery.runtime_source_ranges : toset(compact([
        var.create_vpc ? var.subnet_cidr_range : data.google_compute_subnetwork.primary_for_isolation[0].ip_cidr_range,
        var.deploy_gke_cluster ? module.gke-cluster[0].gke_pod_cidr : null,
      ]))
    })
  })
}

data "google_client_config" "current" {}

data "google_project" "current" {}

data "google_compute_subnetwork" "primary_for_isolation" {
  count     = var.gke_isolated_workers == null ? 0 : (!var.create_vpc ? 1 : 0)
  self_link = var.existing_subnet_self_link
}

module "vpc" {
  source = "./modules/vpc"
  count  = var.create_vpc ? 1 : 0

  deployment_name         = var.deployment_name
  vpc_name                = var.vpc_name
  subnet_cidr_range       = var.subnet_cidr_range
  subnet_flow_logs_config = var.subnet_flow_logs_config

  private_service_access_prefix_length = var.private_service_access_prefix_length
  private_service_access_address       = var.private_service_access_address
}

module "kms" {
  source = "./modules/kms"

  deployment_name  = var.deployment_name
  custom_labels    = var.custom_labels
  grant_gke_access = var.deploy_gke_cluster || var.gke_isolated_workers != null
  project_number   = data.google_project.current.number
}

module "database" {
  source = "./modules/database"

  deployment_name              = var.deployment_name
  custom_labels                = var.custom_labels
  postgres_network             = var.create_vpc ? module.vpc[0].network_self_link : var.existing_network_self_link
  postgres_kms_cmek_id         = module.kms.kms_key_id
  postgres_version             = var.postgres_version
  postgres_availability_type   = var.postgres_availability_type
  postgres_machine_type        = var.postgres_machine_type
  postgres_disk_size           = var.postgres_disk_size
  postgres_enable_seqscan      = var.postgres_enable_seqscan
  postgres_backup_start_time   = var.postgres_backup_start_time
  postgres_maintenance_window  = var.postgres_maintenance_window
  postgres_deletion_protection = var.postgres_deletion_protection

  depends_on = [module.vpc]
}

module "redis" {
  source = "./modules/redis"

  deployment_name      = var.deployment_name
  custom_labels        = var.custom_labels
  redis_network        = var.create_vpc ? module.vpc[0].network_self_link : var.existing_network_self_link
  redis_kms_cmek_id    = module.kms.kms_key_id
  redis_version        = var.redis_version
  redis_memory_size_gb = var.redis_memory_size_gb

  depends_on = [module.vpc]
}

module "storage" {
  source = "./modules/storage"

  deployment_name                       = var.deployment_name
  custom_labels                         = var.custom_labels
  gcs_kms_cmek_id                       = module.kms.kms_key_id
  gcs_additional_allowed_origins        = var.gcs_additional_allowed_origins
  gcs_bucket_retention_days             = var.gcs_bucket_retention_days
  gcs_versioning_enabled                = var.gcs_versioning_enabled
  gcs_storage_class                     = var.gcs_storage_class
  gcs_uniform_bucket_level_access       = var.gcs_uniform_bucket_level_access
  gcs_force_destroy                     = var.gcs_force_destroy
  gcs_soft_delete_retention_days        = var.gcs_soft_delete_retention_days
  gcs_brainstore_logging_config         = var.gcs_brainstore_logging_config
  gcs_api_logging_config                = var.gcs_api_logging_config
  custom_gcs_brainstore_lifecycle_rules = var.custom_gcs_brainstore_lifecycle_rules
  custom_gcs_api_lifecycle_rules        = var.custom_gcs_api_lifecycle_rules
}

module "gke-cluster" {
  source = "./modules/gke-cluster"
  count  = var.deploy_gke_cluster ? 1 : 0

  project_id                         = data.google_client_config.current.project
  region                             = data.google_client_config.current.region
  deployment_name                    = var.deployment_name
  custom_labels                      = var.custom_labels
  gke_cluster_mode                   = var.gke_cluster_mode
  gke_network                        = var.create_vpc ? module.vpc[0].network_self_link : var.existing_network_self_link
  gke_subnetwork                     = var.create_vpc ? module.vpc[0].subnet_self_link : var.existing_subnet_self_link
  gke_control_plane_cidr             = var.gke_control_plane_cidr
  gke_pods_ipv4_cidr_block           = var.gke_pods_ipv4_cidr_block
  gke_pods_secondary_range_name      = var.gke_pods_secondary_range_name
  gke_services_ipv4_cidr_block       = var.gke_services_ipv4_cidr_block
  gke_services_secondary_range_name  = var.gke_services_secondary_range_name
  gke_control_plane_authorized_cidrs = var.gke_control_plane_authorized_cidrs
  gke_enable_master_global_access    = var.gke_enable_master_global_access
  gke_cluster_is_private             = var.gke_cluster_is_private
  gke_release_channel                = var.gke_release_channel
  gke_enable_private_endpoint        = var.gke_enable_private_endpoint
  gke_deletion_protection            = var.gke_deletion_protection
  gke_kms_cmek_id                    = module.kms.gke_kms_key_id
  gke_maintenance_window             = var.gke_maintenance_window
}

module "gke-standard-node-pool" {
  source   = "./modules/gke-node-pool"
  for_each = var.deploy_gke_cluster && var.gke_cluster_mode == "standard" ? var.gke_standard_node_pools : {}

  deployment_name             = var.deployment_name
  custom_labels               = var.custom_labels
  name                        = each.key
  project_id                  = data.google_project.current.project_id
  location                    = module.gke-cluster[0].gke_cluster_location
  cluster_id                  = module.gke-cluster[0].gke_cluster_id
  service_account_email       = module.gke-cluster[0].gke_node_service_account_email
  boot_disk_kms_key           = module.kms.kms_key_id
  machine_type                = each.value.machine_type
  image_type                  = each.value.image_type
  disk_type                   = each.value.disk_type
  disk_size_gb                = each.value.disk_size_gb
  spot                        = each.value.spot
  total_min_node_count        = each.value.total_min_node_count
  total_max_node_count        = each.value.total_max_node_count
  location_policy             = each.value.location_policy
  node_locations              = each.value.node_locations
  cluster_node_locations      = module.gke-cluster[0].gke_node_locations
  labels                      = each.value.labels
  taints                      = each.value.taints
  auto_repair                 = each.value.auto_repair
  respect_pdb_on_delete       = each.value.respect_pdb_on_delete
  max_surge                   = each.value.max_surge
  max_unavailable             = each.value.max_unavailable
  enable_secure_boot          = each.value.enable_secure_boot
  enable_integrity_monitoring = each.value.enable_integrity_monitoring
}

module "gke-iam" {
  source = "./modules/gke-iam"

  deployment_name                  = var.deployment_name
  braintrust_kube_namespace        = var.braintrust_kube_namespace
  braintrust_kube_svc_account      = var.braintrust_kube_svc_account
  brainstore_kube_svc_account      = var.brainstore_kube_svc_account
  braintrust_api_bucket_id         = module.storage.api_bucket_name
  brainstore_gcs_bucket_id         = module.storage.brainstore_bucket_name
  braintrust_hmac_key_enabled      = var.braintrust_hmac_key_enabled
  brainstore_impersonation_targets = var.brainstore_impersonation_targets
  workload_identity_pool           = var.deploy_gke_cluster ? module.gke-cluster[0].workload_identity_pool : "${data.google_project.current.project_id}.svc.id.goog"
}

module "gke_isolated_workers_network" {
  source = "./modules/gke-isolated-workers-network"
  count  = var.gke_isolated_workers == null ? 0 : 1

  deployment_name = var.deployment_name
  network         = var.create_vpc ? module.vpc[0].network_self_link : var.existing_network_self_link
  primary_subnet  = var.create_vpc ? module.vpc[0].subnet_self_link : var.existing_subnet_self_link
  config          = local.isolated_network_config
  custom_labels   = var.custom_labels
  primary_cidrs = compact([
    var.create_vpc ? var.subnet_cidr_range : data.google_compute_subnetwork.primary_for_isolation[0].ip_cidr_range,
    var.gke_control_plane_cidr,
    var.deploy_gke_cluster ? module.gke-cluster[0].gke_pod_cidr : var.gke_pods_ipv4_cidr_block,
    var.gke_services_ipv4_cidr_block,
    var.private_service_access_address == null ? null : "${var.private_service_access_address}/${var.private_service_access_prefix_length}",
  ])
}

module "gke_isolated_workers_cluster" {
  source = "./modules/gke-cluster"
  count  = var.gke_isolated_workers == null ? 0 : 1

  project_id                           = data.google_client_config.current.project
  region                               = data.google_client_config.current.region
  deployment_name                      = var.deployment_name
  custom_labels                        = var.custom_labels
  gke_cluster_name                     = local.isolated_cluster_name
  gke_cluster_mode                     = "standard"
  gke_network                          = module.gke_isolated_workers_network[0].network_self_link
  gke_subnetwork                       = module.gke_isolated_workers_network[0].isolated_subnet_self_link
  gke_cluster_is_private               = true
  gke_enable_private_endpoint          = false
  gke_dns_endpoint_enabled             = false
  gke_private_endpoint_enforcement     = false
  gke_control_plane_cidr               = local.isolated_network_config.control_plane_cidr
  gke_pods_ipv4_cidr_block             = local.isolated_network_config.pod_cidr
  gke_services_ipv4_cidr_block         = local.isolated_network_config.service_cidr
  gke_control_plane_authorized_cidrs   = var.gke_isolated_workers.authorized_cidrs == null ? null : distinct(concat([module.gke_isolated_workers_network[0].node_cidr, local.isolated_network_config.pod_cidr], var.gke_isolated_workers.authorized_cidrs))
  gke_enable_master_global_access      = var.gke_isolated_workers.master_global_access
  gke_deletion_protection              = var.gke_isolated_workers.deletion_protection
  gke_release_channel                  = var.gke_isolated_workers.release_channel
  gke_node_service_account_id          = local.isolated_workers_account_id
  gke_services_node_service_account_id = local.isolated_services_account_id
  gke_node_project_storage_access      = false
  gke_node_network_tags                = [local.isolated_workers_name]
  gke_kms_cmek_id                      = module.kms.gke_kms_key_id
  gke_maintenance_window               = { day = 1, start_time = var.gke_isolated_workers.maintenance_start_time }
}

module "gke_isolated_services_pool" {
  source = "./modules/gke-node-pool"
  count  = var.gke_isolated_workers == null ? 0 : 1

  deployment_name        = var.deployment_name
  custom_labels          = var.custom_labels
  name                   = "services"
  project_id             = data.google_client_config.current.project
  location               = module.gke_isolated_workers_cluster[0].gke_cluster_location
  cluster_id             = module.gke_isolated_workers_cluster[0].gke_cluster_id
  service_account_email  = module.gke_isolated_workers_cluster[0].gke_services_node_service_account_email
  boot_disk_kms_key      = module.kms.kms_key_id
  machine_type           = var.gke_isolated_workers.services_pool.machine_type
  image_type             = "COS_CONTAINERD"
  disk_type              = var.gke_isolated_workers.services_pool.disk_type
  disk_size_gb           = var.gke_isolated_workers.services_pool.boot_disk_size_gb
  total_min_node_count   = var.gke_isolated_workers.services_pool.total_min_node_count
  total_max_node_count   = var.gke_isolated_workers.services_pool.total_max_node_count
  node_locations         = var.gke_isolated_workers.services_pool.node_locations != null ? var.gke_isolated_workers.services_pool.node_locations : slice(sort(tolist(module.gke_isolated_workers_cluster[0].gke_node_locations)), 0, min(2, length(module.gke_isolated_workers_cluster[0].gke_node_locations)))
  cluster_node_locations = module.gke_isolated_workers_cluster[0].gke_node_locations
  network_tags           = [local.isolated_workers_name]
}

module "gke_isolated_workers_pool" {
  source = "./modules/gke-node-pool"
  count  = var.gke_isolated_workers == null ? 0 : 1

  deployment_name              = var.deployment_name
  custom_labels                = var.custom_labels
  name                         = "isolated-workers"
  project_id                   = data.google_project.current.project_id
  location                     = module.gke_isolated_workers_cluster[0].gke_cluster_location
  cluster_id                   = module.gke_isolated_workers_cluster[0].gke_cluster_id
  service_account_email        = module.gke_isolated_workers_cluster[0].gke_node_service_account_email
  boot_disk_kms_key            = module.kms.kms_key_id
  machine_type                 = var.gke_isolated_workers.machine_type
  image_type                   = "UBUNTU_CONTAINERD"
  disk_type                    = "hyperdisk-balanced"
  disk_size_gb                 = var.gke_isolated_workers.boot_disk_size_gb
  enable_nested_virtualization = true
  raw_local_ssd                = true
  network_tags                 = [local.isolated_workers_name, "${local.isolated_workers_name}-workers"]
  labels                       = { "nested-virtualization" = "enabled" }
  taints = [{
    key    = "braintrust/isolated-worker"
    value  = "true"
    effect = "NO_SCHEDULE"
  }]
  total_min_node_count   = var.gke_isolated_workers.total_min_node_count
  total_max_node_count   = var.gke_isolated_workers.total_max_node_count
  node_locations         = var.gke_isolated_workers.node_locations
  cluster_node_locations = module.gke_isolated_workers_cluster[0].gke_node_locations
}
