mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      project_id = "customer-project"
      number     = "123456789012"
    }
  }
}

variables {
  project_id                        = "customer-project"
  project_number                    = "123456789012"
  region                            = "us-central1"
  bootstrap_id                      = "bsp_019d1234-8abc-7def-8123-456789abc111"
  braintrust_bridge_service_account = "bootstrap-bridge@braintrust-byoc-staging.iam.gserviceaccount.com"
}

run "default_foundation" {
  command = plan

  assert {
    condition     = length(google_cloud_quotas_quota_preference.requested) == 0
    error_message = "Quota requests must require an explicit Terraform input."
  }

  assert {
    condition     = length(google_service_account.bootstrap) == 3 && contains(keys(google_service_account.bootstrap), "diagnostics")
    error_message = "The default must create a separate dormant Diagnostics account."
  }

  assert {
    condition = alltrue([
      google_storage_bucket.state.deletion_policy == "ABANDON",
      google_storage_bucket.evidence.deletion_policy == "ABANDON",
      !google_storage_bucket.state.force_destroy,
      !google_storage_bucket.evidence.force_destroy,
      google_storage_bucket.state.versioning[0].enabled,
      google_storage_bucket.evidence.versioning[0].enabled,
      google_storage_bucket.state.uniform_bucket_level_access,
      google_storage_bucket.evidence.uniform_bucket_level_access,
      google_storage_bucket.state.public_access_prevention == "enforced",
      google_storage_bucket.evidence.public_access_prevention == "enforced",
    ])
    error_message = "Bootstrap removal must preserve both private, versioned storage buckets."
  }

  assert {
    condition     = alltrue([for service in google_project_service.required : !service.disable_on_destroy && !service.disable_dependent_services])
    error_message = "Bootstrap removal must leave the required APIs enabled."
  }

  assert {
    condition = (
      google_service_account_iam_member.deployment_bridge.member == "serviceAccount:bootstrap-bridge@braintrust-byoc-staging.iam.gserviceaccount.com" &&
      google_service_account_iam_member.observer_group.member == "group:byoc-support@braintrustdata.com" &&
      google_service_account_iam_member.deployment_bridge.role == "roles/iam.serviceAccountTokenCreator"
    )
    error_message = "Trust must use the exact assigned bridge and support group."
  }

  assert {
    condition = alltrue([
      for permission in google_project_iam_custom_role.foundation["observer"].permissions :
      can(regex("\\.(get|list)$", permission)) && !can(regex("^(storage|secretmanager|iam|logging)\\.", permission))
    ])
    error_message = "Observer permissions must exclude content access and mutation authority."
  }

  assert {
    condition = toset(google_project_iam_custom_role.foundation["evidence"].permissions) == toset([
      "storage.buckets.get", "storage.objects.create", "storage.objects.list",
    ])
    error_message = "Evidence permissions must exclude content reads, replacement, and deletion."
  }

  assert {
    condition = (
      output.bootstrap.contract_status == "draft" && !output.bootstrap.issuable &&
      !output.bootstrap.machine_execution_supported && !output.bootstrap.diagnostics_activation_supported
    )
    error_message = "The candidate must not advertise accepted issuance or execution."
  }

  assert {
    condition = (
      google_storage_bucket.state.name != google_storage_bucket.evidence.name &&
      output.bootstrap.state.prefix != output.bootstrap.evidence.prefix &&
      google_storage_bucket_iam_member.state.bucket == google_storage_bucket.state.name &&
      google_storage_bucket_iam_member.evidence.bucket == google_storage_bucket.evidence.name
    )
    error_message = "State and evidence grants must use separate storage destinations."
  }
}

run "diagnostics_opt_out" {
  command = plan

  variables {
    enable_diagnostics = false
  }

  assert {
    condition     = length(google_service_account.bootstrap) == 2 && !contains(keys(google_service_account.bootstrap), "diagnostics")
    error_message = "Explicit opt-out must omit the Diagnostics account."
  }

  assert {
    condition     = !output.bootstrap.enable_diagnostics && output.bootstrap.diagnostics_service_account == null
    error_message = "The output must report absent Diagnostics."
  }
}

run "different_bootstrap_namespace" {
  command = plan

  variables {
    bootstrap_id = "bsp_019d1234-8abc-7def-8123-456789abc222"
  }

  assert {
    condition     = output.bootstrap.state.bucket != run.default_foundation.bootstrap.state.bucket
    error_message = "Different bootstrap IDs must produce different storage names."
  }
}

run "reject_project_number_mismatch" {
  command = plan

  variables {
    project_number = "555555555555"
  }

  expect_failures = [data.google_project.customer]
}

run "reject_customer_hosted_bridge" {
  command = plan

  variables {
    braintrust_bridge_service_account = "bootstrap-bridge@customer-project.iam.gserviceaccount.com"
  }

  expect_failures = [data.google_project.customer]
}

run "reject_public_bridge_principal" {
  command = plan

  variables {
    braintrust_bridge_service_account = "allUsers"
  }

  expect_failures = [var.braintrust_bridge_service_account]
}

run "reject_reserved_label_override" {
  command = plan

  variables {
    labels = { braintrust_bootstrap = "another-bootstrap" }
  }

  expect_failures = [var.labels]
}
