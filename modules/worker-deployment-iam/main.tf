locals {
  firewall_role = jsondecode(file("${path.module}/../../managed-byoc/custom-roles/braintrustIsolatedWorkerFirewall.json"))
}

resource "google_project_iam_custom_role" "firewall" {
  project     = var.project_id
  role_id     = "braintrustIsolatedWorkerFirewall_${substr(sha256(var.deployment_name), 0, 12)}"
  title       = local.firewall_role.title
  description = local.firewall_role.description
  stage       = local.firewall_role.stage
  permissions = local.firewall_role.includedPermissions
}

resource "google_project_iam_member" "firewall" {
  project = var.project_id
  role    = google_project_iam_custom_role.firewall.name
  member  = "serviceAccount:${var.deploy_service_account_email}"

  # An existing broad grant can be moved here and replaced without revoking
  # custom-role administration before the narrow role is created and granted.
  lifecycle {
    create_before_destroy = true
  }
}
