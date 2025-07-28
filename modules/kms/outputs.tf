output "kms_key_ring_name" {
  value = google_kms_key_ring.kms.name
}

output "kms_key_name" {
  value = google_kms_crypto_key.root.name
}

output "kms_key_ring_id" {
  value = google_kms_key_ring.kms.id
}

output "kms_key_id" {
  value = google_kms_crypto_key.root.id
}
