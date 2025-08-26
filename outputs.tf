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
  value = module.database.postgres_password
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
  value = module.redis.redis_auth_string
}