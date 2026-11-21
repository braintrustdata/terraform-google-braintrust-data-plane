mock_provider "google" {
  mock_data "google_client_config" {
    defaults = { region = "us-central1", project = "braintrust-test" }
  }
  mock_data "google_project" {
    defaults = { project_id = "braintrust-test", number = "123456789012" }
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
    discovery          = { dns_name = "sandbox.example.internal", runtime_source_ranges = ["10.20.0.0/20"] }
  }
}

run "terraform_owned_permissions_preserve_dns_and_custom_identity" {
  command = apply
  module { source = "./modules/gke-isolated-workers-network" }
  variables {
    deploy_service_account_email = "custom-deploy@braintrust-test.iam.gserviceaccount.com"
  }
  assert {
    condition = (
      length(google_project_iam_custom_role.worker_firewall) == 1 &&
      google_project_iam_custom_role.worker_firewall[0].project == "braintrust-test" &&
      google_project_iam_custom_role.worker_firewall[0].role_id == "braintrustIsolatedWorkerFirewall_${substr(sha256("braintrust"), 0, 12)}" &&
      google_project_iam_custom_role.worker_firewall[0].permissions == toset([
        "compute.firewalls.create", "compute.firewalls.get",
        "compute.firewalls.update", "compute.firewalls.delete",
        "compute.globalOperations.get", "compute.networks.updatePolicy",
      ]) &&
      google_project_iam_member.worker_firewall[0].role == google_project_iam_custom_role.worker_firewall[0].name &&
      google_project_iam_member.worker_firewall[0].project == "braintrust-test" &&
      google_project_iam_member.worker_firewall[0].member == "serviceAccount:custom-deploy@braintrust-test.iam.gserviceaccount.com" &&
      length(google_project_iam_custom_role.isolated_dns_records) == 1 &&
      length(google_project_iam_custom_role.isolated_dns_zone_list) == 1
    )
    error_message = "Terraform-owned access must preserve DNS roles and grant only deployment-specific firewall permissions to the supplied identity."
  }
}

run "bootstrap_owned_permissions_leave_existing_dns_roles_managed" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  assert {
    condition = (
      length(google_project_iam_custom_role.worker_firewall) == 0 &&
      length(google_project_iam_member.worker_firewall) == 0 &&
      length(google_project_iam_custom_role.isolated_dns_records) == 1 &&
      length(google_project_iam_custom_role.isolated_dns_zone_list) == 1
    )
    error_message = "Omission must not take over bootstrap IAM or change legacy DNS role ownership."
  }
}
