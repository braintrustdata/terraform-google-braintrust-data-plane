output "brainstore_bucket_name" {
  value = google_storage_bucket.brainstore.name
}

output "brainstore_bucket_self_link" {
  value = google_storage_bucket.brainstore.self_link
}

output "api_code_bundle_bucket_name" {
  value = google_storage_bucket.api_code_bundle.name
}

output "api_code_bundle_bucket_self_link" {
  value = google_storage_bucket.api_code_bundle.self_link
}

output "lambda_response_bucket_name" {
  value = google_storage_bucket.lambda_response.name
}

output "lambda_response_bucket_self_link" {
  value = google_storage_bucket.lambda_response.self_link
}
