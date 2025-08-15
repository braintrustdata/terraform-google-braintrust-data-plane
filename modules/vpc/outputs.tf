output "network_name" {
  value       = google_compute_network.vpc.name
  description = "Name of the VPC Network"
}

output "network_self_link" {
  value       = google_compute_network.vpc.self_link
  description = "Self link of the VPC Network"
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnets.name
  description = "Name of the subnet"
}

output "subnet_self_link" {
  value       = google_compute_subnetwork.subnets.self_link
  description = "Self link of the subnet"
}

output "private_vpc_connection" {
  value       = google_service_networking_connection.private_vpc_connection
  description = "Private VPC connection for Google Cloud Services"
}

output "vpc_access_connector_name" {
  value       = google_vpc_access_connector.connector[0].name
  description = "Name of the Google Access Connector"
}

output "vpc_access_connector_self_link" {
  value       = google_vpc_access_connector.connector[0].self_link
  description = "Self link of the Google Access Connector"
}