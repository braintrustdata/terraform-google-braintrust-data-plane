output "brainstore_bucket_name" {
  value = google_storage_bucket.brainstore.name
}

output "brainstore_bucket_self_link" {
  value = google_storage_bucket.brainstore.self_link
}

output "code_bundle_bucket_name" {
  value = google_storage_bucket.code_bundle.name
}

output "code_bundle_bucket_self_link" {
  value = google_storage_bucket.code_bundle.self_link
}

output "response_bucket_name" {
  value = google_storage_bucket.response.name
}

output "response_bucket_self_link" {
  value = google_storage_bucket.response.self_link
}
