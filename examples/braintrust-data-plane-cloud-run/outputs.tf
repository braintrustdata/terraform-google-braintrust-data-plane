output "braintrust_response_bucket_name" {
  value = module.braintrust.braintrust_response_bucket_name
}

output "braintrust_code_bundle_bucket_name" {
  value = module.braintrust.braintrust_code_bundle_bucket_name
}

output "brainstore_bucket_name" {
  value = module.braintrust.brainstore_bucket_name
}

output "braintrust_service_account" {
  value = module.braintrust.braintrust_service_account
}

output "brainstore_service_account" {
  value = module.braintrust.brainstore_service_account
}

output "postgres_instance_name" {
  value = module.braintrust.postgres_instance_name
}

output "postgres_instance_ip" {
  value = module.braintrust.postgres_instance_ip
}

output "postgres_username" {
  value = module.braintrust.postgres_username
}

output "postgres_password" {
  value     = module.braintrust.postgres_password
  sensitive = true
}

output "pg_url" {
  value     = "postgres://${module.braintrust.postgres_username}:${module.braintrust.postgres_password}@${module.braintrust.postgres_instance_ip}:5432/postgres"
  sensitive = true
}

output "redis_instance_port" {
  value = module.braintrust.redis_instance_port
}

output "redis_instance_host" {
  value = module.braintrust.redis_instance_host
}

output "redis_url" {
  value = "redis://${module.braintrust.redis_instance_host}:${module.braintrust.redis_instance_port}"
}

output "api_url" {
  value = module.braintrust.api_url
}