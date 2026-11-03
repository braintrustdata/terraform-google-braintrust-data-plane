output "braintrust_service_account" {
  value = google_service_account.braintrust.email
}

output "brainstore_service_account" {
  value = google_service_account.brainstore.email
}

output "braintrust_hmac_access_id" {
  description = "HMAC access ID for the Braintrust service account. Null when braintrust_hmac_key_enabled is false."
  value       = one(google_storage_hmac_key.braintrust[*].access_id)
  sensitive   = true
}

output "braintrust_hmac_secret" {
  description = "HMAC secret for the Braintrust service account. Null when braintrust_hmac_key_enabled is false."
  value       = one(google_storage_hmac_key.braintrust[*].secret)
  sensitive   = true
}

output "loop_runtime_service_account" {
  description = "Google service account email for loopRuntime.serviceAccount.googleServiceAccount in Helm."
  value       = one(google_service_account.loop_runtime[*].email)
}
