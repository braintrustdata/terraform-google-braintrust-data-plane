mock_provider "google" {
  mock_data "google_client_config" { defaults = { project = "test-project", region = "us-central1" } }
  mock_data "google_project" { defaults = { project_id = "test-project", number = "123456789012" } }
}
mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 200
      response_body = "{\"conditions\":[{\"type\":\"Completed\",\"state\":\"CONDITION_SUCCEEDED\"}]}"
    }
  }
}
override_resource {
  target = google_secret_manager_secret.tls["client"]
  values = { id = "projects/test-project/secrets/runtime-client-tls" }
}
variables {
  deployment_name         = "example-prod"
  region                  = "us-central1"
  endpoint                = "https://workers.example.gke.goog"
  runtime_service_account = "example-loop@test-project.iam.gserviceaccount.com"
  workers = {
    checkpoint_store = "gs://example-checkpoints/filesystems"
    discovery = {
      hostname                = "workers.sandbox.example.internal"
      endpoint                = "https://workers.sandbox.example.internal:9400"
      external_dns_namespace  = "braintrust-sandbox"
      external_dns_extra_args = ["--google-project=test-project"]
    }
    loop_egress = {
      address       = "10.82.64.2"
      url           = "http://loop-egress.sandbox.example.internal:4002"
      source_ranges = ["10.82.64.0/24", "10.82.0.0/18"]
    }
  }
}
run "apply_executes_bootstrap_and_exports_only_a_runtime_secret_reference" {
  command = apply
  module { source = "./modules/gke-loop-bootstrap" }
  assert {
    condition = (
      toset(keys(google_project_service.bootstrap)) == toset(["run.googleapis.com", "secretmanager.googleapis.com"]) &&
      length(google_secret_manager_secret.tls) == 3 &&
      output.client_tls_secret == "projects/test-project/secrets/runtime-client-tls/versions/latest" &&
      !issensitive(output.client_tls_secret) &&
      output.services_version == jsondecode(file("modules/gke-loop-bootstrap/VERSIONS.json")).services_version &&
      startswith(google_cloud_run_v2_job.install.run_execution_token, "r") &&
      length(google_service_account.installer) == 1 &&
      google_cloud_run_v2_job.install.template[0].template[0].service_account == google_service_account.installer[0].email
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
      google_project_iam_member.installer_cluster[0].role == "roles/container.admin" &&
      google_project_iam_member.installer_cluster[0].project == "test-project" &&
      google_project_iam_member.installer_cluster[0].member == "serviceAccount:${google_service_account.installer[0].email}" &&
      length(google_project_iam_member.installer_cluster[0].condition) == 0
    )
    error_message = "Runtime access must be client-only; the automatic installer needs project-scoped Kubernetes administration, which cannot use a cluster-name IAM condition."
  }
  assert {
    condition = (
      local.config.endpoint == var.endpoint &&
      local.config.namespace == var.workers.discovery.external_dns_namespace &&
      local.config.checkpoint_store == var.workers.checkpoint_store &&
      yamldecode(output.helm_values_yaml).loopRuntime.sandbox.dnsUrl == var.workers.discovery.endpoint &&
      tolist(yamldecode(output.helm_values_yaml).loopRuntime.sandbox.egressGateway.sourceRanges) == var.workers.loop_egress.source_ranges &&
      yamldecode(output.helm_values_yaml).loopRuntime.serviceAccount.googleServiceAccount == var.runtime_service_account &&
      yamldecode(output.helm_values_yaml).loopRuntime.sandbox.clientTlsSecret == output.client_tls_secret &&
      output.loop_runtime.helm_values_yaml == output.helm_values_yaml &&
      !output.loop_runtime.services_version_pinned &&
      !strcontains(jsonencode(local.config), "PRIVATE KEY") &&
      google_cloud_run_v2_job.install.template[0].template[0].containers[0].args[0] == "-c" &&
      google_cloud_run_v2_job.install.template[0].template[0].containers[0].args[1] == file("modules/gke-loop-bootstrap/bootstrap.py")
    )
    error_message = "Bootstrap must install the actual packaged script against the worker cluster, with no generated credentials in its config."
  }
}
run "reuse_existing_deployment_identity_without_another_admin_grant" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  variables { deploy_service_account_email = "deploy@test-project.iam.gserviceaccount.com" }
  assert {
    condition = (
      length(google_service_account.installer) == 0 &&
      length(google_project_iam_member.installer_cluster) == 0 &&
      google_cloud_run_v2_job.install.template[0].template[0].service_account == var.deploy_service_account_email &&
      alltrue([for grant in google_secret_manager_secret_iam_member.installer_read : grant.member == "serviceAccount:${var.deploy_service_account_email}"]) &&
      alltrue([for grant in google_secret_manager_secret_iam_member.installer_write : grant.member == "serviceAccount:${var.deploy_service_account_email}"]) &&
      google_project_iam_member.license[0].member == "serviceAccount:${var.deploy_service_account_email}" &&
      output.revision != run.apply_executes_bootstrap_and_exports_only_a_runtime_secret_reference.revision
    )
    error_message = "A supplied deployment identity must run the job with secret access and trigger a rerun, without creating another privileged identity or granting Kubernetes administration."
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
    condition     = local.config.replicas == 0 && local.config.services_version == "custom-build" && local.config.overrides.env[0].value == "keep" && length(google_project_iam_member.license) == 0 && output.revision != run.apply_executes_bootstrap_and_exports_only_a_runtime_secret_reference.revision && output.loop_runtime.services_version_pinned
    error_message = "Worker changes must trigger a new execution while preserving drain-to-zero and custom settings."
  }
}
run "worker_capacity_changes_do_not_restart_the_primary_runtime" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  variables { options = { worker_replicas = 0, control_plane_telemetry = "" } }
  assert {
    condition = (
      output.revision != run.apply_executes_bootstrap_and_exports_only_a_runtime_secret_reference.revision &&
      output.helm_values_yaml == run.apply_executes_bootstrap_and_exports_only_a_runtime_secret_reference.helm_values_yaml
    )
    error_message = "Worker configuration must rerun the installer without changing the primary runtime's Pod template."
  }
}
run "reject_invalid_worker_capacity" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  variables { options = { worker_replicas = -1 } }
  expect_failures = [var.options]
}

run "drain_executes_with_a_new_token" {
  command = apply
  module { source = "./modules/gke-loop-bootstrap" }
  variables { options = { worker_replicas = 0 } }
  assert {
    condition     = output.execution_token != run.apply_executes_bootstrap_and_exports_only_a_runtime_secret_reference.execution_token
    error_message = "Changing capacity must create a new installer execution."
  }
}

run "restoring_the_original_configuration_executes_again" {
  command = apply
  module { source = "./modules/gke-loop-bootstrap" }
  assert {
    condition = (
      output.revision == run.apply_executes_bootstrap_and_exports_only_a_runtime_secret_reference.revision &&
      output.execution_token != run.apply_executes_bootstrap_and_exports_only_a_runtime_secret_reference.execution_token &&
      output.execution_token != run.drain_executes_with_a_new_token.execution_token
    )
    error_message = "Restoring the original settings must not reuse a previous Cloud Run execution name."
  }
}

run "unchanged_configuration_keeps_the_execution_token" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  variables { options = { services_version = "" } }
  assert {
    condition     = output.execution_token == run.restoring_the_original_configuration_executes_again.execution_token && !output.loop_runtime.services_version_pinned
    error_message = "A no-op plan must not launch an installer; an empty image override still uses the default version."
  }
}

run "failed_installation_blocks_ready_outputs" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  override_data {
    target = data.http.ready
    values = {
      status_code   = 200
      response_body = "{\"conditions\":[{\"type\":\"Completed\",\"state\":\"CONDITION_FAILED\"}]}"
    }
  }
  expect_failures = [data.http.ready]
}

run "missing_execution_does_not_mark_the_installation_ready" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  override_data {
    target = data.http.ready
    values = {
      status_code   = 404
      response_body = "{}"
    }
  }
  expect_failures = [data.http.ready]
}

run "started_execution_does_not_mark_the_installation_ready" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  override_data {
    target = data.http.ready
    values = {
      status_code   = 200
      response_body = "{\"conditions\":[{\"type\":\"Started\",\"state\":\"CONDITION_SUCCEEDED\"},{\"type\":\"Completed\",\"state\":\"CONDITION_RECONCILING\"}]}"
    }
  }
  expect_failures = [data.http.ready]
}

run "explicit_retry_executes_the_same_configuration_again" {
  command = apply
  module { source = "./modules/gke-loop-bootstrap" }
  plan_options { replace = [terraform_data.execution] }
  assert {
    condition = (
      output.revision == run.restoring_the_original_configuration_executes_again.revision &&
      output.execution_token != run.restoring_the_original_configuration_executes_again.execution_token
    )
    error_message = "Replacing only the execution trigger must retry the same worker configuration with a new token."
  }
}

run "grant_cloud_run_to_the_deployer_not_the_installer" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  variables {
    deployer_service_account_email = "deploy@test-project.iam.gserviceaccount.com"
    deploy_service_account_email   = "installer@test-project.iam.gserviceaccount.com"
  }
  assert {
    condition = (
      length(google_project_iam_member.deployer_run) == 1 &&
      google_project_iam_member.deployer_run[0].project == "test-project" &&
      google_project_iam_member.deployer_run[0].role == "roles/run.developer" &&
      google_project_iam_member.deployer_run[0].member == "serviceAccount:deploy@test-project.iam.gserviceaccount.com" &&
      google_cloud_run_v2_job.install.template[0].template[0].service_account == "installer@test-project.iam.gserviceaccount.com"
    )
    error_message = "Only the configured Terraform deployer should receive Cloud Run job management; execution must keep its separate identity."
  }
}

run "omit_cloud_run_grant_without_a_configured_deployer" {
  command = plan
  module { source = "./modules/gke-loop-bootstrap" }
  variables { deploy_service_account_email = "installer@test-project.iam.gserviceaccount.com" }
  assert {
    condition     = length(google_project_iam_member.deployer_run) == 0
    error_message = "A supplied installer is not evidence of the Terraform caller identity and must not receive job management implicitly."
  }
}
