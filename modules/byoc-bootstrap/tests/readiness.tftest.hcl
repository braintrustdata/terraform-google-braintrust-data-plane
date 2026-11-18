mock_provider "google-beta" {}

mock_provider "google" {
  override_during = plan

  mock_data "google_project" {
    defaults = { project_id = "customer-project", number = "123456789012" }
  }
  mock_resource "google_project_iam_custom_role" {
    defaults = { name = "projects/customer-project/roles/mockRole" }
  }
}

override_resource {
  override_during = plan
  target          = google_service_account.bootstrap["deployment"]
  values = {
    name  = "projects/customer-project/serviceAccounts/deployment@customer-project.iam.gserviceaccount.com"
    email = "deployment@customer-project.iam.gserviceaccount.com"
  }
}
override_resource {
  override_during = plan
  target          = google_service_account.bootstrap["observer"]
  values = {
    name  = "projects/customer-project/serviceAccounts/observer@customer-project.iam.gserviceaccount.com"
    email = "observer@customer-project.iam.gserviceaccount.com"
  }
}
override_resource {
  override_during = plan
  target          = google_service_account.bootstrap["diagnostics"]
  values = {
    name  = "projects/customer-project/serviceAccounts/diagnostics@customer-project.iam.gserviceaccount.com"
    email = "diagnostics@customer-project.iam.gserviceaccount.com"
  }
}

variables {
  project_id                        = "customer-project"
  project_number                    = "123456789012"
  region                            = "us-central1"
  bootstrap_id                      = "bsp_019d1234-8abc-7def-8123-456789abc111"
  braintrust_bridge_service_account = "bootstrap-bridge@braintrust-byoc-staging.iam.gserviceaccount.com"
}

override_resource {
  override_during = plan
  target          = google_kms_crypto_key.storage["state"]
  values          = { id = "projects/customer-project/locations/us-central1/keyRings/state/cryptoKeys/storage" }
}
override_resource {
  override_during = plan
  target          = google_kms_crypto_key.storage["evidence"]
  values          = { id = "projects/customer-project/locations/us-central1/keyRings/evidence/cryptoKeys/storage" }
}

run "default_readiness_grants" {
  command = plan
  assert {
    condition = (
      contains(google_project_iam_custom_role.foundation["state"].permissions, "storage.buckets.getIamPolicy") &&
      toset(google_project_iam_custom_role.foundation["evidence"].permissions) == toset(["storage.buckets.get", "storage.buckets.getIamPolicy", "storage.objects.create", "storage.objects.list"]) &&
      length(google_project_iam_custom_role.key_metadata) == 2 &&
      length(google_kms_crypto_key_iam_member.deployment_metadata) == 2 &&
      length(google_project_iam_custom_role.external_metadata) == 0 &&
      length(google_project_iam_member.external_metadata) == 0
    )
    error_message = "Default readiness must add exact bucket policies and key metadata without external project grants or evidence content access."
  }
  assert {
    condition = alltrue([for role in google_project_iam_custom_role.key_metadata :
      role.project == "customer-project" &&
      toset(role.permissions) == toset(["cloudkms.cryptoKeyVersions.get", "cloudkms.cryptoKeys.get", "cloudkms.cryptoKeys.getIamPolicy"])
      ]) && alltrue([for group, grant in google_kms_crypto_key_iam_member.deployment_metadata :
      grant.member == "serviceAccount:deployment@customer-project.iam.gserviceaccount.com" &&
      grant.role == google_project_iam_custom_role.key_metadata[group].name &&
      grant.crypto_key_id == local.storage_keys[local.storage_key_groups[group][0]]
    ])
    error_message = "Only Deployment receives read-only metadata on each selected key."
  }
}

run "shared_external_key_and_license" {
  command = plan
  variables {
    state_storage    = { location = "US", kms_key = "projects/key-project/locations/us/keyRings/customer/cryptoKeys/shared" }
    evidence_storage = { location = "US", kms_key = "projects/key-project/locations/us/keyRings/customer/cryptoKeys/shared" }
    license_secrets  = ["projects/license-project/secrets/license"]
  }
  override_data {
    target = data.google_kms_crypto_key.existing_storage["projects/key-project/locations/us/keyRings/customer/cryptoKeys/shared"]
    values = { purpose = "ENCRYPT_DECRYPT", primary = [{ name = "version", state = "ENABLED" }] }
  }
  assert {
    condition = (
      length(google_project_iam_custom_role.key_metadata) == 1 &&
      length(google_kms_crypto_key_iam_member.deployment_metadata) == 1 &&
      google_project_iam_custom_role.key_metadata["projects/key-project/locations/us/keyRings/customer/cryptoKeys/shared"].project == "key-project" &&
      toset(keys(google_project_iam_custom_role.external_metadata)) == toset(["key-project", "license-project"]) &&
      alltrue([for project, role in google_project_iam_custom_role.external_metadata :
        role.project == project && toset(role.permissions) == toset(["iam.roles.get", "resourcemanager.projects.get"])
      ]) &&
      alltrue([for project, grant in google_project_iam_member.external_metadata :
        grant.project == project && grant.role == google_project_iam_custom_role.external_metadata[project].name &&
        grant.member == "serviceAccount:deployment@customer-project.iam.gserviceaccount.com"
      ]) &&
      toset(google_project_iam_custom_role.license["license-project"].permissions) == toset(["secretmanager.secrets.get", "secretmanager.secrets.getIamPolicy", "secretmanager.versions.get", "secretmanager.versions.access"])
    )
    error_message = "Shared external keys must have one grant. External metadata must use read-only custom roles and exact secret grants."
  }
}

run "own_project_number_is_not_external" {
  command = plan
  variables {
    state_storage   = { location = "US", kms_key = "projects/123456789012/locations/us/keyRings/customer/cryptoKeys/state" }
    license_secrets = ["projects/123456789012/secrets/license"]
  }
  override_data {
    target = data.google_kms_crypto_key.existing_storage["projects/123456789012/locations/us/keyRings/customer/cryptoKeys/state"]
    values = { purpose = "ENCRYPT_DECRYPT", primary = [{ name = "version", state = "ENABLED" }] }
  }
  assert {
    condition = (length(google_project_iam_custom_role.external_metadata) == 0 &&
    alltrue([for role in google_project_iam_custom_role.key_metadata : role.project == "customer-project"]))
    error_message = "The customer project number must not create an external metadata project grant."
  }
}
