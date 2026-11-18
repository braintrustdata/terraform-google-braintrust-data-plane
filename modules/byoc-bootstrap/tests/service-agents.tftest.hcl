mock_provider "google" {
  override_during = plan
  mock_data "google_project" {
    defaults = { project_id = "customer-project", number = "123456789012" }
  }
  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/customer-project/serviceAccounts/deployment@customer-project.iam.gserviceaccount.com"
      email = "deployment@customer-project.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_project_iam_custom_role" {
    defaults = { name = "projects/customer-project/roles/mockRole" }
  }
}
mock_provider "google-beta" {
  override_during = plan
}

override_resource {
  override_during = plan
  target          = google_project_service_identity.required["gke"]
  values = {
    email  = "service-123456789012@container-engine-robot.iam.gserviceaccount.com"
    member = "serviceAccount:service-123456789012@container-engine-robot.iam.gserviceaccount.com"
  }
}
override_resource {
  override_during = plan
  target          = google_project_service_identity.required["redis"]
  values = {
    email  = "service-123456789012@cloud-redis.iam.gserviceaccount.com"
    member = "serviceAccount:service-123456789012@cloud-redis.iam.gserviceaccount.com"
  }
}
override_resource {
  override_during = plan
  target          = google_project_service_identity.required["networking"]
  values = {
    email  = "service-123456789012@service-networking.iam.gserviceaccount.com"
    member = "serviceAccount:service-123456789012@service-networking.iam.gserviceaccount.com"
  }
}
override_resource {
  override_during = plan
  target          = google_project_service_identity.required["dns"]
  values = {
    email  = "service-123456789012@gcp-sa-dns.iam.gserviceaccount.com"
    member = "serviceAccount:service-123456789012@gcp-sa-dns.iam.gserviceaccount.com"
  }
}

variables {
  project_id                        = "customer-project"
  project_number                    = "123456789012"
  region                            = "us-central1"
  bootstrap_id                      = "bsp_019d1234-8abc-7def-8123-456789abc111"
  braintrust_bridge_service_account = "bootstrap-bridge@braintrust-byoc-staging.iam.gserviceaccount.com"
}

run "required_api_coverage" {
  command = plan
  assert {
    condition = alltrue([for service in [
      "compute.googleapis.com", "container.googleapis.com", "sqladmin.googleapis.com", "redis.googleapis.com", "storage.googleapis.com",
      "cloudkms.googleapis.com", "secretmanager.googleapis.com", "servicenetworking.googleapis.com", "dns.googleapis.com",
      "iam.googleapis.com", "cloudresourcemanager.googleapis.com", "serviceusage.googleapis.com", "iamcredentials.googleapis.com",
      "sts.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com", "artifactregistry.googleapis.com"
    ] : contains(keys(google_project_service.required), service)])
    error_message = "The API catalog must cover default resources, native authentication, and optional Loop dependencies."
  }
  assert {
    condition = length(setintersection(toset(keys(google_project_service.required)), toset([
      "cloudquotas.googleapis.com", "oslogin.googleapis.com", "vpcaccess.googleapis.com", "cloudsupport.googleapis.com",
      "autoscaling.googleapis.com", "storage-api.googleapis.com", "storage-component.googleapis.com"
    ]))) == 0
    error_message = "The default API set must exclude Cloud Quotas and services outside the bootstrap requirements."
  }
  assert {
    condition = (
      alltrue([for service in google_project_service.required : !service.disable_on_destroy && !service.disable_dependent_services]) &&
      toset(output.bootstrap.required_apis) == toset(keys(google_project_service.required))
    )
    error_message = "The output must identify managed APIs, and removal must not request API disablement."
  }
}

run "primary_identities_and_platform_grants" {
  command = plan
  assert {
    condition = (
      toset(keys(google_project_service_identity.required)) == toset(["gke", "redis", "networking", "dns"]) &&
      alltrue([for identity in google_project_service_identity.required : identity.project == "customer-project"]) &&
      google_project_service_identity.required["networking"].service == "servicenetworking.googleapis.com" &&
      google_project_service_identity.required["dns"].service == "dns.googleapis.com"
    )
    error_message = "Explicit primary identities must target their exact customer project and service."
  }
  assert {
    condition = (
      toset(keys(google_project_iam_member.service_agents)) == toset(["compute", "gke", "gke_node", "redis", "networking", "dns"]) &&
      alltrue([for grant in google_project_iam_member.service_agents :
        grant.project == "customer-project" && startswith(grant.member, "serviceAccount:service-123456789012@") &&
        !contains(["roles/owner", "roles/editor", "roles/serviceusage.serviceUsageAdmin"], grant.role)
      ]) &&
      google_project_iam_member.service_agents["compute"].member == "serviceAccount:service-123456789012@compute-system.iam.gserviceaccount.com" &&
      google_project_iam_member.service_agents["compute"].role == "roles/compute.serviceAgent" &&
      google_project_iam_member.service_agents["gke"].role == "roles/container.serviceAgent" &&
      google_project_iam_member.service_agents["gke_node"].member == "serviceAccount:service-123456789012@gcp-sa-gkenode.iam.gserviceaccount.com" &&
      google_project_iam_member.service_agents["gke_node"].role == "roles/container.defaultNodeServiceAgent" &&
      google_project_iam_member.service_agents["redis"].role == "roles/redis.serviceAgent" &&
      google_project_iam_member.service_agents["networking"].role == "roles/servicenetworking.serviceAgent" &&
      google_project_iam_member.service_agents["dns"].role == "roles/dns.serviceAgent"
    )
    error_message = "Only the selected Google-managed service agents receive their matching platform roles."
  }
  assert {
    condition = (
      toset(keys(output.bootstrap.service_agents)) == toset(["compute", "gke", "gke_node", "redis", "networking", "dns", "storage"]) &&
      !contains(keys(output.bootstrap.service_agents), "sql") &&
      length(output.bootstrap.service_agents.storage.project_roles) == 0 &&
      !output.bootstrap.issuable && !output.bootstrap.machine_execution_supported
    )
    error_message = "Registration metadata must include agent references without a general Storage agent project grant or a ready status."
  }
}

run "quota_api_requires_opt_in" {
  command = plan
  variables {
    request_quotas      = true
    quota_contact_email = "cloud-admin@customer.example"
  }
  assert {
    condition     = contains(keys(google_project_service.required), "cloudquotas.googleapis.com") && length(google_cloud_quotas_quota_preference.requested) == 2
    error_message = "Native quota preferences must enable their API only after explicit opt-in."
  }
}

run "reject_wrong_service_identity" {
  command = plan
  override_resource {
    override_during = plan
    target          = google_project_service_identity.required["dns"]
    values = {
      email  = "unexpected@customer-project.iam.gserviceaccount.com"
      member = "serviceAccount:unexpected@customer-project.iam.gserviceaccount.com"
    }
  }
  expect_failures = [google_project_service_identity.required["dns"]]
}

run "reject_wrong_identity_project" {
  command = plan
  override_resource {
    override_during = plan
    target          = google_project_service_identity.required["redis"]
    values = {
      email  = "service-555555555555@cloud-redis.iam.gserviceaccount.com"
      member = "serviceAccount:service-555555555555@cloud-redis.iam.gserviceaccount.com"
    }
  }
  expect_failures = [google_project_service_identity.required["redis"]]
}

run "reject_missing_identity_member" {
  command = plan
  override_resource {
    override_during = plan
    target          = google_project_service_identity.required["gke"]
    values = {
      email  = "service-123456789012@container-engine-robot.iam.gserviceaccount.com"
      member = ""
    }
  }
  expect_failures = [google_project_service_identity.required["gke"]]
}
