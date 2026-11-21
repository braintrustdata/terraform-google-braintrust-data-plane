output "client_tls_secret" {
  description = "Runtime-readable client bundle reference, after worker bootstrap succeeds."
  value       = "${google_secret_manager_secret.tls["client"].id}/versions/latest"
  depends_on  = [google_cloud_run_v2_job.install]
}
output "services_version" {
  value      = coalesce(var.options.services_version, local.versions.services_version)
  depends_on = [google_cloud_run_v2_job.install]
}
output "revision" {
  value      = local.revision
  depends_on = [google_cloud_run_v2_job.install]
}
