# Autopilot cluster outputs
output "gke_autopilot_cluster_name" {
  value       = google_container_cluster.braintrust_autopilot.name
  description = "Name of the autopilot cluster (null if not enabled)"
}

output "gke_autopilot_cluster_endpoint" {
  value       = google_container_cluster.braintrust_autopilot.endpoint
  description = "Endpoint of the autopilot cluster (null if not enabled)"
}

output "gke_autopilot_cluster_master_version" {
  value       = google_container_cluster.braintrust_autopilot.master_version
  description = "Master version of the autopilot cluster (null if not enabled)"
}

output "workload_identity_pool" {
  value       = google_container_cluster.braintrust_autopilot.workload_identity_config[0].workload_pool
  description = "Workload Identity pool for Kubernetes service account IAM bindings."
}
