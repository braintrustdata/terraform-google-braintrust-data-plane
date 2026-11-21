mock_provider "google" {
  mock_data "google_client_config" { defaults = { project = "test-project", region = "us-central1" } }
  mock_data "google_project" { defaults = { project_id = "test-project", number = "123456789012" } }
}
override_resource {
  target = google_secret_manager_secret.tls["client"]
  values = { id = "projects/test-project/secrets/runtime-client-tls" }
}
variables {
  deployment_name = "example-prod"
  region          = "us-central1"
  cluster = {
    id       = "projects/test-project/locations/us-central1/clusters/workers"
    endpoint = "https://workers.example.gke.goog"
  }
  runtime_service_account = "example-loop@test-project.iam.gserviceaccount.com"
  workers = {
    checkpoint_store = "gs://example-checkpoints/filesystems"
    discovery = {
      hostname                = "workers.sandbox.example.internal"
      external_dns_namespace  = "braintrust-sandbox"
      external_dns_extra_args = ["--google-project=test-project"]
    }
  }
}
run "apply_executes_bootstrap_and_exports_only_a_runtime_secret_reference" {
  command = apply
  module { source = "./modules/gke-loop-bootstrap" }
  assert {
    condition = (
      length(google_secret_manager_secret.tls) == 3 &&
      output.client_tls_secret == "projects/test-project/secrets/runtime-client-tls/versions/latest" &&
      !issensitive(output.client_tls_secret) &&
      output.services_version == jsondecode(file("modules/gke-loop-bootstrap/VERSIONS.json")).services_version &&
      startswith(google_cloud_run_v2_job.install.run_execution_token, "r") &&
      google_cloud_run_v2_job.install.template[0].template[0].service_account == google_service_account.installer.email
    )
    error_message = "An apply must run the bootstrap to completion and expose only a client secret reference and matching service version."
  }
  assert {
    condition = (
      google_secret_manager_secret_iam_member.runtime.secret_id == google_secret_manager_secret.tls["client"].id &&
      google_secret_manager_secret_iam_member.runtime.secret_id != google_secret_manager_secret.tls["seed"].id &&
      google_secret_manager_secret_iam_member.runtime.secret_id != google_secret_manager_secret.tls["server"].id &&
      google_secret_manager_secret_iam_member.runtime.member == "serviceAccount:${var.runtime_service_account}" &&
      google_secret_manager_secret_iam_member.runtime.role == "roles/secretmanager.secretAccessor" &&
      google_project_iam_member.installer_cluster.condition[0].expression == "resource.name == '${var.cluster.id}'"
    )
    error_message = "Runtime access must be client-only; installer cluster administration must be conditional on this worker cluster."
  }
  assert {
    condition = (
      local.config.endpoint == var.cluster.endpoint &&
      local.config.namespace == var.workers.discovery.external_dns_namespace &&
      local.config.checkpoint_store == var.workers.checkpoint_store &&
      !strcontains(jsonencode(local.config), "PRIVATE KEY") &&
      google_cloud_run_v2_job.install.template[0].template[0].containers[0].args[0] == "-c" &&
      google_cloud_run_v2_job.install.template[0].template[0].containers[0].args[1] == file("modules/gke-loop-bootstrap/bootstrap.py")
    )
    error_message = "Bootstrap must install the actual packaged script against the worker cluster, with no generated credentials in its config."
  }
}
run "worker_changes_rerun_the_job_and_allow_draining_to_zero" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  variables {
    options = {
      services_version               = "custom-build"
      worker_replicas                = 0
      worker_helm_values             = "env:\n  - name: CUSTOM_SETTING\n    value: keep\n"
      brainstore_license_secret_name = ""
    }
  }
  assert {
    condition     = local.config.replicas == 0 && local.config.services_version == "custom-build" && local.config.overrides.env[0].value == "keep" && length(google_project_iam_member.license) == 0 && output.revision != run.apply_executes_bootstrap_and_exports_only_a_runtime_secret_reference.revision
    error_message = "Worker changes must trigger a new execution while preserving drain-to-zero and custom settings."
  }
}
run "reject_invalid_worker_capacity" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  variables { options = { worker_replicas = -1 } }
  expect_failures = [var.options]
}
