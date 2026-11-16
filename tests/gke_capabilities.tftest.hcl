mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "random" {}

variables { deployment_name = "braintrust" }

run "iam_dns_access_keeps_ip_control_plane_private" {
  command = plan
  module { source = "./modules/gke-cluster" }
  variables {
    project_id                  = "braintrust-test"
    region                      = "us-central1"
    gke_cluster_mode            = "standard"
    gke_network                 = "primary"
    gke_subnetwork              = "workers"
    gke_kms_cmek_id             = "key"
    gke_cluster_is_private      = true
    gke_enable_private_endpoint = true
    gke_dns_endpoint_enabled    = true
  }
  assert {
    condition = (
      google_container_cluster.braintrust.private_cluster_config[0].enable_private_nodes &&
      google_container_cluster.braintrust.private_cluster_config[0].enable_private_endpoint &&
      google_container_cluster.braintrust.control_plane_endpoints_config[0].dns_endpoint_config[0].allow_external_traffic &&
      !google_container_cluster.braintrust.control_plane_endpoints_config[0].dns_endpoint_config[0].enable_k8s_certs_via_dns &&
      !google_container_cluster.braintrust.control_plane_endpoints_config[0].dns_endpoint_config[0].enable_k8s_tokens_via_dns
    )
    error_message = "Remote deployment must use IAM-authenticated DNS, with private IP access and Kubernetes credentials disabled on DNS."
  }
}

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
