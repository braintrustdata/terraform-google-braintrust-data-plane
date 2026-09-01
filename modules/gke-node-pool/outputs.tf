output "name" {
  value       = google_container_node_pool.this.name
  description = "GKE node pool name."
}

output "id" {
  value       = google_container_node_pool.this.id
  description = "GKE node pool resource ID."
}

output "managed_instance_group_urls" {
  value       = google_container_node_pool.this.managed_instance_group_urls
  description = "Managed instance group URLs for the node pool."
}
