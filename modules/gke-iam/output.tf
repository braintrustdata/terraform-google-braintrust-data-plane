output "braintrust_service_account" {
  value = google_service_account.braintrust.email
}

output "brainstore_service_account" {
  value = google_service_account.brainstore.email
}
