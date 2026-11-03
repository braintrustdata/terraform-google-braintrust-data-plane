output "kms_key_ring_name" {
  value = google_kms_key_ring.kms.name
}

output "kms_key_name" {
  value = google_kms_crypto_key.kms.name
}

output "kms_key_ring_id" {
  value = google_kms_key_ring.kms.id
}

output "kms_key_id" {
  value = google_kms_crypto_key.kms.id
}

output "gke_kms_key_id" {
  value       = google_kms_crypto_key.kms.id
  description = "Key ID after the GKE service-agent grants exist."
  depends_on  = [google_kms_crypto_key_iam_member.gke_cluster_cmek, google_kms_crypto_key_iam_member.gke_compute_cmek]
}
