#------------------------------------------------------------------------------
# Storage buckets
#------------------------------------------------------------------------------

output "braintrust_response_bucket_name" {
  value = module.storage.response_bucket_name
}

output "braintrust_code_bundle_bucket_name" {
  value = module.storage.code_bundle_bucket_name
}

output "brainstore_bucket_name" {
  value = module.storage.brainstore_bucket_name
}

#------------------------------------------------------------------------------
# Service account
#------------------------------------------------------------------------------
output "braintrust_service_account" {
  value = var.deployment_type == "gke" ? module.gke-iam[0].braintrust_service_account : null
}

output "brainstore_service_account" {
  value = var.deployment_type == "gke" ? module.gke-iam[0].brainstore_service_account : null
}


#------------------------------------------------------------------------------
# Database
#------------------------------------------------------------------------------

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
  value = module.database.postgres_password
}

#------------------------------------------------------------------------------
# Redis
#------------------------------------------------------------------------------

output "redis_instance_port" {
  value = module.redis.redis_instance_port
}

output "redis_instance_host" {
  value = module.redis.redis_instance_host
}

output "redis_server_ca_certs" {
  value = module.redis.redis_server_ca_certs
}

output "api_url" {
  value = var.deployment_type == "cloud-run" ? module.api-cloud-run[0].api_url : null
}