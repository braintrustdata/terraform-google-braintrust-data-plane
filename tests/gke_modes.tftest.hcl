mock_provider "google" {
  override_data {
    target = data.google_client_config.current
    values = {
      region = "us-central1"
    }
  }

  override_data {
    target = data.google_project.current
    values = {
      number     = "123456789012"
      project_id = "braintrust-test"
    }
  }
}

mock_provider "google-beta" {}
mock_provider "random" {}

run "autopilot_is_the_default" {
  command = plan

  override_module {
    target = module.gke-cluster
    outputs = {
      gke_cluster_name               = "braintrust-gke-autopilot"
      gke_cluster_endpoint           = "https://autopilot.example.test"
      gke_cluster_master_version     = "1.33.0"
      gke_cluster_id                 = "projects/braintrust-test/locations/us-central1/clusters/braintrust-gke-autopilot"
      gke_cluster_location           = "us-central1"
      gke_node_service_account_email = "braintrust-gke-cluster@braintrust-test.iam.gserviceaccount.com"
      workload_identity_pool         = "braintrust-test.svc.id.goog"
    }
  }

  variables {
    deployment_name = "braintrust"
  }

  assert {
    condition     = output.gke_cluster_mode == "autopilot"
    error_message = "The default GKE cluster mode must remain Autopilot."
  }

  assert {
    condition     = output.gke_cluster_name == "braintrust-gke-autopilot"
    error_message = "The default Autopilot cluster name must remain unchanged."
  }

  assert {
    condition     = length(output.gke_node_pool_names) == 0
    error_message = "Autopilot mode must not create Standard node pools."
  }
}

run "standard_creates_default_node_pools" {
  command = plan

  override_module {
    target = module.gke-cluster
    outputs = {
      gke_cluster_name               = "braintrust-gke-standard"
      gke_cluster_endpoint           = "https://standard.example.test"
      gke_cluster_master_version     = "1.33.0"
      gke_cluster_id                 = "projects/braintrust-test/locations/us-central1/clusters/braintrust-gke-standard"
      gke_cluster_location           = "us-central1"
      gke_node_service_account_email = "braintrust-gke-cluster@braintrust-test.iam.gserviceaccount.com"
      workload_identity_pool         = "braintrust-test.svc.id.goog"
    }
  }

  variables {
    deployment_name  = "braintrust"
    gke_cluster_mode = "standard"
  }

  assert {
    condition     = output.gke_cluster_mode == "standard"
    error_message = "The Standard configuration must report Standard mode."
  }

  assert {
    condition     = output.gke_cluster_name == "braintrust-gke-standard"
    error_message = "The Standard cluster must use the Standard cluster suffix."
  }

  assert {
    condition     = output.gke_node_pool_names == { api = "api", brainstore = "brainstore" }
    error_message = "Standard mode must create the default API and Brainstore node pools."
  }
}

run "brainstore_requires_a_local_ssd_machine_type" {
  command = plan

  override_module {
    target = module.gke-cluster
    outputs = {
      gke_cluster_name               = "braintrust-gke-standard"
      gke_cluster_endpoint           = "https://standard.example.test"
      gke_cluster_master_version     = "1.33.0"
      gke_cluster_id                 = "projects/braintrust-test/locations/us-central1/clusters/braintrust-gke-standard"
      gke_cluster_location           = "us-central1"
      gke_node_service_account_email = "braintrust-gke-cluster@braintrust-test.iam.gserviceaccount.com"
      workload_identity_pool         = "braintrust-test.svc.id.goog"
    }
  }

  variables {
    deployment_name  = "braintrust"
    gke_cluster_mode = "standard"
    gke_standard_node_pools = {
      api = {
        machine_type         = "c4a-standard-16"
        total_min_node_count = 2
        total_max_node_count = 10
      }
      brainstore = {
        machine_type         = "c4a-standard-48"
        total_min_node_count = 3
        total_max_node_count = 10
      }
    }
  }

  expect_failures = [var.gke_standard_node_pools]
}

run "standard_requires_a_brainstore_pool" {
  command = plan

  override_module {
    target = module.gke-cluster
    outputs = {
      gke_cluster_name               = "braintrust-gke-standard"
      gke_cluster_endpoint           = "https://standard.example.test"
      gke_cluster_master_version     = "1.33.0"
      gke_cluster_id                 = "projects/braintrust-test/locations/us-central1/clusters/braintrust-gke-standard"
      gke_cluster_location           = "us-central1"
      gke_node_service_account_email = "braintrust-gke-cluster@braintrust-test.iam.gserviceaccount.com"
      workload_identity_pool         = "braintrust-test.svc.id.goog"
    }
  }

  variables {
    deployment_name  = "braintrust"
    gke_cluster_mode = "standard"
    gke_standard_node_pools = {
      api = {
        machine_type         = "c4a-standard-16"
        total_min_node_count = 2
        total_max_node_count = 10
      }
    }
  }

  expect_failures = [var.gke_standard_node_pools]
}

run "brainstore_accepts_x86_local_ssd_machine_types" {
  command = plan

  override_module {
    target = module.gke-cluster
    outputs = {
      gke_cluster_name               = "braintrust-gke-standard"
      gke_cluster_endpoint           = "https://standard.example.test"
      gke_cluster_master_version     = "1.33.0"
      gke_cluster_id                 = "projects/braintrust-test/locations/us-central1/clusters/braintrust-gke-standard"
      gke_cluster_location           = "us-central1"
      gke_node_service_account_email = "braintrust-gke-cluster@braintrust-test.iam.gserviceaccount.com"
      workload_identity_pool         = "braintrust-test.svc.id.goog"
    }
  }

  variables {
    deployment_name  = "braintrust"
    gke_cluster_mode = "standard"
    gke_standard_node_pools = {
      api = {
        machine_type         = "c4a-standard-16"
        total_min_node_count = 2
        total_max_node_count = 10
      }
      brainstore = {
        machine_type         = "c4-standard-48-lssd"
        total_min_node_count = 3
        total_max_node_count = 10
      }
    }
  }

  assert {
    condition     = output.gke_node_pool_names == { api = "api", brainstore = "brainstore" }
    error_message = "Standard mode must create the configured node pools."
  }
}
