locals {
  v1_quota_preferences = {
    for quota in jsondecode(file("${path.module}/data/quota-defaults.json")) :
    trim(replace(lower(quota.name), "/[^a-z0-9]+/", "-"), "-") => {
      quota_id        = quota.quota_id
      preferred_value = quota.desired_value
      dimensions      = quota.dimensions
    }
  }
  quota_preferences = var.quota_preferences == null ? local.v1_quota_preferences : var.quota_preferences
}

resource "google_cloud_quotas_quota_preference" "requested" {
  for_each = var.request_quotas ? local.quota_preferences : {}

  parent               = "projects/${data.google_project.customer.number}"
  service              = "compute.googleapis.com"
  quota_id             = each.value.quota_id
  contact_email        = var.quota_contact_email
  ignore_safety_checks = "QUOTA_SAFETY_CHECK_UNSPECIFIED"
  justification        = "Braintrust managed BYOC data plane deployment requires GKE node pools with headroom for autoscaling."
  dimensions = merge({
    for key, value in each.value.dimensions : key => key == "vm_family" ? upper(value) : value
  }, { region = var.region })
  quota_config {
    preferred_value = tostring(each.value.preferred_value)
  }

  depends_on = [google_project_service.required]
}

output "quota_preferences" {
  description = "Requested values and observed quota preference status. These values do not establish deployment capacity."
  value = {
    for key, preference in google_cloud_quotas_quota_preference.requested : key => {
      name            = preference.name
      quota_id        = preference.quota_id
      dimensions      = preference.dimensions
      requested_value = preference.quota_config[0].preferred_value
      granted_value   = preference.quota_config[0].granted_value
      reconciling     = preference.reconciling
      state_detail    = preference.quota_config[0].state_detail
      trace_id        = preference.quota_config[0].trace_id
    }
  }
}
