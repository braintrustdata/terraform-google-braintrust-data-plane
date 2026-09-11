mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      id    = "projects/braintrust-test/serviceAccounts/mock-nodes@braintrust-test.iam.gserviceaccount.com"
      email = "mock-nodes@braintrust-test.iam.gserviceaccount.com"
    }
  }
  mock_resource "google_compute_network" {
    defaults = {
      id        = "projects/braintrust-test/global/networks/primary"
      self_link = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    }
  }

  mock_data "google_client_config" {
    defaults = { region = "us-central1", project = "braintrust-test" }
  }
  mock_data "google_project" {
    defaults = { project_id = "braintrust-test", number = "123456789012" }
  }
  mock_resource "google_container_cluster" {
    defaults = {
      cluster_ipv4_cidr = "10.20.0.0/20"
      node_locations    = ["us-central1-a", "us-central1-b"]
    }
  }
}
mock_provider "google-beta" {}
mock_provider "random" {}

variables { deployment_name = "braintrust" }

run "disabled_by_default" {
  override_data {
    target = data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.storage.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.redis.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  command = plan
  assert {
    condition     = output.gke_isolated_workers == null && output.gke_cluster_mode == "autopilot" && length(module.gke_isolated_services_pool) == 0 && length(module.gke_isolated_workers_cluster) == 0
    error_message = "Existing deployments must create no isolated worker infrastructure."
  }
}

run "autopilot_plus_workers" {
  override_resource {
    target = module.gke_isolated_workers_cluster[0].google_service_account.services_nodes[0]
    values = {
      email = "isolated-services@braintrust-test.iam.gserviceaccount.com"
      id    = "projects/braintrust-test/serviceAccounts/isolated-services@braintrust-test.iam.gserviceaccount.com"
    }
  }

  override_data {
    target = data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.storage.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.redis.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  command = apply
  variables {
    gke_isolated_workers = {
      discovery          = { dns_name = "workers-test.isolated.internal", runtime_source_ranges = ["10.20.0.0/20"] }
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
    }
  }
  assert {
    condition     = output.gke_isolated_workers.kms_key_id == module.kms.kms_key_id
    error_message = "The isolated cluster must use the deployment key."
  }
  assert {
    condition     = output.gke_cluster_mode == "autopilot" && length(output.gke_node_pool_names) == 0
    error_message = "Isolated workers must not change the primary Autopilot mode or pools."
  }
  assert {
    condition     = output.gke_isolated_workers.name == "braintrust-gke-isolated-workers" && output.gke_isolated_workers.name != output.gke_cluster_name && output.gke_isolated_workers.node_selector["braintrust/node-pool"] == "isolated-workers"
    error_message = "Workers require a distinct cluster and stable pool selector."
  }
  assert {
    condition = (
      length(module.gke_isolated_services_pool) == 1 &&
      output.gke_isolated_workers.services_node_service_account != output.gke_isolated_workers.node_service_account &&
      output.gke_isolated_workers.services_node_selector["braintrust/node-pool"] == "services"
    )
    error_message = "The isolated services pool requires a separate node identity with only node roles."
  }

  assert {
    condition = (
      output.gke_isolated_workers.discovery.endpoint == "https://workers.workers-test.isolated.internal:9400" &&
      output.gke_isolated_workers.discovery.external_dns_namespace == local.isolated_workers_name
    )
    error_message = "Discovery must expose HTTPS and a deployment-specific external-dns workload identity."
  }
}

run "firewall_change_keeps_cluster_identity_known" {
  override_resource {
    target = module.gke_isolated_workers_cluster[0].google_service_account.services_nodes[0]
    values = {
      email = "isolated-services@braintrust-test.iam.gserviceaccount.com"
      id    = "projects/braintrust-test/serviceAccounts/isolated-services@braintrust-test.iam.gserviceaccount.com"
    }
  }

  override_data {
    target = data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.storage.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.redis.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  command = plan
  variables {
    gke_isolated_workers = {
      discovery = { dns_name = "workers-test.isolated.internal", runtime_source_ranges = ["10.20.0.0/20"] }
      egress_rules = {
        custom = { destination_ranges = ["10.90.0.0/24"], ports = ["8443"] }
      }
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
    }
  }
  assert {
    condition = (
      module.gke_isolated_workers_cluster[0].gke_cluster_location == "us-central1" &&
      module.gke_isolated_workers_cluster[0].workload_identity_pool == "braintrust-test.svc.id.goog" &&
      module.gke-cluster[0].gke_cluster_location == "us-central1"
    )
    error_message = "Firewall changes must preserve known cluster location and project identity during the plan."
  }
}

run "standard_plus_workers" {
  override_resource {
    target = module.gke_isolated_workers_cluster[0].google_service_account.services_nodes[0]
    values = {
      email = "isolated-services@braintrust-test.iam.gserviceaccount.com"
      id    = "projects/braintrust-test/serviceAccounts/isolated-services@braintrust-test.iam.gserviceaccount.com"
    }
  }

  override_data {
    target = data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.storage.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.redis.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  command = apply
  variables {
    gke_cluster_mode = "standard"
    gke_isolated_workers = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
    }
  }
  assert {
    condition     = output.gke_cluster_mode == "standard" && toset(keys(output.gke_node_pool_names)) == toset(["services", "brainstore"])
    error_message = "The primary Standard pool map must remain independent of isolated workers."
  }
}

run "network_is_restricted" {

  command = apply
  module { source = "./modules/gke-isolated-workers-network" }
  variables {
    network        = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    primary_subnet = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/primary"
    config = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
      ingress_rules      = { runtime = { source_ranges = ["10.20.0.0/20"], ports = ["8080"] } }
    }
  }
  assert {
    condition = (
      google_compute_firewall.deny["EGRESS"].destination_ranges == toset(["0.0.0.0/0"]) &&
      google_compute_firewall.deny["INGRESS"].source_ranges == toset(["0.0.0.0/0"]) &&
      length(google_compute_firewall.egress) == 0 &&
      google_compute_firewall.public_https.destination_ranges == toset(["0.0.0.0/0"]) &&
      one(google_compute_firewall.public_https.allow).protocol == "tcp" &&
      one(google_compute_firewall.public_https.allow).ports == tolist(["443"]) &&
      google_compute_firewall.private_egress.priority < google_compute_firewall.public_https.priority &&
      google_compute_firewall.internal["EGRESS"].priority < google_compute_firewall.private_egress.priority &&
      google_compute_firewall.control_plane_egress.priority < google_compute_firewall.private_egress.priority &&
      google_compute_firewall.public_https.priority < google_compute_firewall.deny["EGRESS"].priority &&
      alltrue([for cidr in ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16", "100.64.0.0/10"] : contains(google_compute_firewall.private_egress.destination_ranges, cidr)])
    )
    error_message = "Workers require public HTTPS with higher-priority private destination denies and cluster traffic exceptions."
  }
  assert {
    condition     = google_compute_firewall.ingress["runtime"].priority < google_compute_firewall.deny["INGRESS"].priority
    error_message = "Explicit worker ingress must precede the deny rule."
  }
  assert {
    condition     = google_compute_subnetwork.workers[0].private_ip_google_access
    error_message = "Workers require Private Google Access."
  }
}

run "overlap_is_rejected" {

  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  variables {
    network        = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    primary_subnet = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/primary"
    primary_cidrs  = ["10.64.0.0/16"]
    config = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
    }
  }
  expect_failures = [terraform_data.network_contract]
}

run "arm_workers_are_rejected" {
  override_data {
    target = data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  command = plan
  variables {
    gke_isolated_workers = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
      machine_type       = "c4a-standard-16-lssd"
    }
  }
  expect_failures = [var.gke_isolated_workers]
}

run "primary_identity_grants_use_names" {

  command = apply
  module { source = "./modules/gke-iam" }
  variables {
    workload_identity_pool   = "braintrust-test.svc.id.goog"
    braintrust_api_bucket_id = "api"
    brainstore_gcs_bucket_id = "brainstore"
  }
  assert {
    condition = google_service_account_iam_binding.braintrust_workload_identity.members == toset([
      "serviceAccount:braintrust-test.svc.id.goog[braintrust/braintrust-api]"
    ])
    error_message = "API impersonation must retain its namespace and service account grant."
  }
  assert {
    condition     = google_service_account_iam_binding.brainstore_workload_identity.members == toset(["serviceAccount:braintrust-test.svc.id.goog[braintrust/braintrust-api]", "serviceAccount:braintrust-test.svc.id.goog[braintrust/brainstore]"])
    error_message = "Both primary service accounts must retain name-based Brainstore access."
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
    machine_type                 = "c4-standard-16-lssd"
    image_type                   = "UBUNTU_CONTAINERD"
    total_min_node_count         = 2
    total_max_node_count         = 10
    cluster_node_locations       = ["us-central1-a", "us-central1-b"]
    enable_nested_virtualization = true
    raw_local_ssd                = true
    taints                       = [{ key = "braintrust/isolated-worker", value = "true", effect = "NO_SCHEDULE" }]
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

run "worker_cluster_iam_and_endpoints" {

  command = apply
  module { source = "./modules/gke-cluster" }
  variables {
    project_id                         = "braintrust-test"
    region                             = "us-central1"
    gke_cluster_name                   = "braintrust-isolated-workers"
    gke_cluster_mode                   = "standard"
    gke_network                        = "primary"
    gke_subnetwork                     = "workers"
    gke_kms_cmek_id                    = "key"
    gke_cluster_is_private             = true
    gke_enable_private_endpoint        = false
    gke_dns_endpoint_enabled           = false
    gke_private_endpoint_enforcement   = false
    gke_control_plane_authorized_cidrs = null
    gke_node_service_account_id        = "braintrust-iw-nodes"
    gke_node_project_storage_access    = false
  }
  assert {
    condition = (
      length(google_project_iam_member.gke_object_viewer) == 0 &&
      length(google_project_iam_member.gke_artifact_reader) == 0 &&
      google_service_account.gke.account_id == "braintrust-iw-nodes" &&
      length(google_service_account.services_nodes) == 0 && length(google_project_iam_member.services_nodes) == 0
    )
    error_message = "Worker nodes require their own identity without project-wide storage or registry access."
  }
  assert {
    condition = (
      google_container_cluster.braintrust.private_cluster_config[0].enable_private_nodes &&
      !google_container_cluster.braintrust.private_cluster_config[0].enable_private_endpoint &&
      !google_container_cluster.braintrust.control_plane_endpoints_config[0].dns_endpoint_config[0].allow_external_traffic &&
      !google_container_cluster.braintrust.control_plane_endpoints_config[0].dns_endpoint_config[0].enable_k8s_tokens_via_dns
    )
    error_message = "Worker nodes must be private, with public IP control-plane access and DNS endpoint access disabled."
  }

}

run "existing_vpc_uses_isolation_network_module" {
  override_data {
    target = data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.storage.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.redis.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.gke_isolated_workers_network[0].data.google_compute_subnetwork.existing[0]
    values = {
      network                  = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
      region                   = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1"
      ip_cidr_range            = "10.60.0.0/24"
      private_ip_google_access = true
    }
  }
  command = apply
  variables {
    create_vpc                 = false
    existing_network_self_link = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    existing_subnet_self_link  = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/primary"
    gke_isolated_workers = {
      existing_subnet_self_link = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/workers"
      node_cidr                 = "10.60.0.0/24"
      pod_cidr                  = "10.64.0.0/18"
      service_cidr              = "10.65.0.0/22"
      control_plane_cidr        = "10.60.1.0/28"
    }
  }

  assert {
    condition     = length(module.vpc) == 0 && length(module.gke_isolated_workers_network) == 1 && output.gke_isolated_workers.subnet == var.gke_isolated_workers.existing_subnet_self_link && output.gke_isolated_workers.network == var.existing_network_self_link
    error_message = "Existing VPCs require the isolation network module with the supplied worker subnet."
  }
}

run "existing_vpc_requires_worker_subnet" {
  override_data {
    target = data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.storage.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.redis.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  command = plan
  variables {
    create_vpc                 = false
    existing_network_self_link = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    existing_subnet_self_link  = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/primary"
    gke_isolated_workers = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
    }
  }

  expect_failures = [var.gke_isolated_workers]
}

run "existing_vpc_requires_separate_worker_subnet" {
  override_data {
    target = data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.storage.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.redis.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  command = plan
  variables {
    create_vpc                 = false
    existing_network_self_link = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    existing_subnet_self_link  = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/primary"
    gke_isolated_workers = {
      existing_subnet_self_link = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/primary"
      node_cidr                 = "10.60.0.0/24"
      pod_cidr                  = "10.64.0.0/18"
      service_cidr              = "10.65.0.0/22"
      control_plane_cidr        = "10.60.1.0/28"
    }
  }

  expect_failures = [var.gke_isolated_workers]
}

run "supplied_subnet_receives_isolation_rules" {
  command = apply
  module { source = "./modules/gke-isolated-workers-network" }
  override_data {
    target = data.google_compute_subnetwork.existing[0]
    values = {
      network                  = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
      region                   = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1"
      ip_cidr_range            = "10.60.0.0/24"
      private_ip_google_access = true
    }
  }
  variables {
    network        = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    primary_subnet = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/primary"
    config = {
      existing_subnet_self_link = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/workers"
      pod_cidr                  = "10.64.0.0/18"
      service_cidr              = "10.65.0.0/22"
      control_plane_cidr        = "10.60.1.0/28"
    }
  }
  assert {
    condition     = length(google_compute_subnetwork.workers) == 0 && output.isolated_subnet_self_link == var.config.existing_subnet_self_link && length(google_compute_firewall.deny) == 2 && output.node_cidr == "10.60.0.0/24"
    error_message = "A supplied subnet requires isolation rules without subnet creation or duplicate private DNS."
  }
}

run "supplied_subnet_requires_same_vpc" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  override_data {
    target = data.google_compute_subnetwork.existing[0]
    values = {
      network                  = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/wrong"
      region                   = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1"
      ip_cidr_range            = "10.60.0.0/24"
      private_ip_google_access = true
    }
  }
  variables {
    network        = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    primary_subnet = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/primary"
    config = {
      existing_subnet_self_link = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/workers"
      node_cidr                 = "10.60.0.0/24"
      pod_cidr                  = "10.64.0.0/18"
      service_cidr              = "10.65.0.0/22"
      control_plane_cidr        = "10.60.1.0/28"
    }
  }
  expect_failures = [data.google_compute_subnetwork.existing]
}

run "discovery_uses_private_zone_and_worker_only_ingress" {
  command = apply
  module { source = "./modules/gke-isolated-workers-network" }
  variables {
    network        = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    primary_subnet = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/primary"
    config = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
      discovery          = { dns_name = "test.isolated.internal", runtime_source_ranges = ["10.20.0.0/20"] }
    }
  }
  assert {
    condition = (
      google_project_iam_custom_role.isolated_dns_zone_list[0].permissions == toset(["dns.managedZones.list"]) &&
      google_project_iam_custom_role.isolated_dns_records[0].permissions == toset(["dns.changes.create", "dns.resourceRecordSets.create", "dns.resourceRecordSets.delete", "dns.resourceRecordSets.list", "dns.resourceRecordSets.update"]) &&
      google_dns_managed_zone_iam_member.isolated_external_dns[0].managed_zone == output.discovery.zone_name &&
      google_service_account.isolated_external_dns[0].account_id != "braintrust-worker-nodes" &&
      google_service_account.isolated_external_dns[0].account_id != "braintrust-services-nodes"
    )
    error_message = "External-dns must use a separate identity with record writes scoped to its discovery zone."
  }
  assert {
    condition     = google_service_account_iam_binding.isolated_external_dns[0].members == toset(["serviceAccount:braintrust-test.svc.id.goog[${local.name}/external-dns]"])
    error_message = "External-dns must use its deployment-specific Kubernetes identity."
  }
  assert {
    condition = (
      google_dns_managed_zone.discovery[0].visibility == "private" &&
      google_dns_managed_zone.discovery[0].dns_name == "test.isolated.internal." &&
      one(google_dns_managed_zone.discovery[0].private_visibility_config[0].networks).network_url == var.network &&
      google_compute_firewall.runtime_to_workers[0].source_ranges == toset(["10.20.0.0/20"]) &&
      google_compute_firewall.runtime_to_workers[0].target_tags == toset(["${local.name}-workers"]) &&
      one(google_compute_firewall.runtime_to_workers[0].allow).ports == tolist(["9400"]) &&
      one(google_compute_firewall.runtime_to_workers[0].allow).protocol == "tcp"
    )
    error_message = "Discovery requires private DNS and TCP 9400 from explicit runtime ranges to worker nodes only."
  }
}

run "discovery_rejects_public_runtime_ingress" {
  command = plan
  module { source = "./modules/gke-isolated-workers-network" }
  variables {
    network        = "primary"
    primary_subnet = "primary"
    config = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
      discovery          = { dns_name = "test.isolated.internal", runtime_source_ranges = ["0.0.0.0/0"] }
    }
  }
  expect_failures = [var.config]
}

run "https_preserves_primary_denies_and_explicit_exceptions" {
  command = apply
  module { source = "./modules/gke-isolated-workers-network" }
  variables {
    network        = "https://www.googleapis.com/compute/v1/projects/braintrust-test/global/networks/primary"
    primary_subnet = "https://www.googleapis.com/compute/v1/projects/braintrust-test/regions/us-central1/subnetworks/primary"
    primary_cidrs  = ["11.20.0.0/20"]
    config = {
      node_cidr          = "10.60.0.0/24"
      pod_cidr           = "10.64.0.0/18"
      service_cidr       = "10.65.0.0/22"
      control_plane_cidr = "10.60.1.0/28"
      discovery          = { dns_name = "test.isolated.internal", runtime_source_ranges = ["12.20.0.0/20"] }
      egress_rules       = { proxy = { destination_ranges = ["10.90.0.4/32"], ports = ["8443"] } }
    }
  }
  assert {
    condition = (
      contains(google_compute_firewall.private_egress.destination_ranges, "11.20.0.0/20") &&
      contains(google_compute_firewall.private_egress.destination_ranges, "12.20.0.0/20") &&
      google_compute_firewall.egress["proxy"].priority < google_compute_firewall.private_egress.priority &&
      one(google_compute_firewall.egress["proxy"].allow).ports == tolist(["8443"])
    )
    error_message = "Public HTTPS must not bypass known primary ranges. Explicit private egress must remain scoped and take precedence."
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
run "isolated_node_identity_roles" {
  command = apply
  module { source = "./modules/gke-cluster" }
  variables {
    project_id                           = "braintrust-test"
    gke_services_node_service_account_id = "braintrust-services-nodes"
    region                               = "us-central1"
    gke_cluster_mode                     = "standard"
    gke_network                          = "primary"
    gke_subnetwork                       = "workers"
    gke_kms_cmek_id                      = "key"
  }
  assert {
    condition = (
      google_service_account.services_nodes[0].account_id == "braintrust-services-nodes" &&
      toset(keys(google_project_iam_member.services_nodes)) == toset(["roles/container.defaultNodeServiceAccount", "roles/logging.logWriter", "roles/monitoring.metricWriter", "roles/stackdriver.resourceMetadata.writer"]) &&
      alltrue([for grant in google_project_iam_member.services_nodes : grant.member == "serviceAccount:${output.gke_services_node_service_account_email}"])
    )
    error_message = "Node IAM must grant only the required node roles to its dedicated identity."
  }
}

run "one_block_and_automatic_runtime_ranges" {
  override_resource {
    target = module.gke_isolated_workers_cluster[0].google_service_account.services_nodes[0]
    values = {
      email = "isolated-services@braintrust-test.iam.gserviceaccount.com"
      id    = "projects/braintrust-test/serviceAccounts/isolated-services@braintrust-test.iam.gserviceaccount.com"
    }
  }

  override_data {
    target = data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.storage.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  override_data {
    target = module.redis.data.google_project.current
    values = { project_id = "braintrust-test", number = "123456789012" }
  }

  command = apply
  variables {
    gke_isolated_workers = {
      network_cidr = "10.64.0.0/16"
      discovery    = { dns_name = "test.isolated.internal" }
    }
  }
  assert {
    condition = (
      output.gke_isolated_workers.node_cidr == "10.64.64.0/24" &&
      output.gke_isolated_workers.pod_cidr == "10.64.0.0/18" &&
      output.gke_isolated_workers.service_cidr == "10.64.68.0/22" &&
      local.isolated_network_config.control_plane_cidr == "10.64.72.0/28" &&
      local.isolated_network_config.discovery.runtime_source_ranges == toset([var.subnet_cidr_range, "10.20.0.0/20"])
    )
    error_message = "One block must produce disjoint cluster ranges and derive runtime access from the primary cluster."
  }
}
