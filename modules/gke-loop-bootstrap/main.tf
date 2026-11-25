data "google_client_config" "current" {}
data "google_project" "current" {
  project_id = data.google_client_config.current.project
}

locals {
  name                      = "${substr(replace(var.deployment_name, "_", "-"), 0, 14)}-${substr(sha256(var.deployment_name), 0, 6)}-loop"
  versions                  = jsondecode(file("${path.module}/VERSIONS.json"))
  installer_service_account = var.deploy_service_account_email != null ? var.deploy_service_account_email : google_service_account.installer[0].email
  secret_ids = {
    seed   = "${local.name}-tls-seed"
    server = "${local.name}-server-tls"
    client = "${split("@", var.runtime_service_account)[0]}-client-tls"
  }
  config = {
    project          = data.google_project.current.project_id
    endpoint         = var.endpoint
    namespace        = var.workers.discovery.external_dns_namespace
    hostname         = var.workers.discovery.hostname
    checkpoint_store = var.workers.checkpoint_store
    dns_args         = var.workers.discovery.external_dns_extra_args
    services_version = coalesce(var.options.services_version, local.versions.services_version)
    replicas         = var.options.worker_replicas
    overrides        = jsondecode(var.options.worker_helm_values == "" ? "{}" : jsonencode(yamldecode(var.options.worker_helm_values)))
    license_secret   = var.options.brainstore_license_secret_name
    telemetry        = var.options.control_plane_telemetry
    secrets          = { for kind, secret in google_secret_manager_secret.tls : kind => secret.id }
    helm_url         = local.versions.helm_url
    helm_sha256      = local.versions.helm_sha256
    chart_url        = local.versions.chart_url
    chart_sha256     = local.versions.chart_sha256
  }
  command  = ["python3"]
  revision = substr(sha256(jsonencode({ config = local.config, script = filesha256("${path.module}/bootstrap.py"), image = local.versions.image, command = local.command, service_account = local.installer_service_account })), 0, 20)
}

resource "google_project_service" "bootstrap" {
  for_each           = toset(["run.googleapis.com", "secretmanager.googleapis.com"])
  project            = data.google_project.current.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "installer" {
  count        = var.deploy_service_account_email == null ? 1 : 0
  account_id   = local.name
  display_name = "Loop worker installer"
}

resource "google_project_iam_member" "installer_cluster" {
  count   = var.deploy_service_account_email == null ? 1 : 0
  project = data.google_project.current.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${local.installer_service_account}"
}

resource "google_secret_manager_secret" "tls" {
  for_each  = local.secret_ids
  secret_id = each.value
  replication {
    auto {}
  }
  depends_on = [google_project_service.bootstrap]
}

resource "google_secret_manager_secret_iam_member" "installer_read" {
  for_each  = local.secret_ids
  secret_id = google_secret_manager_secret.tls[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.installer_service_account}"
}

resource "google_secret_manager_secret_iam_member" "installer_write" {
  for_each  = local.secret_ids
  secret_id = google_secret_manager_secret.tls[each.key].id
  role      = "roles/secretmanager.secretVersionAdder"
  member    = "serviceAccount:${local.installer_service_account}"
}

resource "google_secret_manager_secret_iam_member" "runtime" {
  secret_id = google_secret_manager_secret.tls["client"].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.runtime_service_account}"
}

resource "google_project_iam_member" "license" {
  count   = var.options.brainstore_license_secret_name == "" ? 0 : 1
  project = data.google_project.current.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${local.installer_service_account}"
  condition {
    title      = "loop-worker-telemetry-license"
    expression = "resource.name == 'projects/${data.google_project.current.number}/secrets/${var.options.brainstore_license_secret_name}' || resource.name.startsWith('projects/${data.google_project.current.number}/secrets/${var.options.brainstore_license_secret_name}/versions/')"
  }
}

resource "terraform_data" "execution" {
  triggers_replace = local.revision
}

resource "google_cloud_run_v2_job" "install" {
  project             = data.google_project.current.project_id
  name                = "${local.name}-setup"
  location            = var.region
  deletion_protection = false
  run_execution_token = "r${substr(sha256(terraform_data.execution.id), 0, 20)}"
  template {
    template {
      service_account = local.installer_service_account
      timeout         = "3000s"
      max_retries     = 0
      containers {
        image   = local.versions.image
        command = local.command
        args    = ["-c", file("${path.module}/bootstrap.py")]
        env {
          name  = "LOOP_BOOTSTRAP_CONFIG"
          value = jsonencode(local.config)
        }
        resources {
          limits = { cpu = "1", memory = "1Gi" }
        }
      }
    }
  }
  timeouts {
    create = "60m"
    update = "60m"
  }
  depends_on = [
    google_project_service.bootstrap,
    google_project_iam_member.installer_cluster,
    google_project_iam_member.license,
    google_secret_manager_secret_iam_member.installer_read,
    google_secret_manager_secret_iam_member.installer_write,
    google_secret_manager_secret_iam_member.runtime,
  ]
}

# Refresh credentials after long installs, and defer the check during retries.
data "google_client_config" "installer_check" {
  depends_on = [google_cloud_run_v2_job.install]
}

data "http" "ready" {
  url                = "https://run.googleapis.com/v2/${google_cloud_run_v2_job.install.id}/executions/${google_cloud_run_v2_job.install.name}-${google_cloud_run_v2_job.install.run_execution_token}?fields=conditions(type,state)"
  request_timeout_ms = 30000
  request_headers = {
    Authorization = "Bearer ${data.google_client_config.installer_check.access_token}"
  }
  lifecycle {
    postcondition {
      condition = self.status_code == 200 && try(
        anytrue([for condition in jsondecode(self.response_body).conditions : condition.type == "Completed" && condition.state == "CONDITION_SUCCEEDED"]),
        false
      )
      error_message = "Loop worker installation did not succeed. Fix the execution failure, then retry by replacing this bootstrap module's terraform_data.execution resource; see ISOLATED_WORKERS.md."
    }
  }
}
