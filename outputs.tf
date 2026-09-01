#----------------------------------------------------------------------------------------------
# App-root contract
#----------------------------------------------------------------------------------------------

output "project_id" {
  value       = data.google_project.current.project_id
  description = "GCP project where the data-plane substrate is deployed."
}

output "region" {
  value       = data.google_client_config.current.region
  description = "GCP region where the data-plane substrate is deployed."
}

output "deployment_name" {
  value       = var.deployment_name
  description = "Stable deployment name used to prefix resources."
}

output "labels" {
  value = merge(var.custom_labels, {
    braintrustdeploymentname = var.deployment_name
  })
  description = "Labels for app-layer resources."
}

output "namespace" {
  value       = var.braintrust_kube_namespace
  description = "Kubernetes namespace where Braintrust workloads are deployed."
}

#----------------------------------------------------------------------------------------------
# Storage buckets
#----------------------------------------------------------------------------------------------

output "braintrust_api_bucket_name" {
  value = module.storage.api_bucket_name
}

output "brainstore_bucket_name" {
  value = module.storage.brainstore_bucket_name
}

#----------------------------------------------------------------------------------------------
# Service account
#----------------------------------------------------------------------------------------------
output "braintrust_service_account" {
  value = module.gke-iam.braintrust_service_account
}

output "brainstore_service_account" {
  value = module.gke-iam.brainstore_service_account
}

output "braintrust_hmac_access_id" {
  value     = module.gke-iam.braintrust_hmac_access_id
  sensitive = true
}

output "braintrust_hmac_secret" {
  value     = module.gke-iam.braintrust_hmac_secret
  sensitive = true
}

#----------------------------------------------------------------------------------------------
# Database
#----------------------------------------------------------------------------------------------

output "postgres_instance_name" {
  value = module.database.postgres_instance_name
}

output "postgres_instance_ip" {
  value = module.database.postgres_instance_ip
}

output "postgres_username" {
  value = module.database.postgres_username
}

output "postgres_password" {
  value     = module.database.postgres_password
  sensitive = true
}

output "pg_url" {
  value = format(
    "postgres://%s:%s@%s:5432/postgres?sslmode=require",
    module.database.postgres_username,
    module.database.postgres_password,
    module.database.postgres_instance_ip,
  )
  description = "Postgres URL consumed by the Braintrust app root."
  sensitive   = true
}

#----------------------------------------------------------------------------------------------
# GKE
#----------------------------------------------------------------------------------------------

output "gke_cluster_name" {
  value       = var.deploy_gke_cluster ? module.gke-cluster[0].gke_cluster_name : null
  description = "GKE cluster name. Null when deploy_gke_cluster is false."
}

output "gke_cluster_endpoint" {
  value       = var.deploy_gke_cluster ? module.gke-cluster[0].gke_cluster_endpoint : null
  description = "GKE cluster endpoint. Null when deploy_gke_cluster is false."
}

output "gke_cluster_master_version" {
  value       = var.deploy_gke_cluster ? module.gke-cluster[0].gke_cluster_master_version : null
  description = "GKE cluster master version. Null when deploy_gke_cluster is false."
}

output "gke_cluster_mode" {
  value       = var.deploy_gke_cluster ? var.gke_cluster_mode : null
  description = "GKE cluster mode. Null when deploy_gke_cluster is false."
}

output "gke_node_pool_names" {
  value = {
    for name, pool in module.gke-standard-node-pool : name => pool.name
  }
  description = "Standard GKE node pool names. The map is empty in Autopilot mode."
}

#----------------------------------------------------------------------------------------------
# Redis
#----------------------------------------------------------------------------------------------

output "redis_instance_port" {
  value = module.redis.redis_instance_port
}

output "redis_instance_host" {
  value = module.redis.redis_instance_host
}

output "redis_server_ca_certs" {
  value = module.redis.redis_server_ca_certs
}

output "redis_auth_string" {
  value     = module.redis.redis_auth_string
  sensitive = true
}

output "redis_url" {
  value = format(
    "redis://:%s@%s:%s",
    module.redis.redis_auth_string,
    module.redis.redis_instance_host,
    module.redis.redis_instance_port,
  )
  description = "Redis URL consumed by the Braintrust app root."
  sensitive   = true
}
