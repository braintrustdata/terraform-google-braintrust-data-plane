mock_provider "time" {}

mock_provider "google-beta" {}

mock_provider "google" {
  override_during = plan

  mock_resource "google_service_account" {
    defaults = {
      name  = "projects/customer-project/serviceAccounts/test-account@customer-project.iam.gserviceaccount.com"
      email = "test-account@customer-project.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_project_iam_custom_role" {
    defaults = { name = "projects/customer-project/roles/mockRole" }
  }
  mock_data "google_project" {
    defaults = {
      project_id = "customer-project"
      number     = "123456789012"
    }
  }
  mock_data "google_storage_project_service_account" {
    defaults = {
      email_address = "service-123456789012@gs-project-accounts.iam.gserviceaccount.com"
    }
  }
  mock_data "google_kms_crypto_key" {
    defaults = {
      purpose = "ENCRYPT_DECRYPT"
      primary = [{ name = "projects/key-project/locations/us/keyRings/customer/cryptoKeys/shared/cryptoKeyVersions/1", state = "ENABLED" }]
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

override_data {
  target          = data.google_storage_project_service_account.customer
  override_during = plan
  values          = { email_address = "service-123456789012@gs-project-accounts.iam.gserviceaccount.com" }
}

run "default_encryption" {
  command = plan

  assert {
    condition = (
      google_storage_bucket.state.location == "US-CENTRAL1" &&
      google_storage_bucket.evidence.location == "US-CENTRAL1" &&
      length(google_kms_crypto_key.storage) == 2 &&
      google_kms_crypto_key.storage["state"].id != google_kms_crypto_key.storage["evidence"].id &&
      google_storage_bucket.state.encryption[0].default_kms_key_name == google_kms_crypto_key.storage["state"].id &&
      google_storage_bucket.evidence.encryption[0].default_kms_key_name == google_kms_crypto_key.storage["evidence"].id
    )
    error_message = "Default buckets must use separate keys in the deployment region."
  }
  assert {
    condition = alltrue([for key in google_kms_crypto_key.storage :
      key.deletion_policy == "ABANDON" && key.purpose == "ENCRYPT_DECRYPT" &&
      key.rotation_period == "31536000s" &&
      key.version_template[0].algorithm == "GOOGLE_SYMMETRIC_ENCRYPTION"
    ])
    error_message = "Created keys must retain usable symmetric versions and automatic rotation on removal."
  }
  assert {
    condition = alltrue([for grant in google_kms_crypto_key_iam_member.storage_service_agent :
      grant.role == "roles/cloudkms.cryptoKeyEncrypterDecrypter"
    ])
    error_message = "Storage key grants must use only the encryption and decryption role."
  }
  assert {
    condition = (
      output.bootstrap.state.location == "US-CENTRAL1" &&
      output.bootstrap.state.kms_key == google_storage_bucket.state.encryption[0].default_kms_key_name &&
      output.bootstrap.state.kms_key_created && output.bootstrap.evidence.kms_key_created &&
      length(output.bootstrap.state.data_locations) == 0
    )
    error_message = "The normal bootstrap output must expose actual placement and key references."
  }
}

run "independent_locations" {
  command   = plan
  state_key = "independent"
  variables {
    state_storage    = { location = "europe-west1" }
    evidence_storage = { location = "US" }
  }
  assert {
    condition = (
      google_storage_bucket.state.location == "EUROPE-WEST1" &&
      google_storage_bucket.evidence.location == "US" &&
      google_kms_key_ring.storage["state"].location == "europe-west1" &&
      google_kms_key_ring.storage["evidence"].location == "us" &&
      output.bootstrap.region == "us-central1"
    )
    error_message = "Independent storage placement must not change the deployment or quota region."
  }
}

run "configurable_and_predefined_dual_regions" {
  command   = plan
  state_key = "dual"
  variables {
    state_storage    = { location = "US", data_locations = ["US-EAST1", "us-west1"] }
    evidence_storage = { location = "EUR4" }
  }
  assert {
    condition = (
      google_storage_bucket.state.location == "US" &&
      toset(google_storage_bucket.state.custom_placement_config[0].data_locations) == toset(["US-EAST1", "US-WEST1"]) &&
      google_kms_key_ring.storage["state"].location == "us" &&
      google_storage_bucket.evidence.location == "EUR4" &&
      length(google_storage_bucket.evidence.custom_placement_config) == 0 &&
      google_kms_key_ring.storage["evidence"].location == "eur4" &&
      toset(output.bootstrap.state.data_locations) == toset(["US-EAST1", "US-WEST1"])
    )
    error_message = "Dual-region keys must use the area or predefined location code."
  }
}

run "shared_cross_project_existing_key" {
  command   = plan
  state_key = "existing"
  variables {
    state_storage = {
      location = "US"
      kms_key  = "projects/key-project/locations/us/keyRings/customer/cryptoKeys/shared"
    }
    evidence_storage = {
      location = "us"
      kms_key  = "projects/key-project/locations/us/keyRings/customer/cryptoKeys/shared"
    }
  }
  assert {
    condition = (
      length(google_kms_crypto_key.storage) == 0 && length(google_kms_key_ring.storage) == 0 &&
      length(data.google_kms_crypto_key.existing_storage) == 1 &&
      length(google_kms_crypto_key_iam_member.storage_service_agent) == 1 &&
      google_storage_bucket.state.encryption[0].default_kms_key_name == var.state_storage.kms_key &&
      google_storage_bucket.evidence.encryption[0].default_kms_key_name == var.evidence_storage.kms_key &&
      !output.bootstrap.state.kms_key_created && !output.bootstrap.evidence.kms_key_created
    )
    error_message = "Shared existing keys require one read and one grant without key creation or mutation."
  }
}

run "one_existing_key" {
  command   = plan
  state_key = "mixed"
  variables {
    state_storage = { kms_key = "projects/key-project/locations/us-central1/keyRings/customer/cryptoKeys/state" }
  }
  assert {
    condition = (
      toset(keys(google_kms_crypto_key.storage)) == toset(["evidence"]) &&
      length(google_kms_crypto_key_iam_member.storage_service_agent) == 2 &&
      !output.bootstrap.state.kms_key_created && output.bootstrap.evidence.kms_key_created
    )
    error_message = "Each bucket must select its key independently."
  }
}

run "country_dual_regions" {
  command   = plan
  state_key = "country"
  variables {
    state_storage    = { location = "DE", data_locations = ["europe-west3", "europe-west10"] }
    evidence_storage = { location = "IT", data_locations = ["europe-west8", "europe-west12"] }
  }
  assert {
    condition     = google_kms_key_ring.storage["state"].location == "de" && google_kms_key_ring.storage["evidence"].location == "it"
    error_message = "Country pairs must retain their own area codes for KMS."
  }
}

run "reject_unknown_location" {
  command   = plan
  state_key = "invalid-location"
  variables { state_storage = { location = "moon-west1" } }
  expect_failures = [var.state_storage]
}

run "reject_mismatched_key_location" {
  command   = plan
  state_key = "invalid-key-location"
  variables {
    evidence_storage = { location = "US", kms_key = "projects/key-project/locations/us-central1/keyRings/customer/cryptoKeys/evidence" }
  }
  expect_failures = [var.evidence_storage]
}

run "reject_global_key" {
  command   = plan
  state_key = "global-key"
  variables {
    state_storage = { kms_key = "projects/key-project/locations/global/keyRings/customer/cryptoKeys/state" }
  }
  expect_failures = [var.state_storage]
}

run "reject_version_reference" {
  command   = plan
  state_key = "version-key"
  variables {
    state_storage = { kms_key = "projects/key-project/locations/us-central1/keyRings/customer/cryptoKeys/state/cryptoKeyVersions/1" }
  }
  expect_failures = [var.state_storage]
}

run "reject_duplicate_regions" {
  command   = plan
  state_key = "duplicate"
  variables { state_storage = { location = "us", data_locations = ["us-west1", "US-WEST1"] } }
  expect_failures = [var.state_storage]
}

run "reject_cross_area_pair" {
  command   = plan
  state_key = "cross-area"
  variables { evidence_storage = { location = "us", data_locations = ["us-west1", "europe-west1"] } }
  expect_failures = [var.evidence_storage]
}

run "reject_predefined_pair_as_custom" {
  command   = plan
  state_key = "predefined"
  variables { state_storage = { location = "us", data_locations = ["us-east1", "us-central1"] } }
  expect_failures = [var.state_storage]
}

run "reject_east5_pair" {
  command   = plan
  state_key = "east5"
  variables { state_storage = { location = "us", data_locations = ["us-east5", "us-west1"] } }
  expect_failures = [var.state_storage]
}

run "reject_wrong_country_code" {
  command   = plan
  state_key = "wrong-country"
  variables { evidence_storage = { location = "eu", data_locations = ["europe-west8", "europe-west12"] } }
  expect_failures = [var.evidence_storage]
}

run "reject_incomplete_pair" {
  command   = plan
  state_key = "incomplete"
  variables { state_storage = { location = "us", data_locations = ["us-west1"] } }
  expect_failures = [var.state_storage]
}

run "reject_disabled_existing_key" {
  command   = plan
  state_key = "disabled"
  variables {
    state_storage = { kms_key = "projects/key-project/locations/us-central1/keyRings/customer/cryptoKeys/state" }
  }
  override_data {
    target = data.google_kms_crypto_key.existing_storage["projects/key-project/locations/us-central1/keyRings/customer/cryptoKeys/state"]
    values = { purpose = "ENCRYPT_DECRYPT", primary = [{ name = "key-version", state = "DISABLED" }] }
  }
  expect_failures = [data.google_kms_crypto_key.existing_storage]
}

run "reject_asymmetric_existing_key" {
  command   = plan
  state_key = "asymmetric"
  variables {
    state_storage = { kms_key = "projects/key-project/locations/us-central1/keyRings/customer/cryptoKeys/state" }
  }
  override_data {
    target = data.google_kms_crypto_key.existing_storage["projects/key-project/locations/us-central1/keyRings/customer/cryptoKeys/state"]
    values = { purpose = "ASYMMETRIC_SIGN", primary = [] }
  }
  expect_failures = [data.google_kms_crypto_key.existing_storage]
}

run "eu_kms_location_mapping" {
  command   = plan
  state_key = "eu"
  variables {
    state_storage = { location = "EU" }
    evidence_storage = {
      location       = "EU"
      data_locations = ["europe-west1", "europe-west4"]
      kms_key        = "projects/key-project/locations/europe/keyRings/customer/cryptoKeys/evidence"
    }
  }
  assert {
    condition     = google_kms_key_ring.storage["state"].location == "europe" && google_storage_bucket.evidence.location == "EU"
    error_message = "EU buckets must use the europe KMS location for created and existing keys."
  }
}

run "reject_eu_as_kms_location" {
  command   = plan
  state_key = "invalid-eu-key"
  variables {
    state_storage = { location = "EU", kms_key = "projects/key-project/locations/eu/keyRings/customer/cryptoKeys/state" }
  }
  expect_failures = [var.state_storage]
}

run "reject_null_region_member" {
  command   = plan
  state_key = "null-member"
  variables { evidence_storage = { location = "us", data_locations = [null, "us-west1"] } }
  expect_failures = [var.evidence_storage]
}

run "additional_predefined_dual_regions" {
  command   = plan
  state_key = "eur5"
  variables {
    state_storage    = { location = "EUR5" }
    evidence_storage = { location = "EUR8" }
  }
  assert {
    condition     = google_kms_key_ring.storage["state"].location == "eur5" && google_kms_key_ring.storage["evidence"].location == "eur8"
    error_message = "Predefined dual-region keys must use the exact location code."
  }
}
