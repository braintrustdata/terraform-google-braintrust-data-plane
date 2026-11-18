locals {
  suffix = substr(sha256("${var.project_id}/${var.bootstrap_id}"), 0, 16)
  service_accounts = merge({
    deployment = "bt-${local.suffix}-deploy"
    observer   = "bt-${local.suffix}-observe"
  }, var.enable_diagnostics ? { diagnostics = "bt-${local.suffix}-diag" } : {})
  labels = merge(var.labels, { braintrust_bootstrap = var.bootstrap_id })
  services = toset(concat(
    jsondecode(file("${path.module}/data/services.json")),
    var.request_quotas ? ["cloudquotas.googleapis.com"] : [],
  ))
}

data "google_project" "customer" {
  project_id = var.project_id

  lifecycle {
    postcondition {
      condition     = tostring(self.number) == var.project_number
      error_message = "The project number does not match the selected customer project."
    }
    postcondition {
      condition     = !endswith(var.braintrust_bridge_service_account, "@${var.project_id}.iam.gserviceaccount.com")
      error_message = "The Braintrust bridge must belong to a separate project."
    }
  }
}

resource "google_project_service" "required" {
  for_each = local.services

  project                    = data.google_project.customer.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

data "google_storage_project_service_account" "customer" {
  project    = data.google_project.customer.project_id
  depends_on = [google_project_service.required]
}

resource "google_service_account" "bootstrap" {
  for_each = local.service_accounts

  project      = data.google_project.customer.project_id
  account_id   = each.value
  display_name = "Braintrust ${each.key} (${var.bootstrap_id})"
  description  = "Customer bootstrap account for ${each.key}."

  # A customer can disable an account independently. Reapply must not enable it.
  lifecycle {
    ignore_changes = [disabled]
  }

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket" "state" {
  project                     = data.google_project.customer.project_id
  name                        = "bt-${var.project_number}-${local.suffix}-state"
  location                    = upper(local.storage["state"].location)
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  deletion_policy             = "ABANDON"
  labels                      = local.labels

  dynamic "custom_placement_config" {
    for_each = length(local.storage["state"].data_locations) == 0 ? [] : [local.storage["state"].data_locations]
    content {
      data_locations = [for location in custom_placement_config.value : upper(location)]
    }
  }

  encryption {
    default_kms_key_name = local.storage_keys["state"]
  }

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required, google_kms_crypto_key_iam_member.storage_service_agent]
}

resource "google_storage_bucket" "evidence" {
  project                     = data.google_project.customer.project_id
  name                        = "bt-${var.project_number}-${local.suffix}-evidence"
  location                    = upper(local.storage["evidence"].location)
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  deletion_policy             = "ABANDON"
  labels                      = local.labels

  dynamic "custom_placement_config" {
    for_each = length(local.storage["evidence"].data_locations) == 0 ? [] : [local.storage["evidence"].data_locations]
    content {
      data_locations = [for location in custom_placement_config.value : upper(location)]
    }
  }

  encryption {
    default_kms_key_name = local.storage_keys["evidence"]
  }

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required, google_kms_crypto_key_iam_member.storage_service_agent]
}
