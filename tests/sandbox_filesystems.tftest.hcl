mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      id    = "projects/braintrust-test/serviceAccounts/worker-nodes@braintrust-test.iam.gserviceaccount.com"
      email = "worker-nodes@braintrust-test.iam.gserviceaccount.com"
    }
  }
  mock_data "google_client_config" {
    defaults = { region = "us-central1", project = "braintrust-test" }
  }
  mock_data "google_project" {
    defaults = { project_id = "braintrust-test", number = "123456789012" }
  }
}
mock_provider "random" {}

variables { deployment_name = "braintrust" }

run "disabled_workers_have_no_checkpoint_storage" {
  command = plan
  module { source = "./modules/storage" }
  variables {
    gcs_kms_cmek_id = "projects/braintrust-test/locations/us-central1/keyRings/braintrust/cryptoKeys/storage"
  }
  assert {
    condition     = length(google_storage_bucket.sandbox_filesystems) == 0 && output.sandbox_filesystems_bucket_name == null
    error_message = "Disabled workers must not create checkpoint storage."
  }
}

run "workers_have_private_gc_managed_storage" {
  command = apply
  module { source = "./modules/storage" }
  variables {
    sandbox_filesystems_enabled    = true
    gcs_kms_cmek_id                = "projects/braintrust-test/locations/us-central1/keyRings/braintrust/cryptoKeys/storage"
    gcs_versioning_enabled         = true
    gcs_soft_delete_retention_days = 30
    gcs_force_destroy              = true
    custom_gcs_brainstore_lifecycle_rules = [{
      action    = { type = "Delete" }
      condition = { age = 1 }
    }]
  }
  assert {
    condition = (
      google_storage_bucket.sandbox_filesystems[0].uniform_bucket_level_access &&
      google_storage_bucket.sandbox_filesystems[0].public_access_prevention == "enforced" &&
      google_storage_bucket.sandbox_filesystems[0].storage_class == "STANDARD" &&
      google_storage_bucket.sandbox_filesystems[0].encryption[0].default_kms_key_name == var.gcs_kms_cmek_id &&
      output.sandbox_filesystems_bucket_name == google_storage_bucket.sandbox_filesystems[0].name
    )
    error_message = "Checkpoint storage must expose a private, encrypted bucket ready for recovery."
  }
  assert {
    condition = (
      !google_storage_bucket.sandbox_filesystems[0].versioning[0].enabled &&
      google_storage_bucket.sandbox_filesystems[0].soft_delete_policy[0].retention_duration_seconds == 0 &&
      length(google_storage_bucket.sandbox_filesystems[0].lifecycle_rule) == 0 &&
      length(google_storage_bucket.sandbox_filesystems[0].retention_policy) == 0 &&
      !google_storage_bucket.sandbox_filesystems[0].force_destroy &&
      google_storage_bucket.sandbox_filesystems[0].deletion_policy == "ABANDON"
    )
    error_message = "Checkpoint GC must own deletion independently of general storage settings, and Terraform must retain the bucket."
  }
}

run "worker_removal_releases_checkpoint_storage" {
  command = plan
  module { source = "./modules/storage" }
  variables {
    gcs_kms_cmek_id = "projects/braintrust-test/locations/us-central1/keyRings/braintrust/cryptoKeys/storage"
  }
  assert {
    condition     = length(google_storage_bucket.sandbox_filesystems) == 0 && output.sandbox_filesystems_bucket_name == null
    error_message = "Worker removal must abandon the checkpoint bucket according to its deletion policy."
  }
}

run "worker_identity_has_checkpoint_object_access" {
  command = plan
  module { source = "./modules/gke-iam" }
  variables {
    workload_identity_pool         = "braintrust-test.svc.id.goog"
    braintrust_api_bucket_id       = "braintrust-api"
    brainstore_gcs_bucket_id       = "braintrust-storage"
    sandbox_filesystems_enabled    = true
    sandbox_filesystems_bucket_id  = "sandbox-checkpoints"
    sandbox_worker_service_account = "worker-nodes@braintrust-test.iam.gserviceaccount.com"
  }
  assert {
    condition = (
      google_storage_bucket_iam_member.sandbox_filesystems_worker[0].bucket == "sandbox-checkpoints" &&
      google_storage_bucket_iam_member.sandbox_filesystems_worker[0].role == "roles/storage.objectUser" &&
      google_storage_bucket_iam_member.sandbox_filesystems_worker[0].member == "serviceAccount:worker-nodes@braintrust-test.iam.gserviceaccount.com"
    )
    error_message = "The worker-node identity must receive object access scoped to the checkpoint bucket."
  }
}

run "disabled_workers_have_no_checkpoint_grant" {
  command = plan
  module { source = "./modules/gke-iam" }
  variables {
    workload_identity_pool   = "braintrust-test.svc.id.goog"
    braintrust_api_bucket_id = "braintrust-api"
    brainstore_gcs_bucket_id = "braintrust-storage"
  }
  assert {
    condition     = length(google_storage_bucket_iam_member.sandbox_filesystems_worker) == 0
    error_message = "Disabled workers must not receive checkpoint storage access."
  }
}
