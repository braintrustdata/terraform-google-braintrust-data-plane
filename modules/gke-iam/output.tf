output "braintrust_service_account" {
  value = google_service_account.braintrust.email
}

output "brainstore_service_account" {
  value = google_service_account.brainstore.email
}

# output "secret_creation_commands" {
#   description = "CLI commands to create secret values"
#   value = <<-EOT
#     # Create secret versions with final values with the following commands:
#     gcloud secrets versions add ${google_secret_manager_secret.brainstore_license_key.secret_id} --data-file=<(echo "YOUR_BRAINTRUST_LICENSE_KEY_HERE")
#     gcloud secrets versions add ${google_secret_manager_secret.pg_url.secret_id} --data-file=<(echo "postgresql://postgres:password@host:port/postgres")
#     gcloud secrets versions add ${google_secret_manager_secret.redis_url.secret_id} --data-file=<(echo "redis://ip:6379")
#     gcloud secrets versions add ${google_secret_manager_secret.function_secret_key.secret_id} --data-file=<(echo "YOUR_FUNCTION_SECRET_KEY_HERE")
#   EOT
# }
