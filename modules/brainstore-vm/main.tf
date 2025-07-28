#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
locals {
  common_labels = {
    braintrustdeploymentname = var.deployment_name
  }

  brainstore_release_version = jsondecode(file("${path.module}/VERSIONS.json"))["brainstore"]


  # Get zones where the machine type is available. Not all machine types are available in all zones inside a region.
  available_zones = [
    for zone_name, machine_types in data.google_compute_machine_types.brainstore :
    zone_name if length(machine_types.machine_types) > 0
  ]
}

data "google_compute_zones" "up" {
  project = data.google_project.current.project_id
  status  = "UP"
}

data "google_compute_image" "brainstore" {
  name    = var.image_name
  project = var.image_project
}

data "google_project" "current" {}

# Data source to get machine types available in each zone
data "google_compute_machine_types" "brainstore" {
  for_each = toset(data.google_compute_zones.up.names)
  zone     = each.value
  filter   = "name = ${var.brainstore_reader_machine_type}"
}

#----------------------------------------------------------------------------------------------
# Firewall Rules - Brainstore Reader and Writer
#----------------------------------------------------------------------------------------------

resource "google_compute_firewall" "vm_allow_ingress_ssh_from_cidr" {
  count = var.cidr_allow_ingress_vm_ssh != null ? 1 : 0

  name        = "${var.deployment_name}-brainstore-allow-ssh-from-cidr"
  description = "Allow TCP/22 ingress to Brainstore instances from specified CIDR ranges."
  network     = var.brainstore_network
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  source_ranges = var.cidr_allow_ingress_vm_ssh
  target_tags   = ["brainstore-reader", "brainstore-writer"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "vm_allow_ingress_ssh_from_iap" {
  count = var.allow_ingress_vm_ssh_from_iap ? 1 : 0

  name        = "${var.deployment_name}-brainstore-allow-ssh-from-iap"
  description = "Allow TCP/22 ingress to Brainstore instances from IAP."
  network     = var.brainstore_network
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [22]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["brainstore-reader", "brainstore-writer"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}