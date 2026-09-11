data "google_client_config" "current" {}

locals {
  # Preserve a readable prefix and avoid truncation collisions for long deployments.
  name                 = "${substr(replace(var.deployment_name, "_", "-"), 0, 14)}-${substr(sha256(var.deployment_name), 0, 6)}-isolated-workers"
  labels               = merge(var.custom_labels, { braintrustdeploymentname = var.deployment_name })
  subnet               = var.config.existing_subnet_self_link == null ? google_compute_subnetwork.workers[0].self_link : data.google_compute_subnetwork.existing[0].self_link
  node_cidr            = var.config.existing_subnet_self_link == null ? var.config.node_cidr : data.google_compute_subnetwork.existing[0].ip_cidr_range
  ranges               = [local.node_cidr, var.config.pod_cidr, var.config.service_cidr, var.config.control_plane_cidr]
  known_primary_ranges = [for cidr in var.primary_cidrs : cidr if can(cidrnetmask(cidr))]
  # Stable private and reserved ranges, plus known primary network destinations.
  # Public ECR endpoints do not require an IP allowlist.
  private_destinations = distinct(concat([
    "0.0.0.0/8", "10.0.0.0/8", "100.64.0.0/10", "127.0.0.0/8",
    "169.254.0.0/16", "172.16.0.0/12", "192.168.0.0/16",
    "224.0.0.0/4", "240.0.0.0/4",
  ], local.known_primary_ranges, var.config.discovery == null ? [] : tolist(var.config.discovery.runtime_source_ranges)))
  range_bounds = {
    for cidr in distinct(concat(local.ranges, local.known_primary_ranges)) : cidr => {
      first = try(sum([for i, octet in split(".", cidrhost(cidr, 0)) : tonumber(octet) * pow(256, 3 - i)]), 0)
      last  = try(sum([for i, octet in split(".", cidrhost(cidr, -1)) : tonumber(octet) * pow(256, 3 - i)]), 0)
    }
  }
}

resource "terraform_data" "network_contract" {
  input = local.ranges
  lifecycle {
    precondition {
      condition = alltrue(flatten([
        for i, a in local.ranges : [for j, b in local.ranges :
          local.range_bounds[a].last < local.range_bounds[b].first || local.range_bounds[b].last < local.range_bounds[a].first if i < j
        ]
        ])) && alltrue(flatten([
        for a in local.ranges : [for b in local.known_primary_ranges :
          local.range_bounds[a].last < local.range_bounds[b].first || local.range_bounds[b].last < local.range_bounds[a].first
        ]
      ]))
      error_message = "Worker ranges must not overlap each other or known primary ranges."
    }
  }
}

resource "google_compute_subnetwork" "workers" {
  count                    = var.config.existing_subnet_self_link == null ? 1 : 0
  name                     = local.name
  project                  = data.google_client_config.current.project
  region                   = data.google_client_config.current.region
  network                  = var.network
  ip_cidr_range            = var.config.node_cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  depends_on = [terraform_data.network_contract]
}

# These controls protect hosts and VPC destinations. Guest DNS and metadata
# isolation remain the responsibility of the privileged worker application.
resource "google_compute_firewall" "deny" {
  for_each           = toset(["INGRESS", "EGRESS"])
  name               = "${local.name}-deny-${lower(each.key)}"
  project            = data.google_client_config.current.project
  network            = var.network
  direction          = each.key
  priority           = 1000
  target_tags        = [local.name]
  source_ranges      = each.key == "INGRESS" ? ["0.0.0.0/0"] : null
  destination_ranges = each.key == "EGRESS" ? ["0.0.0.0/0"] : null
  deny { protocol = "all" }
  log_config { metadata = "INCLUDE_ALL_METADATA" }
}

resource "google_compute_firewall" "internal" {
  for_each           = toset(["INGRESS", "EGRESS"])
  name               = "${local.name}-internal-${lower(each.key)}"
  project            = data.google_client_config.current.project
  network            = var.network
  direction          = each.key
  priority           = 900
  target_tags        = [local.name]
  source_ranges      = each.key == "INGRESS" ? [local.node_cidr, var.config.pod_cidr] : null
  destination_ranges = each.key == "EGRESS" ? [local.node_cidr, var.config.pod_cidr, var.config.service_cidr] : null
  allow { protocol = "all" }
}

resource "google_compute_firewall" "control_plane_ingress" {
  name          = "${local.name}-control-ingress"
  project       = data.google_client_config.current.project
  network       = var.network
  direction     = "INGRESS"
  priority      = 900
  target_tags   = [local.name]
  source_ranges = [var.config.control_plane_cidr]
  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }
}

resource "google_compute_firewall" "control_plane_egress" {
  name               = "${local.name}-control-egress"
  project            = data.google_client_config.current.project
  network            = var.network
  direction          = "EGRESS"
  priority           = 900
  target_tags        = [local.name]
  destination_ranges = [var.config.control_plane_cidr]
  allow {
    protocol = "tcp"
    ports    = ["443", "8132"]
  }
}

resource "google_compute_firewall" "public_https" {
  name               = "${local.name}-public-https"
  project            = data.google_client_config.current.project
  network            = var.network
  direction          = "EGRESS"
  priority           = 950
  target_tags        = [local.name]
  destination_ranges = ["0.0.0.0/0"]
  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

# Internal cluster traffic and explicit exceptions precede this deny.
# This deny precedes general outbound HTTPS through the existing NAT path.
resource "google_compute_firewall" "private_egress" {
  name               = "${local.name}-deny-private"
  project            = data.google_client_config.current.project
  network            = var.network
  direction          = "EGRESS"
  priority           = 925
  target_tags        = [local.name]
  destination_ranges = local.private_destinations
  deny { protocol = "all" }
  log_config { metadata = "INCLUDE_ALL_METADATA" }
}

resource "google_compute_firewall" "ingress" {
  for_each      = var.config.ingress_rules
  name          = "${local.name}-in-${substr(sha256(each.key), 0, 8)}"
  project       = data.google_client_config.current.project
  network       = var.network
  direction     = "INGRESS"
  priority      = 800
  target_tags   = [local.name]
  source_ranges = each.value.source_ranges
  description   = "Explicit isolated worker ingress: ${each.key}"
  allow {
    protocol = "tcp"
    ports    = each.value.ports
  }
  log_config { metadata = "INCLUDE_ALL_METADATA" }
}

resource "google_compute_firewall" "egress" {
  for_each           = var.config.egress_rules
  name               = "${local.name}-out-${substr(sha256(each.key), 0, 8)}"
  project            = data.google_client_config.current.project
  network            = var.network
  direction          = "EGRESS"
  priority           = 800
  target_tags        = [local.name]
  destination_ranges = each.value.destination_ranges
  description        = "Explicit isolated worker egress: ${each.key}"
  allow {
    protocol = "tcp"
    ports    = each.value.ports
  }
  log_config { metadata = "INCLUDE_ALL_METADATA" }
}

data "google_compute_subnetwork" "existing" {
  count     = var.config.existing_subnet_self_link == null ? 0 : 1
  self_link = var.config.existing_subnet_self_link
  lifecycle {
    postcondition {
      condition = (
        self.network == var.network && (var.config.node_cidr == null || self.ip_cidr_range == var.config.node_cidr) &&
        basename(var.primary_subnet) != basename(self.self_link) &&
        self.private_ip_google_access && endswith(self.region, "/${data.google_client_config.current.region}")
      )
      error_message = "The isolated subnet must match the VPC, region, and node CIDR, with Private Google Access enabled and separation from the primary subnet."
    }
  }
}

resource "google_dns_managed_zone" "discovery" {
  count      = var.config.discovery == null ? 0 : 1
  project    = data.google_client_config.current.project
  name       = "${local.name}-discovery"
  dns_name   = "${trimsuffix(var.config.discovery.dns_name, ".")}."
  visibility = "private"
  labels     = local.labels
  private_visibility_config {
    networks { network_url = var.network }
  }
}

resource "google_compute_firewall" "runtime_to_workers" {
  count         = var.config.discovery == null ? 0 : 1
  project       = data.google_client_config.current.project
  name          = "${local.name}-runtime"
  network       = var.network
  direction     = "INGRESS"
  priority      = 800
  target_tags   = ["${local.name}-workers"]
  source_ranges = var.config.discovery.runtime_source_ranges
  allow {
    protocol = "tcp"
    ports    = ["9400"]
  }
  log_config { metadata = "INCLUDE_ALL_METADATA" }
}

locals {
  isolated_discovery     = var.config.discovery
  isolated_dns_namespace = local.isolated_discovery == null ? null : coalesce(local.isolated_discovery.external_dns_namespace, local.name)
}

resource "google_service_account" "isolated_external_dns" {
  count        = local.isolated_discovery == null ? 0 : 1
  project      = data.google_client_config.current.project
  account_id   = "${substr(replace(var.deployment_name, "_", "-"), 0, 13)}-${substr(sha256(var.deployment_name), 0, 6)}-iw-dns"
  display_name = "${var.deployment_name} isolated worker discovery"
}

resource "google_service_account_iam_binding" "isolated_external_dns" {
  count              = local.isolated_discovery == null ? 0 : 1
  service_account_id = google_service_account.isolated_external_dns[0].id
  role               = "roles/iam.workloadIdentityUser"
  members            = ["serviceAccount:${data.google_client_config.current.project}.svc.id.goog[${local.isolated_dns_namespace}/${local.isolated_discovery.external_dns_service_account}]"]
}

# External-dns lists zones before it applies its zone and domain filters.
resource "google_project_iam_custom_role" "isolated_dns_zone_list" {
  count       = local.isolated_discovery == null ? 0 : 1
  project     = data.google_client_config.current.project
  role_id     = "isolatedDnsList_${substr(sha256(var.deployment_name), 0, 12)}"
  title       = "Isolated worker DNS zone discovery"
  permissions = ["dns.managedZones.list"]
}

resource "google_project_iam_member" "isolated_dns_zone_list" {
  count   = local.isolated_discovery == null ? 0 : 1
  project = data.google_client_config.current.project
  role    = google_project_iam_custom_role.isolated_dns_zone_list[0].name
  member  = "serviceAccount:${google_service_account.isolated_external_dns[0].email}"
}

resource "google_project_iam_custom_role" "isolated_dns_records" {
  count   = local.isolated_discovery == null ? 0 : 1
  project = data.google_client_config.current.project
  role_id = "isolatedDnsRecords_${substr(sha256(var.deployment_name), 0, 12)}"
  title   = "Isolated worker DNS records"
  permissions = [
    "dns.changes.create",
    "dns.resourceRecordSets.create",
    "dns.resourceRecordSets.delete",
    "dns.resourceRecordSets.list",
    "dns.resourceRecordSets.update",
  ]
}

resource "google_dns_managed_zone_iam_member" "isolated_external_dns" {
  count        = local.isolated_discovery == null ? 0 : 1
  project      = data.google_client_config.current.project
  managed_zone = google_dns_managed_zone.discovery[0].name
  role         = google_project_iam_custom_role.isolated_dns_records[0].name
  member       = "serviceAccount:${google_service_account.isolated_external_dns[0].email}"
}
