mock_provider "google" {}

variables {
  deployment_name        = "braintrust"
  name                   = "services"
  project_id             = "braintrust-test"
  location               = "us-central1"
  cluster_node_locations = ["us-central1-a", "us-central1-b", "us-central1-c"]
  cluster_id             = "projects/braintrust-test/locations/us-central1/clusters/braintrust-test"
  service_account_email  = "nodes@braintrust-test.iam.gserviceaccount.com"
  boot_disk_kms_key      = "projects/braintrust-test/locations/us-central1/keyRings/test/cryptoKeys/nodes"
  machine_type           = "c4a-standard-16"
  total_min_node_count   = 2
  total_max_node_count   = 10
}

run "explicit_opt_out_omits_drain_configuration" {
  command = plan

  module {
    source = "./modules/gke-node-pool"
  }

  variables {
    respect_pdb_on_delete = false
  }

  assert {
    condition     = length(google_container_node_pool.this.node_drain_config) == 0
    error_message = "The explicit opt-out must omit drain configuration."
  }
}

run "default_protection_omits_custom_timeouts" {
  command = plan

  module {
    source = "./modules/gke-node-pool"
  }

  assert {
    condition     = google_container_node_pool.this.node_drain_config[0].respect_pdb_during_node_pool_deletion
    error_message = "The PDB option must enable PDB protection during pool deletion."
  }

  assert {
    condition = (
      google_container_node_pool.this.node_drain_config[0].pdb_timeout_duration == null &&
      google_container_node_pool.this.node_drain_config[0].grace_termination_duration == null
    )
    error_message = "The PDB option must not send custom drain timeout values."
  }
}

run "initial_capacity_rounds_up_across_cluster_zones" {
  command = plan
  module { source = "./modules/gke-node-pool" }
  variables { total_min_node_count = 5 }
  assert {
    condition     = google_container_node_pool.this.initial_node_count == 2
    error_message = "Five nodes across three zones must start with two nodes per zone."
  }
}

run "explicit_zones_control_initial_capacity" {
  command = plan
  module { source = "./modules/gke-node-pool" }
  variables {
    total_min_node_count = 5
    node_locations       = ["us-central1-a"]
  }
  assert {
    condition     = google_container_node_pool.this.initial_node_count == 5
    error_message = "A single-zone pool must start with the configured total minimum."
  }
}

run "create_services_pool" {
  command = apply
  module { source = "./modules/gke-node-pool" }
}

run "minimum_change_keeps_pool" {
  command = apply
  module { source = "./modules/gke-node-pool" }
  variables { total_min_node_count = 5 }
  assert {
    condition     = google_container_node_pool.this.id == run.create_services_pool.id
    error_message = "An autoscaler minimum change must preserve the pool."
  }
}

run "architecture_change_replaces_services_pool" {
  command = apply
  module { source = "./modules/gke-node-pool" }
  variables { machine_type = "c4-standard-16" }
  assert {
    condition     = google_container_node_pool.this.id != run.create_services_pool.id
    error_message = "An architecture change must replace the services pool."
  }
}

run "pool_key_controls_workload_label" {
  command = plan
  module { source = "./modules/gke-node-pool" }
  variables {
    name         = "brainstore"
    machine_type = "c4-standard-48-lssd"
    labels       = { "braintrust/node-pool" = "incorrect" }
  }
  assert {
    condition     = google_container_node_pool.this.node_config[0].labels["braintrust/node-pool"] == "brainstore"
    error_message = "The pool key must determine the workload label, even with custom labels."
  }
}
