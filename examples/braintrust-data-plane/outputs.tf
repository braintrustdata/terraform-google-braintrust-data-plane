output "braintrust_api_bucket_name" {
  value = module.braintrust-data-plane.braintrust_api_bucket_name
}

output "brainstore_bucket_name" {
  value = module.braintrust-data-plane.brainstore_bucket_name
}

output "braintrust_service_account" {
  value = module.braintrust-data-plane.braintrust_service_account
}

output "brainstore_service_account" {
  value = module.braintrust-data-plane.brainstore_service_account
}

output "postgres_instance_name" {
  value = module.braintrust-data-plane.postgres_instance_name
}

output "postgres_instance_ip" {
  value = module.braintrust-data-plane.postgres_instance_ip
}

output "postgres_username" {
  value = module.braintrust-data-plane.postgres_username
}

output "postgres_password" {
  value     = module.braintrust-data-plane.postgres_password
  sensitive = true
}

output "pg_url" {
  value     = "postgres://${module.braintrust-data-plane.postgres_username}:${module.braintrust-data-plane.postgres_password}@${module.braintrust-data-plane.postgres_instance_ip}:5432/postgres?sslmode=require"
  sensitive = true
}

output "redis_instance_port" {
  value = module.braintrust-data-plane.redis_instance_port
}

output "redis_instance_host" {
  value = module.braintrust-data-plane.redis_instance_host
}

output "redis_url" {
  value = "redis://:${module.braintrust-data-plane.redis_auth_string}@${module.braintrust-data-plane.redis_instance_host}:${module.braintrust-data-plane.redis_instance_port}"
  sensitive = true
}
