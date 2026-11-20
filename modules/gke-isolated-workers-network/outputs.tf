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
    zone_name                    = google_dns_managed_zone.discovery[0].name
    dns_name                     = google_dns_managed_zone.discovery[0].dns_name
    hostname                     = "workers.${trimsuffix(var.config.discovery.dns_name, ".")}"
    endpoint                     = "https://workers.${trimsuffix(var.config.discovery.dns_name, ".")}:9400"
    external_dns_namespace       = local.isolated_dns_namespace
    external_dns_service_account = local.isolated_discovery.external_dns_service_account
    # Arguments the published Sandbox Service chart does not set itself.
    external_dns_extra_args = [
      "--google-project=${data.google_client_config.current.project}",
      "--google-zone-visibility=private",
      "--zone-id-filter=${google_dns_managed_zone.discovery[0].name}",
      "--domain-filter=${trimsuffix(local.isolated_discovery.dns_name, ".")}",
      "--txt-owner-id=${local.name}",
    ]
  }
}

output "node_cidr" {
  value       = local.node_cidr
  description = "Node range from the created or supplied subnet."
}

output "loop_egress" {
  description = "Loop Runtime Git forward proxy address for Helm loopRuntime.sandbox.egressGateway. Null without discovery."
  value = var.config.discovery == null ? null : {
    address       = google_compute_address.loop_egress[0].address
    hostname      = trimsuffix(google_dns_record_set.loop_egress[0].name, ".")
    url           = "http://${trimsuffix(google_dns_record_set.loop_egress[0].name, ".")}:${local.loop_egress_port}"
    source_ranges = [local.node_cidr, var.config.pod_cidr]
  }
}

output "network_tag" {
  value = local.name
}
