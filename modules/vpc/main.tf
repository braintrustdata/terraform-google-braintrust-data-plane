#----------------------------------------------------------------------------------------------
# Network
#----------------------------------------------------------------------------------------------
resource "google_compute_network" "vpc" {
  name                            = "${var.deployment_name}-${var.vpc_name}"
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
  routing_mode                    = "REGIONAL"
}

resource "google_compute_subnetwork" "subnets" {
  name                     = "${var.deployment_name}-${var.vpc_name}-private"
  network                  = google_compute_network.vpc.self_link
  ip_cidr_range            = var.subnet_cidr_range
  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  name    = "${var.deployment_name}-${var.vpc_name}-router"
  network = google_compute_network.vpc.self_link
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.deployment_name}-${var.vpc_name}"
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

#----------------------------------------------------------------------------------------------
# Private Services Connection for Cloud SQL and Redis
#----------------------------------------------------------------------------------------------
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.deployment_name}-private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  deletion_policy         = "ABANDON" # Due to https://github.com/hashicorp/terraform-provider-google/issues/19908 resource cannot be deleted
}
