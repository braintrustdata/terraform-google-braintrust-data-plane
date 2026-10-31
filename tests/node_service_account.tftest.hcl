mock_provider "google" {
  mock_data "google_client_config" {
    defaults = {
      project = "test-project"
      region  = "us-central1"
    }
  }
  mock_resource "google_service_account" {
    defaults = {
      email = "bt-test-gke-cluster@test-project.iam.gserviceaccount.com"
    }
  }
}

override_data {
  target = data.google_project.current
  values = {
    project_id = "test-project"
    number     = "123456789012"
  }
}

variables {
  deployment_name = "bt-test"
  gke_network     = "projects/test-project/global/networks/test"
  gke_subnetwork  = "projects/test-project/regions/us-central1/subnetworks/test"
  gke_kms_cmek_id = "projects/test-project/locations/us-central1/keyRings/test/cryptoKeys/test"
}

run "dedicated_node_identity" {
  command = apply
  module {
    source = "./modules/gke-cluster"
  }

  assert {
    condition     = google_container_cluster.braintrust_autopilot.cluster_autoscaling[0].auto_provisioning_defaults[0].service_account == google_service_account.gke.email
    error_message = "Autopilot must use the dedicated node service account."
  }

  assert {
    condition     = google_project_iam_member.gke_default_node_sa.role == "roles/container.defaultNodeServiceAccount" && google_project_iam_member.gke_default_node_sa.member == "serviceAccount:${google_service_account.gke.email}" && google_project_iam_member.gke_default_node_sa.project == "test-project"
    error_message = "The node account must receive the minimum GKE role on the cluster project."
  }

  assert {
    condition     = google_container_cluster.braintrust_autopilot.workload_identity_config[0].workload_pool == "test-project.svc.id.goog"
    error_message = "Application identities must retain the project workload pool."
  }

  assert {
    condition     = google_kms_crypto_key_iam_member.gke_cluster_cmek.member == "serviceAccount:service-123456789012@container-engine-robot.iam.gserviceaccount.com" && google_kms_crypto_key_iam_member.gke_compute_cmek.member == "serviceAccount:service-123456789012@compute-system.iam.gserviceaccount.com"
    error_message = "CMEK access must remain on the GKE and Compute Engine service agents."
  }

  assert {
    condition     = output.gke_node_service_account_email == google_service_account.gke.email
    error_message = "The output must identify the node account for private repository grants."
  }
}
