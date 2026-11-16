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

run "dedicated_node_identity" {
  command = apply
  module {
    source = "./modules/gke-cluster"
  }

  assert {
    condition     = google_container_cluster.braintrust.cluster_autoscaling[0].auto_provisioning_defaults[0].service_account == google_service_account.gke.email
    error_message = "Autopilot must use the dedicated node service account."
  }

  assert {
    condition     = google_project_iam_member.gke_default_node_sa.role == "roles/container.defaultNodeServiceAccount" && google_project_iam_member.gke_default_node_sa.member == "serviceAccount:${google_service_account.gke.email}" && google_project_iam_member.gke_default_node_sa.project == "test-project"
    error_message = "The node account must receive the minimum GKE role on the cluster project."
  }

  assert {
    condition     = google_container_cluster.braintrust.workload_identity_config[0].workload_pool == "test-project.svc.id.goog"
    error_message = "Application identities must retain the project workload pool."
  }

  assert {
    condition     = output.gke_node_service_account_email == google_service_account.gke.email
    error_message = "The output must identify the node account for private repository grants."
  }

  assert {
    condition     = google_project_iam_member.gke_stackdriver_writer.role == "roles/stackdriver.resourceMetadata.writer" && google_project_iam_member.gke_stackdriver_writer.member == "serviceAccount:${google_service_account.gke.email}" && google_project_iam_member.gke_stackdriver_writer.project == "test-project"
    error_message = "The node account must retain metadata access for Cloud Monitoring."
  }
}
