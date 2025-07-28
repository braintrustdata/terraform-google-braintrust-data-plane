#----------------------------------------------------------------------------------------------
# User Data (cloud-init) arguments - Brainstore Writer
#----------------------------------------------------------------------------------------------

locals {
  brainstore_writer_data_args = {
    # Brainstore settings
    deployment_name                        = var.deployment_name
    project_id                             = data.google_project.current.project_id
    database_secret_name                   = var.database_secret_name
    brainstore_port                        = var.brainstore_port
    brainstore_gcs_bucket                  = var.brainstore_gcs_bucket
    redis_host                             = var.redis_host
    redis_port                             = var.redis_port
    database_host                          = var.database_host
    database_port                          = var.database_port
    brainstore_license_key_secret_name     = var.brainstore_license_key_secret_name
    brainstore_disable_optimization_worker = var.brainstore_disable_optimization_worker
    brainstore_vacuum_all_objects          = var.brainstore_vacuum_all_objects
    extra_env_vars                         = var.extra_env_vars_writer
    is_dedicated_writer_node               = true
    internal_observability_api_key         = var.internal_observability_api_key
    internal_observability_env_name        = var.internal_observability_env_name
    internal_observability_region          = var.internal_observability_region
    brainstore_version_override            = var.brainstore_version_override == null ? "" : var.brainstore_version_override
    brainstore_release_version             = local.brainstore_release_version
  }
}

#----------------------------------------------------------------------------------------------
# Cloud Init Config - Brainstore Writer
#----------------------------------------------------------------------------------------------

data "cloudinit_config" "brainstore_writer_cloudinit" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "user_data.sh"
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/templates/user_data.sh.tpl", local.brainstore_writer_data_args)
  }
}

#----------------------------------------------------------------------------------------------
# Instance Template - Brainstore Writer
#----------------------------------------------------------------------------------------------

resource "google_compute_instance_template" "brainstore_writer" {
  name_prefix  = "${var.deployment_name}-brainstore-writer-template-"
  machine_type = var.brainstore_writer_machine_type

  disk {
    source_image = data.google_compute_image.brainstore.self_link
    auto_delete  = true
    boot         = true
    disk_size_gb = var.brainstore_writer_disk_size_gb
    disk_type    = "hyperdisk-balanced"
    mode         = "READ_WRITE"
    type         = "PERSISTENT"
  }

  network_interface {
    subnetwork = var.brainstore_subnet
  }

  metadata = {
    user-data          = data.cloudinit_config.brainstore_writer_cloudinit.rendered
    user-data-encoding = "base64"
  }

  service_account {
    scopes = ["cloud-platform"]
    email  = google_service_account.brainstore.email
  }

  labels = local.common_labels
  tags   = ["brainstore-writer"]

  lifecycle {
    create_before_destroy = true
  }
}

#----------------------------------------------------------------------------------------------
# Instance Group - Brainstore Writer
#----------------------------------------------------------------------------------------------

resource "google_compute_region_instance_group_manager" "brainstore_writer" {
  name                      = "${var.deployment_name}-brainstore-writer"
  base_instance_name        = "${var.deployment_name}-brainstore-writer"
  distribution_policy_zones = local.available_zones
  target_size               = var.brainstore_writer_instance_count

  version {
    instance_template = google_compute_instance_template.brainstore_writer.self_link
  }

  named_port {
    name = "brainstore"
    port = var.brainstore_port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.brainstore_writer_auto_healing.self_link
    initial_delay_sec = var.initial_delay_sec
  }

  update_policy {
    minimal_action = "REPLACE"
    type           = "PROACTIVE"

    max_surge_fixed       = length(data.google_compute_zones.up.names)
    max_unavailable_fixed = length(data.google_compute_zones.up.names)
  }
}

resource "google_compute_health_check" "brainstore_writer_auto_healing" {
  name                = "${var.deployment_name}-brainstore-writer"
  check_interval_sec  = 10
  healthy_threshold   = 3
  unhealthy_threshold = 3
  timeout_sec         = 10

  tcp_health_check {
    port = var.brainstore_port
  }
}

#----------------------------------------------------------------------------------------------
# Load Balancer - Brainstore Writer
#----------------------------------------------------------------------------------------------

#----------------------------------------------------------------------------------------------
# Frontend
#----------------------------------------------------------------------------------------------
resource "google_compute_address" "brainstore_writer_frontend_lb" {
  name         = "${var.deployment_name}-brainstore-writer-frontend-lb-ip"
  description  = "Static IP to associate with Brainstore load balancer forwarding rule (front end)."
  address_type = "INTERNAL"
  network_tier = null
  subnetwork   = var.brainstore_subnet
}

resource "google_compute_forwarding_rule" "brainstore_writer_frontend_lb" {
  name                  = "${var.deployment_name}-brainstore-writer-frontend-lb-internal"
  backend_service       = google_compute_region_backend_service.brainstore_writer_backend_lb.id
  ip_protocol           = "TCP"
  load_balancing_scheme = "INTERNAL"
  ports                 = [var.brainstore_port]
  network               = var.brainstore_network
  subnetwork            = var.brainstore_subnet
  ip_address            = google_compute_address.brainstore_writer_frontend_lb.address
}

#----------------------------------------------------------------------------------------------
# Backend
#----------------------------------------------------------------------------------------------
resource "google_compute_region_backend_service" "brainstore_writer_backend_lb" {
  name                  = "${var.deployment_name}-brainstore-backend-lb-internal"
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"

  backend {
    description    = "Brainstore Writer Internal regional backend service."
    group          = google_compute_region_instance_group_manager.brainstore_writer.instance_group
    balancing_mode = "CONNECTION"
    failover       = false
  }

  health_checks = [google_compute_region_health_check.brainstore_writer_backend_lb.self_link]
}

resource "google_compute_region_health_check" "brainstore_writer_backend_lb" {
  name               = "${var.deployment_name}-brainstore-writer-backend-svc-health-check"
  check_interval_sec = 5
  timeout_sec        = 5

  tcp_health_check {
    port = var.brainstore_port
  }
}

#----------------------------------------------------------------------------------------------
# Firewall Rules - Brainstore
#----------------------------------------------------------------------------------------------

resource "google_compute_firewall" "brainstore_writer_allow_lb_health_checks" {
  name        = "${var.deployment_name}-brainstore-writer-allow-lb-health-checks-${var.brainstore_port}"
  description = "Allow TCP/${var.brainstore_port} inbound to Brainstore instances from GCP load balancer health probe source CIDR blocks."
  network     = var.brainstore_network
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = [var.brainstore_port]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["brainstore-writer"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}
