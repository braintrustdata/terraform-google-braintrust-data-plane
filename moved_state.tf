moved {
  from = module.gke-cluster[0].google_kms_crypto_key_iam_member.gke_cluster_cmek
  to   = module.kms.google_kms_crypto_key_iam_member.gke_cluster_cmek[0]
}

moved {
  from = module.gke-cluster[0].google_kms_crypto_key_iam_member.gke_compute_cmek
  to   = module.kms.google_kms_crypto_key_iam_member.gke_compute_cmek[0]
}