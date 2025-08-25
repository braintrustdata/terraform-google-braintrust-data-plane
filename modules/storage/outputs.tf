output "brainstore_bucket_name" {
  value = google_storage_bucket.brainstore.name
}

output "brainstore_bucket_self_link" {
  value = google_storage_bucket.brainstore.self_link
}


output "api_bucket_name" {
  value = google_storage_bucket.api.name
}

output "api_bucket_self_link" {
  value = google_storage_bucket.api.self_link
}
