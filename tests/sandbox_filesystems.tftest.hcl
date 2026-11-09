mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      id    = "projects/braintrust-test/serviceAccounts/worker-nodes@braintrust-test.iam.gserviceaccount.com"
      email = "worker-nodes@braintrust-test.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_compute_network" {
    defaults = {
      id        = "projects/braintrust-test/global/networks/primary"
      self_link = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    }
  }
  mock_resource "google_container_cluster" {
    defaults = {
      cluster_ipv4_cidr = "10.20.0.0/20"
      node_locations    = ["us-central1-a", "us-central1-b"]
    }
  }
  mock_data "google_client_config" {
    defaults = { region = "us-central1", project = "braintrust-test" }
  }
  mock_data "google_project" {
    defaults = { project_id = "braintrust-test", number = "123456789012" }
  }
}
mock_provider "google-beta" {}
mock_provider "random" {}

variables { deployment_name = "braintrust" }

run "disabled_workers_have_no_checkpoint_storage" {
  command = plan
  assert {
    condition = (
      length(google_storage_bucket.sandbox_filesystems) == 0 &&
      length(google_storage_bucket_iam_member.sandbox_filesystems_worker) == 0 &&
      output.gke_isolated_workers == null
    )
    error_message = "Disabled workers must not create checkpoint storage or grant storage access."
  }
}

run "loop_workers_have_private_gc_managed_storage" {
  command = apply
  variables {
    enable_loop_runtime            = true
    gcs_versioning_enabled         = true
    gcs_soft_delete_retention_days = 30
    gcs_force_destroy              = true
    custom_gcs_brainstore_lifecycle_rules = [{
      action    = { type = "Delete" }
      condition = { age = 1 }
    }]
  }
  override_resource {
    target = module.gke_isolated_workers_cluster[0].google_service_account.services_nodes[0]
    values = {
      email = "services-nodes@braintrust-test.iam.gserviceaccount.com"
      id    = "projects/braintrust-test/serviceAccounts/services-nodes@braintrust-test.iam.gserviceaccount.com"
    }
  }
  assert {
    condition = (
      google_storage_bucket.sandbox_filesystems[0].uniform_bucket_level_access &&
      google_storage_bucket.sandbox_filesystems[0].public_access_prevention == "enforced" &&
      google_storage_bucket.sandbox_filesystems[0].storage_class == "STANDARD" &&
      google_storage_bucket.sandbox_filesystems[0].encryption[0].default_kms_key_name == module.kms.kms_key_id
    )
    error_message = "Checkpoint storage must be private, encrypted, and immediately available for recovery."
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
    error_message = "Checkpoint GC must own deletion independently of general storage lifecycle settings, and Terraform must retain the bucket."
  }
  assert {
    condition = (
      google_storage_bucket_iam_member.sandbox_filesystems_worker[0].bucket == google_storage_bucket.sandbox_filesystems[0].name &&
      google_storage_bucket_iam_member.sandbox_filesystems_worker[0].role == "roles/storage.objectUser" &&
      google_storage_bucket_iam_member.sandbox_filesystems_worker[0].member == "serviceAccount:${output.gke_isolated_workers.node_service_account}" &&
      output.gke_isolated_workers.node_service_account != output.gke_isolated_workers.services_node_service_account
    )
    error_message = "Only the worker-node identity must receive object access scoped to the checkpoint bucket."
  }
  assert {
    condition = (
      output.loop_runtime.workers.checkpoint_store == "gs://${google_storage_bucket.sandbox_filesystems[0].name}/sandbox-filesystems" &&
      output.gke_isolated_workers.checkpoint_store == output.loop_runtime.workers.checkpoint_store &&
      output.gke_cluster_mode == "autopilot"
    )
    error_message = "Both worker outputs must expose the same checkpoint URI without changing primary cluster mode."
  }
}

run "standalone_workers_share_the_storage_contract" {
  command = apply
  variables {
    gke_cluster_mode = "standard"
    gke_isolated_workers = {
      network_cidr     = "10.64.0.0/16"
      authorized_cidrs = ["192.0.2.10/32"]
      discovery        = { dns_name = "workers-test.isolated.internal" }
    }
  }
  assert {
    condition = (
      length(google_storage_bucket.sandbox_filesystems) == 1 &&
      output.gke_isolated_workers.checkpoint_store == "gs://${google_storage_bucket.sandbox_filesystems[0].name}/sandbox-filesystems" &&
      output.loop_runtime == null &&
      output.gke_cluster_mode == "standard"
    )
    error_message = "Standalone workers must support checkpoints without requiring the Loop flag or changing cluster mode."
  }
}

run "worker_removal_drops_access_and_retains_the_bucket" {
  command = plan
  assert {
    condition = (
      length(google_storage_bucket.sandbox_filesystems) == 0 &&
      length(google_storage_bucket_iam_member.sandbox_filesystems_worker) == 0 &&
      output.gke_isolated_workers == null
    )
    error_message = "Worker removal must remove grants while the previous bucket is abandoned according to its deletion policy."
  }
}
