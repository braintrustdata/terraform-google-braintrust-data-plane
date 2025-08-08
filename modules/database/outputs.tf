output "postgres_instance_name" {
  value = google_sql_database_instance.braintrust.name
}

output "postgres_instance_ip" {
  value = google_sql_database_instance.braintrust.private_ip_address
}

output "postgres_password_secret_name" {
  value = basename(google_secret_manager_secret.postgres_password.id)
}

output "postgres_username" {
  value = local.postgres_username
}

output "postgres_password" {
  value = local.postgres_password
}
