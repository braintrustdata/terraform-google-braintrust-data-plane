mock_provider "google" {
  mock_data "google_project" {
    defaults = {
      project_id = "customer-project"
      number     = "123456789012"
    }
  }

  mock_resource "google_cloud_quotas_quota_preference" {
    defaults = {
      reconciling = true
      quota_config = {
        granted_value = "250"
        state_detail  = "Approval pending"
        trace_id      = "test-trace"
      }
    }
  }

  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/customer-project/serviceAccounts/test-account@customer-project.iam.gserviceaccount.com"
      email = "test-account@customer-project.iam.gserviceaccount.com"
    }
  }

  mock_resource "google_project_iam_custom_role" {
    defaults = {
      name = "projects/customer-project/roles/mockRole"
    }
  }
}

variables {
  project_id                        = "customer-project"
  project_number                    = "123456789012"
  region                            = "us-central1"
  bootstrap_id                      = "bsp_019d1234-8abc-7def-8123-456789abc111"
  braintrust_bridge_service_account = "bootstrap-bridge@braintrust-byoc-staging.iam.gserviceaccount.com"
  request_quotas                    = true
  quota_contact_email               = "cloud-admin@customer.example"
}

run "v1_targets_as_terraform" {
  command = plan

  assert {
    condition = (
      length(google_cloud_quotas_quota_preference.requested) == 2 &&
      google_cloud_quotas_quota_preference.requested["c4-vcpus"].quota_config[0].preferred_value == "500" &&
      google_cloud_quotas_quota_preference.requested["c4-local-ssd-gb"].quota_config[0].preferred_value == "22500"
    )
    error_message = "The default targets must preserve the v1 CPU and Local SSD values."
  }

  assert {
    condition = alltrue([for preference in google_cloud_quotas_quota_preference.requested :
      preference.parent == "projects/123456789012" && preference.service == "compute.googleapis.com" &&
      preference.dimensions == tomap({ region = "us-central1", vm_family = "C4" }) &&
      preference.ignore_safety_checks == "QUOTA_SAFETY_CHECK_UNSPECIFIED"
    ])
    error_message = "Requests must use the exact project and dimensions and preserve Google safety checks."
  }
}

run "customer_target_override" {
  command = plan

  variables {
    quota_preferences = {
      cpu = {
        quota_id        = "CPUS-PER-VM-FAMILY-per-project-region"
        preferred_value = 750
        dimensions      = { vm_family = "c4" }
      }
    }
  }

  assert {
    condition = (
      length(google_cloud_quotas_quota_preference.requested) == 1 &&
      google_cloud_quotas_quota_preference.requested["cpu"].quota_config[0].preferred_value == "750"
    )
    error_message = "An explicit override must replace the v1 target map."
  }
}

run "reject_missing_contact" {
  command = plan

  variables {
    quota_contact_email = null
  }

  expect_failures = [var.quota_contact_email]
}

run "reject_fractional_quota" {
  command = plan

  variables {
    quota_preferences = {
      cpu = { quota_id = "CPUS-PER-VM-FAMILY-per-project-region", preferred_value = 1.5 }
    }
  }

  expect_failures = [var.quota_preferences]
}

run "reject_region_override" {
  command = plan

  variables {
    quota_preferences = {
      cpu = {
        quota_id        = "CPUS-PER-VM-FAMILY-per-project-region"
        preferred_value = 750
        dimensions      = { region = "europe-west1" }
      }
    }
  }

  expect_failures = [var.quota_preferences]
}

run "pending_approval_is_visible" {
  command = apply

  assert {
    condition = (
      output.quota_preferences["c4-vcpus"].requested_value == "500" &&
      output.quota_preferences["c4-vcpus"].granted_value == "250" &&
      output.quota_preferences["c4-vcpus"].reconciling &&
      output.quota_preferences["c4-vcpus"].state_detail == "Approval pending"
    )
    error_message = "A successful request must keep pending approval and the lower granted value visible."
  }
}

run "reject_duplicate_quota_dimensions" {
  command = plan

  variables {
    quota_preferences = {
      cpu = {
        quota_id        = "CPUS-PER-VM-FAMILY-per-project-region"
        preferred_value = 500
        dimensions      = { vm_family = "c4" }
      }
      same-cpu = {
        quota_id        = "CPUS-PER-VM-FAMILY-per-project-region"
        preferred_value = 750
        dimensions      = { vm_family = "C4" }
      }
    }
  }

  expect_failures = [var.quota_preferences]
}
