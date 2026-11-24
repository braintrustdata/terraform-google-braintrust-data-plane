mock_provider "google" {
  mock_data "google_client_config" {
    defaults = { project = "braintrust-test", region = "us-central1" }
  }
  mock_data "google_project" {
    defaults = { number = "123456789012" }
  }
}

variables {
  deployment_name = "braintrust"
  network         = "projects/braintrust-test/global/networks/primary"
  primary_subnet  = "projects/braintrust-test/regions/us-central1/subnetworks/primary"
  config = {
    node_cidr          = "10.60.0.0/24"
    pod_cidr           = "10.64.0.0/18"
    service_cidr       = "10.65.0.0/22"
    control_plane_cidr = "10.60.1.0/28"
    discovery          = { dns_name = "test.isolated.internal", runtime_source_ranges = ["10.20.0.0/20"] }
  }
}

run "bootstrap_roles_take_precedence_over_legacy_roles" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  override_data {
    target = data.google_project_iam_custom_roles.isolated_dns[0]
    values = {
      roles = [
        { name = "projects/braintrust-test/roles/braintrustIsolatedDnsList", deleted = false, stage = "GA" },
        { name = "projects/braintrust-test/roles/braintrustIsolatedDnsRecords", deleted = false, stage = "GA" },
        { name = "projects/braintrust-test/roles/isolatedDnsList_c0a49b8a7265", deleted = false, stage = "GA" },
        { name = "projects/braintrust-test/roles/isolatedDnsRecords_c0a49b8a7265", deleted = false, stage = "GA" },
      ]
    }
  }
  assert {
    condition = (
      google_project_iam_member.isolated_dns_zone_list[0].role == "projects/braintrust-test/roles/braintrustIsolatedDnsList" &&
      google_dns_managed_zone_iam_member.isolated_external_dns[0].role == "projects/braintrust-test/roles/braintrustIsolatedDnsRecords"
    )
    error_message = "Bootstrap roles must be selected automatically when both pairs exist."
  }
}

run "existing_deployment_keeps_its_legacy_roles" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  variables { deployment_name = "custom-deployment" }
  override_data {
    target = data.google_project_iam_custom_roles.isolated_dns[0]
    values = {
      roles = [
        { name = "projects/braintrust-test/roles/isolatedDnsList_4ce13448bff2", deleted = false, stage = "GA" },
        { name = "projects/braintrust-test/roles/isolatedDnsRecords_4ce13448bff2", deleted = false, stage = "GA" },
      ]
    }
  }
  assert {
    condition = (
      google_project_iam_member.isolated_dns_zone_list[0].role == "projects/braintrust-test/roles/isolatedDnsList_4ce13448bff2" &&
      google_dns_managed_zone_iam_member.isolated_external_dns[0].role == "projects/braintrust-test/roles/isolatedDnsRecords_4ce13448bff2"
    )
    error_message = "Upgrades must retain the deployment's legacy role pair without another bootstrap run."
  }
}

run "deleted_bootstrap_role_falls_back_to_legacy_pair" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  override_data {
    target = data.google_project_iam_custom_roles.isolated_dns[0]
    values = {
      roles = [
        { name = "projects/braintrust-test/roles/braintrustIsolatedDnsList", deleted = true, stage = "GA" },
        { name = "projects/braintrust-test/roles/braintrustIsolatedDnsRecords", deleted = false, stage = "GA" },
        { name = "projects/braintrust-test/roles/isolatedDnsList_c0a49b8a7265", deleted = false, stage = "GA" },
        { name = "projects/braintrust-test/roles/isolatedDnsRecords_c0a49b8a7265", deleted = false, stage = "GA" },
      ]
    }
  }
  assert {
    condition = (
      google_project_iam_member.isolated_dns_zone_list[0].role == local.legacy_dns_roles.zone_list &&
      google_dns_managed_zone_iam_member.isolated_external_dns[0].role == local.legacy_dns_roles.records
    )
    error_message = "Deleted roles must not displace a working legacy pair."
  }
}

run "disabled_role_cannot_complete_a_pair" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  override_data {
    target = data.google_project_iam_custom_roles.isolated_dns[0]
    values = {
      roles = [
        { name = "projects/braintrust-test/roles/braintrustIsolatedDnsList", deleted = false, stage = "GA" },
        { name = "projects/braintrust-test/roles/braintrustIsolatedDnsRecords", deleted = false, stage = "DISABLED" },
      ]
    }
  }
  expect_failures = [google_project_iam_member.isolated_dns_zone_list]
}

run "fresh_project_needs_no_custom_role_bootstrap" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  override_data {
    target = data.google_project_iam_custom_roles.isolated_dns[0]
    values = { roles = [] }
  }
  assert {
    condition = (
      google_project_iam_member.isolated_dns_zone_list[0].role == "roles/dns.reader" &&
      google_dns_managed_zone_iam_member.isolated_external_dns[0].role == "roles/dns.admin" &&
      google_dns_managed_zone_iam_member.isolated_external_dns[0].managed_zone == google_dns_managed_zone.discovery[0].name &&
      google_project_service.dns[0].service == "dns.googleapis.com"
    )
    error_message = "Fresh projects must enable DNS and use built-in read access plus administration scoped to the discovery zone, without a separate bootstrap."
  }
}

run "partial_pairs_cannot_be_mixed" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  override_data {
    target = data.google_project_iam_custom_roles.isolated_dns[0]
    values = {
      roles = [
        { name = "projects/braintrust-test/roles/braintrustIsolatedDnsList", deleted = false, stage = "GA" },
        { name = "projects/braintrust-test/roles/isolatedDnsRecords_c0a49b8a7265", deleted = false, stage = "GA" },
      ]
    }
  }
  expect_failures = [google_project_iam_member.isolated_dns_zone_list]
}

run "explicit_builtin_roles_need_no_custom_role_lookup" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  variables { existing_dns_roles = { zone_list = "roles/dns.reader", records = "roles/dns.admin" } }
  assert {
    condition = (
      length(data.google_project_iam_custom_roles.isolated_dns) == 0 &&
      google_project_iam_member.isolated_dns_zone_list[0].role == "roles/dns.reader" &&
      google_dns_managed_zone_iam_member.isolated_external_dns[0].role == "roles/dns.admin"
    )
    error_message = "Explicit built-in DNS roles must work without discovering or managing custom role definitions."
  }
}

run "discovery_off_does_not_read_roles_or_create_grants" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  variables {
    config = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
    }
  }
  assert {
    condition = (
      length(data.google_project_iam_custom_roles.isolated_dns) == 0 &&
      length(google_project_service.dns) == 0 &&
      length(google_project_iam_member.isolated_dns_zone_list) == 0 &&
      length(google_dns_managed_zone_iam_member.isolated_external_dns) == 0
    )
    error_message = "Discovery off must not look up DNS roles or grant DNS access."
  }
}
