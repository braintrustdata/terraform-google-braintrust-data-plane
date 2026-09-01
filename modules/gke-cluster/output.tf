# Generic cluster outputs
output "gke_cluster_name" {
  value       = google_container_cluster.braintrust.name
  description = "GKE cluster name."
}

output "gke_cluster_endpoint" {
  value       = google_container_cluster.braintrust.endpoint
  description = "GKE cluster endpoint."
}

output "gke_cluster_master_version" {
  value       = google_container_cluster.braintrust.master_version
  description = "GKE cluster control plane version."
}

output "gke_cluster_id" {
  value       = google_container_cluster.braintrust.id
  description = "GKE cluster resource ID."
}

output "gke_cluster_location" {
  value       = google_container_cluster.braintrust.location
  description = "GKE cluster location."
}

output "gke_node_service_account_email" {
  value       = google_service_account.gke.email
  description = "Email address of the GKE node service account."
}

# Compatibility outputs
output "gke_autopilot_cluster_name" {
  value       = var.gke_cluster_mode == "autopilot" ? google_container_cluster.braintrust.name : null
  description = "GKE Autopilot cluster name. Null for Standard clusters."
}

output "gke_autopilot_cluster_endpoint" {
  value       = var.gke_cluster_mode == "autopilot" ? google_container_cluster.braintrust.endpoint : null
  description = "GKE Autopilot cluster endpoint. Null for Standard clusters."
}

output "gke_autopilot_cluster_master_version" {
  value       = var.gke_cluster_mode == "autopilot" ? google_container_cluster.braintrust.master_version : null
  description = "GKE Autopilot control plane version. Null for Standard clusters."
}

output "workload_identity_pool" {
  value       = google_container_cluster.braintrust.workload_identity_config[0].workload_pool
  description = "Workload Identity pool for Kubernetes service account IAM bindings."
}
