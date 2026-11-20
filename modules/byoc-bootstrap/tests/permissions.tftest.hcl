mock_provider "time" {}

mock_provider "google-beta" {}

mock_provider "google" {
  override_during = plan

  mock_data "google_project" {
    defaults = { project_id = "customer-project", number = "123456789012" }
  }
  mock_resource "google_project_iam_custom_role" {
    defaults = { name = "projects/customer-project/roles/mockRole" }
  }
}

override_resource {
  override_during = plan
  target          = google_service_account.bootstrap["deployment"]
  values = {
    name  = "projects/customer-project/serviceAccounts/deployment@customer-project.iam.gserviceaccount.com"
    email = "deployment@customer-project.iam.gserviceaccount.com"
  }
}
override_resource {
  override_during = plan
  target          = google_service_account.bootstrap["observer"]
  values = {
    name  = "projects/customer-project/serviceAccounts/observer@customer-project.iam.gserviceaccount.com"
    email = "observer@customer-project.iam.gserviceaccount.com"
  }
}
override_resource {
  override_during = plan
  target          = google_service_account.bootstrap["diagnostics"]
  values = {
    name  = "projects/customer-project/serviceAccounts/diagnostics@customer-project.iam.gserviceaccount.com"
    email = "diagnostics@customer-project.iam.gserviceaccount.com"
  }
}

variables {
  project_id                        = "customer-project"
  project_number                    = "123456789012"
  region                            = "us-central1"
  bootstrap_id                      = "bsp_019d1234-8abc-7def-8123-456789abc111"
  braintrust_bridge_service_account = "bootstrap-bridge@braintrust-byoc-staging.iam.gserviceaccount.com"
}

run "workload_roles_and_grants" {
  command = plan

  assert {
    condition = (
      toset(keys(google_project_iam_custom_role.deployment)) == toset([
        "iam", "gke", "kubernetes", "network", "sql", "kms", "redis", "storage", "secret_create", "secrets", "dns", "services", "storage_create"
      ]) &&
      toset(keys(google_project_iam_member.deployment)) == toset(keys(google_project_iam_custom_role.deployment)) &&
      alltrue([for grant in google_project_iam_member.deployment :
        grant.project == "customer-project" && grant.member == "serviceAccount:deployment@customer-project.iam.gserviceaccount.com"
      ]) &&
      google_project_iam_member.observer.member == "serviceAccount:observer@customer-project.iam.gserviceaccount.com"
    )
    error_message = "Only Deployment receives the workload roles, and Observer retains its separate identity."
  }
  assert {
    condition = alltrue([for role in values(google_project_iam_custom_role.deployment) :
      length(role.permissions) > 0 && length(role.permissions) == length(distinct(role.permissions)) &&
      alltrue([for permission in role.permissions : !strcontains(permission, "*")])
    ])
    error_message = "Every workload role must use explicit, nonempty, unique permissions."
  }
  assert {
    condition = (
      contains(google_project_iam_custom_role.deployment["iam"].permissions, "iam.serviceAccounts.create") &&
      contains(google_project_iam_custom_role.deployment["iam"].permissions, "iam.serviceAccounts.enable") &&
      contains(google_project_iam_custom_role.deployment["iam"].permissions, "iam.serviceAccounts.disable") &&
      contains(google_project_iam_custom_role.deployment["iam"].permissions, "iam.roles.undelete") &&
      contains(google_project_iam_custom_role.deployment["sql"].permissions, "cloudsql.users.create") &&
      contains(google_project_iam_custom_role.deployment["redis"].permissions, "redis.instances.updateAuth") &&
      contains(google_project_iam_custom_role.deployment["redis"].permissions, "redis.instances.getAuthString") &&
      contains(google_project_iam_custom_role.deployment["dns"].permissions, "dns.networks.bindPrivateDNSZone") &&
      contains(google_project_iam_custom_role.deployment["network"].permissions, "compute.networks.updatePolicy")
    )
    error_message = "Workload roles must cover the reviewed account recovery, initial SQL, Redis AUTH, private DNS, and network dependencies."
  }
  assert {
    condition = length(setintersection(toset(flatten([for role in values(google_project_iam_custom_role.deployment) : tolist(role.permissions)])), toset([
      "iam.serviceAccounts.getAccessToken", "iam.serviceAccounts.getOpenIdToken", "iam.serviceAccounts.signBlob", "iam.serviceAccounts.signJwt",
      "iam.serviceAccounts.implicitDelegation", "iam.serviceAccountKeys.create", "iam.serviceAccountKeys.upload",
      "container.clusters.getCredentials", "container.pods.exec", "container.pods.attach", "container.pods.portForward", "container.pods.getLogs",
      "container.pods.proxy", "container.nodes.proxy", "container.serviceAccounts.createToken", "container.clusterRoles.bind", "container.clusterRoles.escalate",
      "container.roles.bind", "container.roles.escalate", "storage.objects.get", "storage.objects.create", "storage.objects.update", "storage.objects.delete",
      "storage.hmacKeys.create", "cloudkms.cryptoKeyVersions.destroy", "cloudkms.cryptoKeyVersions.update", "cloudkms.cryptoKeyVersions.restore",
      "cloudkms.cryptoKeyVersions.useToDecrypt", "cloudkms.cryptoKeyVersions.useToEncrypt", "logging.logEntries.list", "logging.privateLogEntries.list",
      "serviceusage.services.disable", "serviceusage.services.enable", "cloudquotas.quotas.update", "cloudsql.instances.executeSql", "cloudsql.instances.login",
      "cloudsql.users.update", "cloudsql.instances.restoreBackup", "secretmanager.secrets.setIamPolicy"
    ]))) == 0
    error_message = "Normal workload roles must exclude token minting, sessions, logs, object payloads, destructive keys, quota writes, and unsupported SQL paths."
  }
  assert {
    condition = (
      length(google_project_iam_custom_role.license) == 0 && length(google_secret_manager_secret_iam_member.license) == 0 &&
      !output.bootstrap.issuable && !output.bootstrap.machine_execution_supported &&
      !output.bootstrap.diagnostics_activation_supported
    )
    error_message = "Provisional role definitions must not advertise live execution, Diagnostics, or unrequested license access."
  }
}

run "observer_health_without_workload_configuration" {
  command = plan
  assert {
    condition = (
      alltrue([for permission in google_project_iam_custom_role.foundation["observer"].permissions :
        endswith(permission, ".get") || endswith(permission, ".list")
      ]) &&
      alltrue([for permission in google_project_iam_custom_role.foundation["observer"].permissions :
        !startswith(permission, "container.") || contains(["container.clusters.get", "container.clusters.list", "container.operations.get"], permission)
      ]) &&
      length(setintersection(toset(google_project_iam_custom_role.foundation["observer"].permissions), toset([
        "storage.objects.get", "secretmanager.versions.access", "redis.instances.getAuthString", "cloudsql.users.list", "iam.serviceAccounts.getAccessToken",
        "logging.logEntries.list", "logging.privateLogEntries.list", "logging.views.access", "container.pods.get", "container.pods.getStatus",
        "container.deployments.get", "container.statefulSets.get", "container.replicaSets.get", "container.configMaps.get", "container.secrets.get"
      ]))) == 0 &&
      contains(google_project_iam_custom_role.foundation["observer"].permissions, "monitoring.timeSeries.list") &&
      contains(google_project_iam_custom_role.foundation["observer"].permissions, "compute.backendServices.get") &&
      contains(google_project_iam_custom_role.foundation["observer"].permissions, "cloudsql.instances.get") &&
      contains(google_project_iam_custom_role.foundation["observer"].permissions, "monitoring.alertPolicies.get")
    )
    error_message = "Observer health must use approved cloud APIs and metrics without workload specifications, credentials, payloads, or logs."
  }
}

run "loop_compatibility_without_interactive_access" {
  command = plan
  assert {
    condition = alltrue([for permission in [
      "container.statefulSets.create", "container.jobs.create", "container.daemonSets.create", "container.clusterRoles.create", "container.clusterRoleBindings.create",
      "container.customResourceDefinitions.create", "container.thirdPartyObjects.create", "container.validatingWebhookConfigurations.create",
      "container.mutatingWebhookConfigurations.create", "container.apiServices.create", "container.nodes.update", "container.pods.delete",
      "container.pods.evict", "container.statefulSets.getScale", "container.statefulSets.updateScale", "container.endpointSlices.list", "container.leases.update", "container.persistentVolumeClaims.create"
    ] : contains(google_project_iam_custom_role.deployment["kubernetes"].permissions, permission)])
    error_message = "Loop retains related worker lifecycle capabilities without a blanket cluster-admin or interactive grant."
  }
}

run "destination_and_secret_conditions" {
  command = plan
  assert {
    condition = (
      google_project_iam_member.deployment["storage"].condition[0].title == "exclude_bootstrap_buckets" &&
      strcontains(google_project_iam_member.deployment["storage"].condition[0].expression, "projects/_/buckets/${google_storage_bucket.state.name}") &&
      strcontains(google_project_iam_member.deployment["storage"].condition[0].expression, "projects/_/buckets/${google_storage_bucket.evidence.name}") &&
      google_project_iam_member.deployment["kms"].condition[0].title == "exclude_bootstrap_keys" &&
      google_project_iam_member.deployment["secrets"].condition[0].title == "module_postgres_secrets" &&
      strcontains(google_project_iam_member.deployment["secrets"].condition[0].expression, "-postgres-password") &&
      strcontains(google_project_iam_member.deployment["secrets"].condition[0].expression, "SecretVersion") &&
      length(google_project_iam_member.deployment["secret_create"].condition) == 0 &&
      toset(google_project_iam_custom_role.deployment["secret_create"].permissions) == toset(["secretmanager.secrets.create"])
    )
    error_message = "Direct workload grants must exclude bootstrap buckets and keys and scope managed secret access separately from project-level creation."
  }
}

run "existing_key_exclusion_paths" {
  command = plan
  variables {
    state_storage    = { location = "US", kms_key = "projects/key-project/locations/us/keyRings/customer/cryptoKeys/state" }
    evidence_storage = { location = "US", kms_key = "projects/key-project/locations/us/keyRings/customer/cryptoKeys/evidence" }
  }
  override_data {
    target = data.google_kms_crypto_key.existing_storage["projects/key-project/locations/us/keyRings/customer/cryptoKeys/state"]
    values = { purpose = "ENCRYPT_DECRYPT", primary = [{ name = "key-version", state = "ENABLED" }] }
  }
  override_data {
    target = data.google_kms_crypto_key.existing_storage["projects/key-project/locations/us/keyRings/customer/cryptoKeys/evidence"]
    values = { purpose = "ENCRYPT_DECRYPT", primary = [{ name = "key-version", state = "ENABLED" }] }
  }
  assert {
    condition = (
      strcontains(google_project_iam_member.deployment["kms"].condition[0].expression, "/locations/us/keyRings/customer/cryptoKeys/state") &&
      strcontains(google_project_iam_member.deployment["kms"].condition[0].expression, "/locations/us/keyRings/customer/cryptoKeys/evidence")
    )
    error_message = "Bootstrap key exclusions must follow selected existing key paths."
  }
}

run "exact_license_grants" {
  command = plan
  variables {
    license_secrets = [
      "projects/customer-project/secrets/brainstore-license-key",
      "projects/123456789012/secrets/second-license",
      "projects/license-project/secrets/external-license"
    ]
  }
  assert {
    condition = (
      length(google_secret_manager_secret_iam_member.license) == 3 &&
      toset(keys(google_project_iam_custom_role.license)) == toset(["customer-project", "license-project"]) &&
      alltrue([for role in google_project_iam_custom_role.license :
        toset(role.permissions) == toset(["secretmanager.secrets.get", "secretmanager.secrets.getIamPolicy", "secretmanager.versions.get", "secretmanager.versions.access"])
      ]) &&
      alltrue([for ref, grant in google_secret_manager_secret_iam_member.license :
        grant.secret_id == ref && grant.member == "serviceAccount:deployment@customer-project.iam.gserviceaccount.com"
      ]) &&
      google_secret_manager_secret_iam_member.license["projects/license-project/secrets/external-license"].project == "license-project"
    )
    error_message = "License grants must be read-only on exact references, with roles in the secret-owning project."
  }
}

run "diagnostics_opt_out_keeps_workload_boundary" {
  command = plan
  variables { enable_diagnostics = false }
  assert {
    condition = (
      length(google_service_account.bootstrap) == 2 && output.bootstrap.diagnostics_service_account == null &&
      alltrue([for grant in google_project_iam_member.deployment : grant.member == "serviceAccount:deployment@customer-project.iam.gserviceaccount.com"])
    )
    error_message = "Diagnostics opt-out must not change workload grant ownership."
  }
}

run "reject_license_version" {
  command = plan
  variables { license_secrets = ["projects/customer-project/secrets/license/versions/latest"] }
  expect_failures = [var.license_secrets]
}

run "reject_license_in_managed_secret_namespace" {
  command = plan
  variables { license_secrets = ["projects/123456789012/secrets/braintrust-postgres-password"] }
  expect_failures = [var.license_secrets]
}

run "reject_malformed_license" {
  command = plan
  variables { license_secrets = ["license"] }
  expect_failures = [var.license_secrets]
}
