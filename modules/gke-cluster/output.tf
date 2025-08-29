output "gke_cluster_name" {
  value = google_container_cluster.braintrust.name
}

output "gke_cluster_endpoint" {
  value = google_container_cluster.braintrust.endpoint
}

output "gke_cluster_master_version" {
  value = google_container_cluster.braintrust.master_version
}

output "gke_cluster_node_pool_name" {
  value = google_container_node_pool.braintrust.name
}

output "gke_cluster_node_pool_version" {
  value = google_container_node_pool.braintrust.version
}