output "braintrust_service_account" {
  value = google_service_account.braintrust.email
}

output "brainstore_service_account" {
  value = google_service_account.brainstore.email
}

output "braintrust_hmac_access_id" {
  value     = google_storage_hmac_key.braintrust[0].access_id
  sensitive = true
}

output "braintrust_hmac_secret" {
  value     = google_storage_hmac_key.braintrust[0].secret
  sensitive = true
}