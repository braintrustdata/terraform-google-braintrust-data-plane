mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      email = "bt-test-gke-cluster@test-project.iam.gserviceaccount.com"
    }
  }
}

variables {
  project_id      = "test-project"
  region          = "us-central1"
  deployment_name = "bt-test"
  gke_network     = "projects/test-project/global/networks/test"
  gke_subnetwork  = "projects/test-project/regions/us-central1/subnetworks/test"
  gke_kms_cmek_id = "projects/test-project/locations/us-central1/keyRings/test/cryptoKeys/test"
}

run "standard_node_identity" {
  command = apply
  module {
    source = "./modules/gke-cluster"
  }

  variables {
    gke_cluster_mode = "standard"
  }

  assert {
    condition     = google_container_cluster.braintrust.node_config[0].service_account == google_service_account.gke.email
    error_message = "Standard must use the dedicated node service account."
  }
}
