locals {
  suffix = substr(sha256("${var.project_id}/${var.bootstrap_id}"), 0, 16)
  service_accounts = merge({
    deployment = "bt-${local.suffix}-deploy"
    observer   = "bt-${local.suffix}-observe"
  }, var.enable_diagnostics ? { diagnostics = "bt-${local.suffix}-diag" } : {})
  labels = merge(var.labels, { braintrust_bootstrap = var.bootstrap_id })
  services = toset(concat(
    jsondecode(file("${path.module}/data/services.json")),
    ["serviceusage.googleapis.com"],
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

resource "google_service_account_iam_member" "deployment_bridge" {
  service_account_id = google_service_account.bootstrap["deployment"].name
  role               = local.impersonation_role
  member             = "serviceAccount:${var.braintrust_bridge_service_account}"
}

resource "google_service_account_iam_member" "observer_group" {
  service_account_id = google_service_account.bootstrap["observer"].name
  role               = local.impersonation_role
  member             = local.observer_principal
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

resource "google_project_iam_member" "observer" {
  project = data.google_project.customer.project_id
  role    = google_project_iam_custom_role.foundation["observer"].name
  member  = "serviceAccount:${google_service_account.bootstrap["observer"].email}"
}

resource "google_storage_bucket" "state" {
  project                     = data.google_project.customer.project_id
  name                        = "bt-${var.project_number}-${local.suffix}-state"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  deletion_policy             = "ABANDON"
  labels                      = local.labels

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket" "evidence" {
  project                     = data.google_project.customer.project_id
  name                        = "bt-${var.project_number}-${local.suffix}-evidence"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  deletion_policy             = "ABANDON"
  labels                      = local.labels

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket_iam_member" "state" {
  bucket = google_storage_bucket.state.name
  role   = google_project_iam_custom_role.foundation["state"].name
  member = "serviceAccount:${google_service_account.bootstrap["deployment"].email}"
}

resource "google_storage_bucket_iam_member" "evidence" {
  bucket = google_storage_bucket.evidence.name
  role   = google_project_iam_custom_role.foundation["evidence"].name
  member = "serviceAccount:${google_service_account.bootstrap["deployment"].email}"
}
