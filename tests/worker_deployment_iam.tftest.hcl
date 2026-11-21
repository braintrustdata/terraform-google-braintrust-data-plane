mock_provider "google" {
  mock_data "google_client_config" {
    defaults = { region = "us-central1", project = "braintrust-test" }
  }
  mock_data "google_project" {
    defaults = { project_id = "braintrust-test", number = "123456789012" }
  }
  mock_data "google_project_iam_custom_roles" {
    defaults = {
      roles = [
        { name = "projects/braintrust-test/roles/braintrustIsolatedDnsList", deleted = false, stage = "GA" },
        { name = "projects/braintrust-test/roles/braintrustIsolatedDnsRecords", deleted = false, stage = "GA" },
      ]
    }
  }
}

run "shared_firewall_role_matches_bootstrap_and_custom_identity" {
  command = apply
  module { source = "./modules/worker-deployment-iam" }
  variables {
    deployment_name              = "braintrust"
    project_id                   = "braintrust-test"
    deploy_service_account_email = "custom-deploy@braintrust-test.iam.gserviceaccount.com"
  }
  assert {
    condition = (
      google_project_iam_custom_role.firewall.project == "braintrust-test" &&
      google_project_iam_custom_role.firewall.role_id == "braintrustIsolatedWorkerFirewall_${substr(sha256("braintrust"), 0, 12)}" &&
      google_project_iam_custom_role.firewall.permissions == toset([
        "compute.firewalls.create", "compute.firewalls.get",
        "compute.firewalls.update", "compute.firewalls.delete",
        "compute.globalOperations.get", "compute.networks.updatePolicy",
      ]) &&
      google_project_iam_member.firewall.role == google_project_iam_custom_role.firewall.name &&
      google_project_iam_member.firewall.project == "braintrust-test" &&
      google_project_iam_member.firewall.member == "serviceAccount:custom-deploy@braintrust-test.iam.gserviceaccount.com"
    )
    error_message = "Shared IAM must grant only the released firewall permissions to the supplied deployment identity."
  }
}

run "bootstrap_owned_firewall_permissions_use_discovered_dns_roles" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  variables {
    deployment_name = "braintrust"
    network         = "projects/braintrust-test/global/networks/primary"
    primary_subnet  = "projects/braintrust-test/regions/us-central1/subnetworks/primary"
    config = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
      discovery          = { dns_name = "sandbox.example.internal", runtime_source_ranges = ["10.20.0.0/20"] }
    }
  }
  assert {
    condition = (
      length(module.deployment_iam) == 0 &&
      google_project_iam_member.isolated_dns_zone_list[0].role == "projects/braintrust-test/roles/braintrustIsolatedDnsList" &&
      google_dns_managed_zone_iam_member.isolated_external_dns[0].role == "projects/braintrust-test/roles/braintrustIsolatedDnsRecords"
    )
    error_message = "Omission must leave firewall IAM to bootstrap and discover the DNS role grants."
  }
}

run "terraform_owned_firewall_permissions_use_discovered_dns_roles" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  variables {
    deployment_name              = "braintrust"
    deploy_service_account_email = "deploy@braintrust-test.iam.gserviceaccount.com"
    network                      = "projects/braintrust-test/global/networks/primary"
    primary_subnet               = "projects/braintrust-test/regions/us-central1/subnetworks/primary"
    config = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
      discovery          = { dns_name = "sandbox.example.internal", runtime_source_ranges = ["10.20.0.0/20"] }
    }
  }
  assert {
    condition = (
      length(module.deployment_iam) == 1 &&
      google_project_iam_member.isolated_dns_zone_list[0].role == "projects/braintrust-test/roles/braintrustIsolatedDnsList" &&
      google_dns_managed_zone_iam_member.isolated_external_dns[0].role == "projects/braintrust-test/roles/braintrustIsolatedDnsRecords"
    )
    error_message = "Firewall IAM ownership must not affect the discovered DNS role grants."
  }
}
