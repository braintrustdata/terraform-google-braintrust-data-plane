module "vpc" {
  source = "./modules/vpc"

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
  postgres_network             = module.vpc.network_self_link
  postgres_deletion_protection = var.postgres_deletion_protection
  postgres_kms_cmek_id         = module.kms.kms_key_id
}

module "redis" {
  source = "./modules/redis"

  deployment_name        = var.deployment_name
  redis_network          = module.vpc.network_self_link
  redis_kms_cmek_id      = module.kms.kms_key_id
}

module "storage" {
  source = "./modules/storage"

  deployment_name      = var.deployment_name
  gcs_location         = var.region
  gcs_force_destroy    = var.gcs_force_destroy
  gcs_kms_cmek_id      = module.kms.kms_key_id
}

module "brainstore-vm" {
  source = "./modules/brainstore-vm"

  count = var.enable_brainstore_vm ? 1 : 0

  deployment_name                    = var.deployment_name
  brainstore_network                 = module.vpc.network_self_link
  brainstore_subnet                  = module.vpc.subnet_self_link
  brainstore_gcs_bucket              = module.storage.brainstore_bucket_name
  redis_host                         = module.redis.redis_instance_ip
  database_host                      = module.database.postgres_instance_ip
  database_secret_name               = module.database.postgres_password_secret_name
  brainstore_license_key_secret_name = var.brainstore_license_key_secret_name
}


