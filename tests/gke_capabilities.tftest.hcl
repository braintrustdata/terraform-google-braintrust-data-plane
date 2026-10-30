mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "random" {}

variables { deployment_name = "braintrust" }

run "worker_pool_capabilities" {
  command = apply
  module { source = "./modules/gke-node-pool" }
  variables {
    name                         = "isolated-workers"
    project_id                   = "braintrust-test"
    location                     = "us-central1"
    cluster_id                   = "workers"
    service_account_email        = "workers@braintrust-test.iam.gserviceaccount.com"
    boot_disk_kms_key            = "key"
    machine_type                 = "c4-standard-8-lssd"
    image_type                   = "UBUNTU_CONTAINERD"
    total_min_node_count         = 1
    total_max_node_count         = 10
    cluster_node_locations       = ["us-central1-a", "us-central1-b"]
    enable_nested_virtualization = true
    raw_local_ssd                = true
    taints                       = [{ key = "braintrust.io/sandbox", value = "true", effect = "NO_SCHEDULE" }]
  }
  assert {
    condition = (
      google_container_node_pool.this.node_config[0].advanced_machine_features[0].enable_nested_virtualization &&
      length(google_container_node_pool.this.node_config[0].local_nvme_ssd_block_config) == 1 &&
      google_container_node_pool.this.node_config[0].image_type == "UBUNTU_CONTAINERD" &&
      length(google_container_node_pool.this.node_config[0].taint) == 1 && google_container_node_pool.this.node_config[0].taint[0].effect == "NO_SCHEDULE" &&
      google_container_node_pool.this.management[0].auto_upgrade
    )
    error_message = "The worker pool requires nested virtualization, raw SSD, Ubuntu, automatic upgrades, and its isolation taint."
  }
}

run "shared_gke_key_grants" {
  command = apply
  module { source = "./modules/kms" }
  variables {
    grant_gke_access = true
    project_number   = "123456789012"
  }
  assert {
    condition = (
      google_kms_crypto_key_iam_member.gke_cluster_cmek[0].crypto_key_id == google_kms_crypto_key.kms.id &&
      google_kms_crypto_key_iam_member.gke_compute_cmek[0].crypto_key_id == google_kms_crypto_key.kms.id &&
      google_kms_crypto_key_iam_member.gke_cluster_cmek[0].member == "serviceAccount:service-123456789012@container-engine-robot.iam.gserviceaccount.com" &&
      google_kms_crypto_key_iam_member.gke_compute_cmek[0].member == "serviceAccount:service-123456789012@compute-system.iam.gserviceaccount.com"
    )
    error_message = "Both clusters must share the deployment key with one grant per Google service agent."
  }
}

run "kms_without_gke_has_no_service_agent_grants" {
  command = plan
  module { source = "./modules/kms" }
  assert {
    condition     = length(google_kms_crypto_key_iam_member.gke_cluster_cmek) == 0 && length(google_kms_crypto_key_iam_member.gke_compute_cmek) == 0
    error_message = "Deployments without GKE must not create GKE service-agent grants."
  }
}
