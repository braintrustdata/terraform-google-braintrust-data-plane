module "vpc" {
  source = "./modules/vpc"
  count  = var.create_vpc ? 1 : 0

  deployment_name   = var.deployment_name
  vpc_name          = var.vpc_name
  subnet_cidr_range = var.subnet_cidr_range
}

module "kms" {
  source = "./modules/kms"

  deployment_name = var.deployment_name
}

module "database" {
  source = "./modules/database"

  deployment_name              = var.deployment_name
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
}

module "redis" {
  source = "./modules/redis"

  deployment_name      = var.deployment_name
  redis_network        = var.create_vpc ? module.vpc[0].network_self_link : var.existing_network_self_link
  redis_kms_cmek_id    = module.kms.kms_key_id
  redis_version        = var.redis_version
  redis_memory_size_gb = var.redis_memory_size_gb
}

module "storage" {
  source = "./modules/storage"

  deployment_name                 = var.deployment_name
  gcs_kms_cmek_id                 = module.kms.kms_key_id
  gcs_additional_allowed_origins  = var.gcs_additional_allowed_origins
  gcs_bucket_retention_days       = var.gcs_bucket_retention_days
  gcs_versioning_enabled          = var.gcs_versioning_enabled
  gcs_storage_class               = var.gcs_storage_class
  gcs_uniform_bucket_level_access = var.gcs_uniform_bucket_level_access
  gcs_force_destroy               = var.gcs_force_destroy
}

module "gke-cluster" {
  source = "./modules/gke-cluster"
  count  = var.deploy_gke_cluster ? 1 : 0

  deployment_name                    = var.deployment_name
  gke_network                        = var.create_vpc ? module.vpc[0].network_self_link : var.existing_network_self_link
  gke_subnetwork                     = var.create_vpc ? module.vpc[0].subnet_self_link : var.existing_subnet_self_link
  gke_control_plane_cidr             = var.gke_control_plane_cidr
  gke_control_plane_authorized_cidrs = var.gke_control_plane_authorized_cidrs
  gke_enable_master_global_access    = var.gke_enable_master_global_access
  gke_cluster_is_private             = var.gke_cluster_is_private
  gke_release_channel                = var.gke_release_channel
  gke_enable_private_endpoint        = var.gke_enable_private_endpoint
  gke_deletion_protection            = var.gke_deletion_protection
  gke_kms_cmek_id                    = module.kms.kms_key_id
  gke_maintenance_window             = var.gke_maintenance_window
}

module "gke-iam" {
  source = "./modules/gke-iam"

  deployment_name             = var.deployment_name
  braintrust_kube_namespace   = var.braintrust_kube_namespace
  braintrust_kube_svc_account = var.braintrust_kube_svc_account
  brainstore_kube_svc_account = var.brainstore_kube_svc_account
  braintrust_api_bucket_id    = module.storage.api_bucket_name
  brainstore_gcs_bucket_id    = module.storage.brainstore_bucket_name
  braintrust_hmac_key_enabled = var.braintrust_hmac_key_enabled
}
