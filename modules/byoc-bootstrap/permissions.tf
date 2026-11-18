# Shared role resources define the foundation roles.
# Identity-specific files define the permission lists and grants.
locals {
  foundation_roles = {
    observer = { permissions = local.observer_permissions }
    state    = { permissions = local.deployment_state_permissions }
    evidence = { permissions = local.deployment_evidence_permissions }
  }
}

resource "google_project_iam_custom_role" "foundation" {
  for_each = local.foundation_roles

  project     = data.google_project.customer.project_id
  role_id     = "bt_${local.suffix}_${each.key}"
  title       = "Braintrust bootstrap ${each.key}"
  description = "Draft bootstrap foundation permissions."
  permissions = each.value.permissions
  depends_on  = [google_project_service.required]
}
