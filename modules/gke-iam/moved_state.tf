moved {
  from = google_service_account.loop_runtime
  to   = google_service_account.loop_runtime[0]
}

moved {
  from = google_service_account_iam_binding.loop_runtime_workload_identity
  to   = google_service_account_iam_binding.loop_runtime_workload_identity[0]
}

moved {
  from = google_storage_bucket_iam_member.loop_runtime_brainstore_gcs_object_admin
  to   = google_storage_bucket_iam_member.loop_runtime_brainstore_gcs_object_admin[0]
}

moved {
  from = google_storage_bucket_iam_member.loop_runtime_brainstore_gcs_reader
  to   = google_storage_bucket_iam_member.loop_runtime_brainstore_gcs_reader[0]
}

moved {
  from = google_storage_bucket_iam_member.loop_runtime_api_bucket_gcs_object_admin
  to   = google_storage_bucket_iam_member.loop_runtime_api_bucket_gcs_object_admin[0]
}

moved {
  from = google_storage_bucket_iam_member.loop_runtime_api_bucket_gcs_reader
  to   = google_storage_bucket_iam_member.loop_runtime_api_bucket_gcs_reader[0]
}
