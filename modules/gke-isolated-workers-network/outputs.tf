output "isolated_subnet_self_link" {
  description = "Worker subnet after network policy creation."
  value       = local.subnet
  depends_on  = [google_compute_firewall.deny, google_compute_firewall.internal, google_compute_firewall.control_plane_ingress, google_compute_firewall.control_plane_egress, google_compute_firewall.public_https, google_compute_firewall.private_egress]
}

output "network_self_link" {
  value       = var.network
  description = "VPC self link for isolated workers."
}

output "discovery" {
  description = "Private worker discovery zone. External-dns owns its worker records."
  value = var.config.discovery == null ? null : {
    zone_name                                = google_dns_managed_zone.discovery[0].name
    dns_name                                 = google_dns_managed_zone.discovery[0].dns_name
    hostname                                 = "workers.${trimsuffix(var.config.discovery.dns_name, ".")}"
    endpoint                                 = "https://workers.${trimsuffix(var.config.discovery.dns_name, ".")}:9400"
    external_dns_namespace                   = local.isolated_dns_namespace
    external_dns_service_account             = local.isolated_discovery.external_dns_service_account
    external_dns_google_service_account      = google_service_account.isolated_external_dns[0].email
    external_dns_service_account_annotations = { "iam.gke.io/gcp-service-account" = google_service_account.isolated_external_dns[0].email }
    external_dns_args = [
      "--source=service",
      "--service-type-filter=ClusterIP",
      "--provider=google",
      "--google-project=${data.google_client_config.current.project}",
      "--google-zone-visibility=private",
      "--zone-id-filter=${google_dns_managed_zone.discovery[0].name}",
      "--domain-filter=${trimsuffix(local.isolated_discovery.dns_name, ".")}",
      "--namespace=${local.isolated_dns_namespace}",
      "--registry=txt",
      "--txt-owner-id=${local.name}",
      "--txt-prefix=_external-dns.",
      "--policy=sync",
    ]

  }
}

output "node_cidr" {
  value       = local.node_cidr
  description = "Node range from the created or supplied subnet."
}
