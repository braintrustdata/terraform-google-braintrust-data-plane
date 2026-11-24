data "google_project_iam_custom_roles" "isolated_dns" {
  count        = local.isolated_discovery == null || var.existing_dns_roles != null ? 0 : 1
  project      = data.google_client_config.current.project
  show_deleted = true
}

locals {
  bootstrap_dns_roles = {
    zone_list = "projects/${data.google_client_config.current.project}/roles/braintrustIsolatedDnsList"
    records   = "projects/${data.google_client_config.current.project}/roles/braintrustIsolatedDnsRecords"
  }
  legacy_dns_roles = {
    zone_list = "projects/${data.google_client_config.current.project}/roles/isolatedDnsList_${substr(sha256(var.deployment_name), 0, 12)}"
    records   = "projects/${data.google_client_config.current.project}/roles/isolatedDnsRecords_${substr(sha256(var.deployment_name), 0, 12)}"
  }
  available_dns_roles = toset([
    for role in try(data.google_project_iam_custom_roles.isolated_dns[0].roles, []) : role.name
    if !role.deleted && role.stage != "DISABLED"
  ])
  # Prefer bootstrap roles, retaining the existing pair until bootstrap is run.
  discovered_dns_roles = [
    for pair in [local.bootstrap_dns_roles, local.legacy_dns_roles] : pair
    if alltrue([for role in values(pair) : contains(local.available_dns_roles, role)])
  ]
  known_dns_roles_present = anytrue([
    for role in try(data.google_project_iam_custom_roles.isolated_dns[0].roles, []) :
    contains(concat(values(local.bootstrap_dns_roles), values(local.legacy_dns_roles)), role.name)
  ])
  isolated_dns_roles = var.existing_dns_roles != null ? var.existing_dns_roles : try(local.discovered_dns_roles[0], {
    zone_list = "roles/dns.reader"
    records   = "roles/dns.admin"
  })
}

# Role definitions belong to bootstrap. Forget legacy state without deleting
# roles that existing external-dns grants still use, including when workers turn off.
removed {
  from = google_project_iam_custom_role.isolated_dns_zone_list
  lifecycle {
    destroy = false
  }
}

removed {
  from = google_project_iam_custom_role.isolated_dns_records
  lifecycle {
    destroy = false
  }
}
