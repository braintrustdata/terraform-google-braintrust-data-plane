locals {
  storage_catalog = jsondecode(file("${path.module}/data/storage-locations.json"))
  storage = {
    for name, config in { state = var.state_storage, evidence = var.evidence_storage } : name => {
      location                  = lower(coalesce(config.location, var.region))
      kms_location              = lookup(local.storage_catalog.kms_location_overrides, lower(coalesce(config.location, var.region)), lower(coalesce(config.location, var.region)))
      data_locations            = [for location in config.data_locations : lower(location)]
      kms_key                   = config.kms_key
    }
  }
  managed_storage_keys = { for name, config in local.storage : name => config if config.kms_key == null }
  # Group shared existing keys so that one IAM member owns each key grant.
  storage_key_groups = {
    for name, config in local.storage : (config.kms_key == null ? "managed:${name}" : config.kms_key) => name...
  }
  existing_storage_keys = toset([
    for config in values(local.storage) : config.kms_key if config.kms_key != null
  ])
  storage_keys = {
    for name, config in local.storage : name => config.kms_key == null ? google_kms_crypto_key.storage[name].id : config.kms_key
  }
}

resource "google_kms_key_ring" "storage" {
  for_each = local.managed_storage_keys

  project  = data.google_project.customer.project_id
  name     = "bt-${local.suffix}-${each.key}"
  location = each.value.kms_location

  depends_on = [google_project_service.required]
}

resource "google_kms_crypto_key" "storage" {
  for_each = local.managed_storage_keys

  name            = "storage"
  key_ring        = google_kms_key_ring.storage[each.key].id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "31536000s"
  deletion_policy = "ABANDON"
  labels          = local.labels

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }
}

data "google_kms_crypto_key" "existing_storage" {
  for_each = local.existing_storage_keys

  name     = try(split("/", each.value)[7], "invalid")
  key_ring = try(join("/", slice(split("/", each.value), 0, 6)), "invalid")

  lifecycle {
    postcondition {
      condition     = self.purpose == "ENCRYPT_DECRYPT" && try(self.primary[0].state == "ENABLED", false)
      error_message = "An existing storage key must support symmetric encryption and have an enabled primary version."
    }
  }
}

resource "google_kms_crypto_key_iam_member" "storage_service_agent" {
  for_each = local.storage_key_groups

  crypto_key_id = local.storage_keys[each.value[0]]
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.customer.email_address}"

  # The provider cannot abandon IAM members. Require explicit state handoff.
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [data.google_kms_crypto_key.existing_storage]
}
