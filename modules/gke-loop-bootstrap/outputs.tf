locals {
  helm_values_yaml = yamlencode({
    loopRuntime = {
      enabled        = true
      image          = { tag = local.config.services_version }
      serviceAccount = { googleServiceAccount = var.runtime_service_account }
      sandbox = {
        dnsUrl = var.workers.discovery.endpoint
        egressGateway = {
          address      = var.workers.loop_egress.address
          url          = var.workers.loop_egress.url
          sourceRanges = var.workers.loop_egress.source_ranges
        }
        clientTlsSecret = "${google_secret_manager_secret.tls["client"].id}/versions/latest"
      }
    }
  })
}

output "helm_values_yaml" {
  description = "Ready Loop values for an existing primary Helm release; contains references, not credentials."
  value       = local.helm_values_yaml
  depends_on  = [data.http.ready]
}

output "loop_runtime" {
  description = "Applied Loop configuration for the GKE app module."
  value = {
    helm_values_yaml        = local.helm_values_yaml
    services_version_pinned = var.options.services_version != null && var.options.services_version != ""
  }
  depends_on = [data.http.ready]
}

output "client_tls_secret" {
  description = "Runtime-readable client bundle reference, after worker bootstrap succeeds."
  value       = "${google_secret_manager_secret.tls["client"].id}/versions/latest"
  depends_on  = [data.http.ready]
}
output "services_version" {
  value      = coalesce(var.options.services_version, local.versions.services_version)
  depends_on = [data.http.ready]
}
output "revision" {
  value      = local.revision
  depends_on = [data.http.ready]
}

output "execution_token" {
  description = "Installer execution suffix, stable until the worker configuration changes."
  value       = google_cloud_run_v2_job.install.run_execution_token
}
