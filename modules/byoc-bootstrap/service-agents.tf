locals {
  # The catalog contains primary agents supported by the legacy identity endpoint.
  primary_service_agents = {
    gke = {
      service = "container.googleapis.com"
      email   = "service-${var.project_number}@container-engine-robot.iam.gserviceaccount.com"
      role    = "roles/container.serviceAgent"
    }
    redis = {
      service = "redis.googleapis.com"
      email   = "service-${var.project_number}@cloud-redis.iam.gserviceaccount.com"
      role    = "roles/redis.serviceAgent"
    }
    networking = {
      service = "servicenetworking.googleapis.com"
      email   = "service-${var.project_number}@service-networking.iam.gserviceaccount.com"
      role    = "roles/servicenetworking.serviceAgent"
    }
    dns = {
      service = "dns.googleapis.com"
      email   = "service-${var.project_number}@gcp-sa-dns.iam.gserviceaccount.com"
      role    = "roles/dns.serviceAgent"
    }
  }
  # Compute and the GKE node agent follow API activation, not the default VM account.
  activation_service_agents = {
    compute = {
      service = "compute.googleapis.com"
      email   = "service-${var.project_number}@compute-system.iam.gserviceaccount.com"
      role    = "roles/compute.serviceAgent"
    }
    gke_node = {
      service = "container.googleapis.com"
      email   = "service-${var.project_number}@gcp-sa-gkenode.iam.gserviceaccount.com"
      role    = "roles/container.defaultNodeServiceAgent"
    }
  }
  platform_service_agents = merge({
    for name, config in local.primary_service_agents : name => {
      service = config.service
      email   = google_project_service_identity.required[name].email
      member  = google_project_service_identity.required[name].member
      role    = config.role
    }
    }, {
    for name, config in local.activation_service_agents : name => {
      service = config.service
      email   = config.email
      member  = "serviceAccount:${config.email}"
      role    = config.role
    }
  })
}

resource "google_project_service_identity" "required" {
  for_each = local.primary_service_agents
  provider = google-beta

  project = data.google_project.customer.project_id
  service = each.value.service

  lifecycle {
    postcondition {
      condition     = self.email == each.value.email && self.member == "serviceAccount:${each.value.email}"
      error_message = "The generated identity must match the selected service agent in the customer project."
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "service_agents" {
  for_each = local.platform_service_agents

  project = data.google_project.customer.project_id
  role    = each.value.role
  member  = each.value.member

  # Retained resources and other data planes can still require these platform grants.
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.required]
}
