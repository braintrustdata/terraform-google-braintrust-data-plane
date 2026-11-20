# Deployment permissions and grants.

locals {
  deployment_roles = {
    dns            = { permissions = local.deployment_dns_permissions }
    gke            = { permissions = local.deployment_gke_permissions }
    iam            = { permissions = local.deployment_iam_permissions }
    kms            = { permissions = local.deployment_kms_permissions }
    kubernetes     = { permissions = local.deployment_kubernetes_permissions }
    network        = { permissions = local.deployment_network_permissions }
    redis          = { permissions = local.deployment_redis_permissions }
    secret_create  = { permissions = local.deployment_secret_create_permissions }
    secrets        = { permissions = local.deployment_secrets_permissions }
    services       = { permissions = local.deployment_services_permissions }
    sql            = { permissions = local.deployment_sql_permissions }
    storage        = { permissions = local.deployment_storage_permissions }
    storage_create = { permissions = local.deployment_storage_create_permissions }
  }
}

locals {
  deployment_state_permissions = [
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.objects.create",
    "storage.objects.delete",
    "storage.objects.get",
    "storage.objects.list",
    "storage.objects.update",
  ]
  deployment_evidence_permissions = [
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.objects.create",
    "storage.objects.list",
  ]
}

# Workload account and grant administration. Effective bootstrap self-protection remains a release gate.
locals {
  deployment_iam_permissions = [
    "iam.roles.create",
    "iam.roles.delete",
    "iam.roles.get",
    "iam.roles.undelete",
    "iam.roles.update",
    "iam.serviceAccounts.actAs",
    "iam.serviceAccounts.create",
    "iam.serviceAccounts.delete",
    "iam.serviceAccounts.disable",
    "iam.serviceAccounts.enable",
    "iam.serviceAccounts.get",
    "iam.serviceAccounts.getIamPolicy",
    "iam.serviceAccounts.setIamPolicy",
    "iam.serviceAccounts.update",
    "resourcemanager.projects.get",
    "resourcemanager.projects.getIamPolicy",
    "resourcemanager.projects.setIamPolicy",
  ]
}

# Cluster and node pool lifecycle. Legacy cluster credentials remain excluded.
locals {
  deployment_gke_permissions = [
    "compute.instanceGroupManagers.list",
    "container.clusters.connect",
    "container.clusters.create",
    "container.clusters.delete",
    "container.clusters.get",
    "container.clusters.update",
    "container.operations.get",
  ]
}

# Terraform and Helm lifecycle, including related Loop worker resources. No interactive session or log permissions.
locals {
  deployment_kubernetes_permissions = [
    "container.apiServices.create",
    "container.apiServices.delete",
    "container.apiServices.get",
    "container.apiServices.list",
    "container.apiServices.update",
    "container.backendConfigs.create",
    "container.backendConfigs.delete",
    "container.backendConfigs.get",
    "container.backendConfigs.list",
    "container.backendConfigs.update",
    "container.clusterRoleBindings.create",
    "container.clusterRoleBindings.delete",
    "container.clusterRoleBindings.get",
    "container.clusterRoleBindings.list",
    "container.clusterRoleBindings.update",
    "container.clusterRoles.create",
    "container.clusterRoles.delete",
    "container.clusterRoles.get",
    "container.clusterRoles.list",
    "container.clusterRoles.update",
    "container.configMaps.create",
    "container.configMaps.delete",
    "container.configMaps.get",
    "container.configMaps.list",
    "container.configMaps.update",
    "container.cronJobs.create",
    "container.cronJobs.delete",
    "container.cronJobs.get",
    "container.cronJobs.list",
    "container.cronJobs.update",
    "container.customResourceDefinitions.create",
    "container.customResourceDefinitions.delete",
    "container.customResourceDefinitions.get",
    "container.customResourceDefinitions.list",
    "container.customResourceDefinitions.update",
    "container.daemonSets.create",
    "container.daemonSets.delete",
    "container.daemonSets.get",
    "container.daemonSets.list",
    "container.daemonSets.update",
    "container.deployments.create",
    "container.deployments.delete",
    "container.deployments.get",
    "container.deployments.list",
    "container.deployments.update",
    "container.endpointSlices.get",
    "container.endpointSlices.list",
    "container.horizontalPodAutoscalers.create",
    "container.horizontalPodAutoscalers.delete",
    "container.horizontalPodAutoscalers.get",
    "container.horizontalPodAutoscalers.list",
    "container.horizontalPodAutoscalers.update",
    "container.ingresses.create",
    "container.ingresses.delete",
    "container.ingresses.get",
    "container.ingresses.list",
    "container.ingresses.update",
    "container.jobs.create",
    "container.jobs.delete",
    "container.jobs.get",
    "container.jobs.list",
    "container.jobs.update",
    "container.leases.create",
    "container.leases.delete",
    "container.leases.get",
    "container.leases.list",
    "container.leases.update",
    "container.managedCertificates.create",
    "container.managedCertificates.delete",
    "container.managedCertificates.get",
    "container.managedCertificates.list",
    "container.managedCertificates.update",
    "container.mutatingWebhookConfigurations.create",
    "container.mutatingWebhookConfigurations.delete",
    "container.mutatingWebhookConfigurations.get",
    "container.mutatingWebhookConfigurations.list",
    "container.mutatingWebhookConfigurations.update",
    "container.namespaces.create",
    "container.namespaces.delete",
    "container.namespaces.get",
    "container.namespaces.list",
    "container.namespaces.update",
    "container.networkPolicies.create",
    "container.networkPolicies.delete",
    "container.networkPolicies.get",
    "container.networkPolicies.list",
    "container.networkPolicies.update",
    "container.nodes.get",
    "container.nodes.list",
    "container.nodes.update",
    "container.persistentVolumeClaims.create",
    "container.persistentVolumeClaims.delete",
    "container.persistentVolumeClaims.get",
    "container.persistentVolumeClaims.list",
    "container.persistentVolumeClaims.update",
    "container.persistentVolumes.get",
    "container.persistentVolumes.list",
    "container.podDisruptionBudgets.create",
    "container.podDisruptionBudgets.delete",
    "container.podDisruptionBudgets.get",
    "container.podDisruptionBudgets.list",
    "container.podDisruptionBudgets.update",
    "container.pods.create",
    "container.pods.delete",
    "container.pods.evict",
    "container.pods.get",
    "container.pods.list",
    "container.pods.update",
    "container.replicaSets.get",
    "container.replicaSets.list",
    "container.roleBindings.create",
    "container.roleBindings.delete",
    "container.roleBindings.get",
    "container.roleBindings.list",
    "container.roleBindings.update",
    "container.roles.create",
    "container.roles.delete",
    "container.roles.get",
    "container.roles.list",
    "container.roles.update",
    "container.secrets.create",
    "container.secrets.delete",
    "container.secrets.get",
    "container.secrets.list",
    "container.secrets.update",
    "container.serviceAccounts.create",
    "container.serviceAccounts.delete",
    "container.serviceAccounts.get",
    "container.serviceAccounts.list",
    "container.serviceAccounts.update",
    "container.services.create",
    "container.services.delete",
    "container.services.get",
    "container.services.list",
    "container.services.update",
    "container.statefulSets.create",
    "container.statefulSets.delete",
    "container.statefulSets.get",
    "container.statefulSets.getScale",
    "container.statefulSets.list",
    "container.statefulSets.update",
    "container.statefulSets.updateScale",
    "container.storageClasses.create",
    "container.storageClasses.delete",
    "container.storageClasses.get",
    "container.storageClasses.list",
    "container.storageClasses.update",
    "container.thirdPartyObjects.create",
    "container.thirdPartyObjects.delete",
    "container.thirdPartyObjects.get",
    "container.thirdPartyObjects.list",
    "container.thirdPartyObjects.update",
    "container.validatingWebhookConfigurations.create",
    "container.validatingWebhookConfigurations.delete",
    "container.validatingWebhookConfigurations.get",
    "container.validatingWebhookConfigurations.list",
    "container.validatingWebhookConfigurations.update",

  ]
}

# Same-project network lifecycle. No Shared VPC, general route, VPN, or peering administration.
locals {
  deployment_network_permissions = [
    "compute.addresses.createInternal",
    "compute.addresses.deleteInternal",
    "compute.addresses.get",
    "compute.addresses.setLabels",
    "compute.firewalls.create",
    "compute.firewalls.delete",
    "compute.firewalls.get",
    "compute.firewalls.update",
    "compute.globalAddresses.create",
    "compute.globalAddresses.createInternal",
    "compute.globalAddresses.delete",
    "compute.globalAddresses.deleteInternal",
    "compute.globalAddresses.get",
    "compute.globalAddresses.setLabels",
    "compute.globalOperations.get",
    "compute.networks.create",
    "compute.networks.delete",
    "compute.networks.get",
    "compute.networks.update",
    "compute.networks.updatePolicy",
    "compute.networks.use",
    "compute.projects.get",
    "compute.regionOperations.get",
    "compute.routers.create",
    "compute.routers.delete",
    "compute.routers.get",
    "compute.routers.update",
    "compute.subnetworks.create",
    "compute.subnetworks.delete",
    "compute.subnetworks.expandIpCidrRange",
    "compute.subnetworks.get",
    "compute.subnetworks.setPrivateIpGoogleAccess",
    "compute.subnetworks.update",
    "compute.subnetworks.use",
    "servicenetworking.operations.get",
    "servicenetworking.services.addPeering",
    "servicenetworking.services.get",
  ]
}

# Initial SQL user setup uses Users.Insert. User updates, restore, and backup creation await a demonstrated workflow.
locals {
  deployment_sql_permissions = [
    "cloudsql.backupRuns.get",
    "cloudsql.backupRuns.list",
    "cloudsql.instances.create",
    "cloudsql.instances.delete",
    "cloudsql.instances.get",
    "cloudsql.instances.update",
    "cloudsql.users.create",
    "cloudsql.users.delete",
    "cloudsql.users.list",
  ]
}

# AUTH-enabled Redis lifecycle. Redis is disposable during retain-data removal.
locals {
  deployment_redis_permissions = [
    "redis.instances.create",
    "redis.instances.delete",
    "redis.instances.get",
    "redis.instances.getAuthString",
    "redis.instances.update",
    "redis.instances.updateAuth",
    "redis.instances.upgrade",
    "redis.operations.get",
  ]
}

# Workload key metadata, rotation, and grants. No direct crypto or version disablement or destruction.
locals {
  deployment_kms_permissions = [
    "cloudkms.cryptoKeyVersions.get",
    "cloudkms.cryptoKeyVersions.list",
    "cloudkms.cryptoKeys.create",
    "cloudkms.cryptoKeys.get",
    "cloudkms.cryptoKeys.getIamPolicy",
    "cloudkms.cryptoKeys.setIamPolicy",
    "cloudkms.cryptoKeys.update",
    "cloudkms.keyRings.create",
    "cloudkms.keyRings.get",
  ]
}

# Bucket creation checks the parent project. Bucket administration uses a separate conditional grant.
locals {
  deployment_storage_create_permissions = [
    "storage.buckets.create",
  ]
}

# Workload bucket administration. Object payload operations require separate destination grants.
locals {
  deployment_storage_permissions = [
    "storage.buckets.delete",
    "storage.buckets.get",
    "storage.buckets.getIamPolicy",
    "storage.buckets.setIamPolicy",
    "storage.buckets.update",
    "storage.objects.list",
  ]
}

# Secret creation checks the parent project. Subsequent access uses the managed-secret condition.
locals {
  deployment_secret_create_permissions = [
    "secretmanager.secrets.create",
  ]
}

# Module-owned PostgreSQL secrets. License reads use separate exact-resource grants.
locals {
  deployment_secrets_permissions = [
    "secretmanager.secrets.delete",
    "secretmanager.secrets.get",
    "secretmanager.secrets.update",
    "secretmanager.versions.access",
    "secretmanager.versions.add",
    "secretmanager.versions.destroy",
    "secretmanager.versions.enable",
    "secretmanager.versions.get",
  ]
}

# Private Loop discovery only. Braintrust public endpoint DNS remains separate.
locals {
  deployment_dns_permissions = [
    "dns.changes.create",
    "dns.changes.get",
    "dns.managedZones.create",
    "dns.managedZones.delete",
    "dns.managedZones.get",
    "dns.managedZones.getIamPolicy",
    "dns.managedZones.setIamPolicy",
    "dns.managedZones.update",
    "dns.networks.bindPrivateDNSZone",
    "dns.resourceRecordSets.create",
    "dns.resourceRecordSets.delete",
    "dns.resourceRecordSets.list",
    "dns.resourceRecordSets.update",
  ]
}

# API status, operation waits, and quota-project consumption. API enablement and quota writes remain excluded.
locals {
  deployment_services_permissions = [
    "serviceusage.operations.get",
    "serviceusage.services.get",
    "serviceusage.services.list",
    "serviceusage.services.use",
  ]
}

locals {
  license_secret_pattern = "^projects/([a-z][a-z0-9-]{4,28}[a-z0-9]|[1-9][0-9]*)/secrets/[A-Za-z0-9_-]{1,255}$"
  bootstrap_storage_key_paths = [
    for name, config in local.storage : config.kms_key == null ? (
      "/locations/${config.kms_location}/keyRings/bt-${local.suffix}-${name}/cryptoKeys/storage"
    ) : "/${join("/", slice(split("/", config.kms_key), 2, 8))}"
  ]
  # These grant conditions narrow direct API access. Project IAM writes can bypass them.
  deployment_conditions = {
    storage = {
      title = "exclude_bootstrap_buckets"
      expression = "resource.type != 'storage.googleapis.com/Bucket' || !(resource.name in ${jsonencode([
        "projects/_/buckets/${google_storage_bucket.state.name}",
        "projects/_/buckets/${google_storage_bucket.evidence.name}",
      ])})"
    }
    kms = {
      title = "exclude_bootstrap_keys"
      expression = "resource.type != 'cloudkms.googleapis.com/CryptoKey' || !(${join(" || ", [
        for path in local.bootstrap_storage_key_paths : "resource.name.endsWith(${jsonencode(path)})"
      ])})"
    }
    secrets = {
      title      = "module_postgres_secrets"
      expression = <<-EOT
        (resource.type == 'secretmanager.googleapis.com/Secret' && resource.name.endsWith('-postgres-password')) ||
        (resource.type == 'secretmanager.googleapis.com/SecretVersion' && resource.name.extract('projects/${var.project_number}/secrets/{secret}/versions/').endsWith('-postgres-password'))
      EOT
    }
  }
  license_secret_projects = {
    for secret in var.license_secrets : secret => (
      split("/", secret)[1] == var.project_number ? var.project_id : split("/", secret)[1]
    ) if can(regex(local.license_secret_pattern, secret))
  }
}

resource "google_project_iam_custom_role" "deployment" {
  for_each = local.deployment_roles

  project     = data.google_project.customer.project_id
  role_id     = "bt_${local.suffix}_deploy_${each.key}"
  title       = "Braintrust Deployment ${each.key}"
  description = "Provisional workload permissions. Effective isolation requires separate acceptance."
  permissions = each.value.permissions
  depends_on  = [google_project_service.required]
}

resource "google_project_iam_member" "deployment" {
  for_each = local.deployment_roles

  project = data.google_project.customer.project_id
  role    = google_project_iam_custom_role.deployment[each.key].name
  member  = "serviceAccount:${google_service_account.bootstrap["deployment"].email}"

  dynamic "condition" {
    for_each = contains(keys(local.deployment_conditions), each.key) ? [local.deployment_conditions[each.key]] : []
    content {
      title      = condition.value.title
      expression = condition.value.expression
    }
  }
}

resource "google_project_iam_custom_role" "license" {
  for_each = toset(values(local.license_secret_projects))

  project     = each.value
  role_id     = "bt_${local.suffix}_license"
  title       = "Braintrust license reads"
  description = "Read metadata, policy, and existing version payloads on exact license secrets."
  permissions = ["secretmanager.secrets.get", "secretmanager.secrets.getIamPolicy", "secretmanager.versions.get", "secretmanager.versions.access"]
  depends_on  = [google_project_service.required]
}

resource "google_secret_manager_secret_iam_member" "license" {
  for_each = local.license_secret_projects

  project   = each.value
  secret_id = each.key
  role      = google_project_iam_custom_role.license[each.value].name
  member    = "serviceAccount:${google_service_account.bootstrap["deployment"].email}"
}

resource "google_service_account_iam_member" "deployment_bridge" {
  service_account_id = google_service_account.bootstrap["deployment"].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${var.braintrust_bridge_service_account}"
}

# Cloud Storage can reject a new role after IAM reports successful creation.
# The Google provider does not retry the role hierarchy error.
resource "time_sleep" "storage_role_propagation" {
  create_duration = "60s"

  triggers = {
    state_role    = google_project_iam_custom_role.foundation["state"].name
    evidence_role = google_project_iam_custom_role.foundation["evidence"].name
  }

  lifecycle {
    replace_triggered_by = [
      google_project_iam_custom_role.foundation["state"],
      google_project_iam_custom_role.foundation["evidence"],
    ]
  }
}

resource "google_storage_bucket_iam_member" "state" {
  bucket = google_storage_bucket.state.name
  role   = google_project_iam_custom_role.foundation["state"].name
  member = "serviceAccount:${google_service_account.bootstrap["deployment"].email}"

  depends_on = [time_sleep.storage_role_propagation]
}

resource "google_storage_bucket_iam_member" "evidence" {
  bucket = google_storage_bucket.evidence.name
  role   = google_project_iam_custom_role.foundation["evidence"].name
  member = "serviceAccount:${google_service_account.bootstrap["deployment"].email}"

  depends_on = [time_sleep.storage_role_propagation]
}

# Readiness reads reuse Deployment. No key cryptographic use or policy mutation applies.
locals {
  deployment_key_metadata_permissions = [
    "cloudkms.cryptoKeyVersions.get",
    "cloudkms.cryptoKeys.get",
    "cloudkms.cryptoKeys.getIamPolicy",
  ]
  deployment_external_metadata_permissions = [
    "iam.roles.get",
    "resourcemanager.projects.get",
  ]
  # Keys for for_each depend only on reviewed inputs, not newly created key IDs.
  key_metadata_projects = {
    for group, names in local.storage_key_groups : group => (
      local.storage[names[0]].kms_key == null ? var.project_id : (
        try(split("/", local.storage[names[0]].kms_key)[1], "invalid") == var.project_number ? var.project_id : try(split("/", local.storage[names[0]].kms_key)[1], "invalid")
      )
    )
  }
  external_metadata_projects = toset([
    for project in concat(values(local.key_metadata_projects), values(local.license_secret_projects)) : project
    if project != var.project_id && project != var.project_number
  ])
}

# A distinct role per key group avoids role-name collisions across project aliases.
resource "google_project_iam_custom_role" "key_metadata" {
  for_each = local.storage_key_groups

  project     = local.key_metadata_projects[each.key]
  role_id     = "bt_${local.suffix}_key_metadata_${substr(sha256(each.key), 0, 12)}"
  title       = "Braintrust bootstrap key metadata"
  description = "Read selected key metadata and policy without cryptographic use or mutation."
  permissions = local.deployment_key_metadata_permissions
  depends_on  = [google_project_service.required]
}

resource "google_kms_crypto_key_iam_member" "deployment_metadata" {
  for_each = local.storage_key_groups

  crypto_key_id = local.storage_keys[each.value[0]]
  role          = google_project_iam_custom_role.key_metadata[each.key].name
  member        = "serviceAccount:${google_service_account.bootstrap["deployment"].email}"
  depends_on    = [data.google_kms_crypto_key.existing_storage]
}

# These two metadata permissions need a project grant. They include no inventory or IAM writes.
resource "google_project_iam_custom_role" "external_metadata" {
  for_each = local.external_metadata_projects

  project     = each.value
  role_id     = "bt_${local.suffix}_external_metadata_${substr(sha256(each.value), 0, 12)}"
  title       = "Braintrust external resource metadata"
  description = "Read known role definitions and project identity for selected external keys and license secrets."
  permissions = local.deployment_external_metadata_permissions
  depends_on  = [google_project_service.required]
}

resource "google_project_iam_member" "external_metadata" {
  for_each = local.external_metadata_projects

  project = each.value
  role    = google_project_iam_custom_role.external_metadata[each.key].name
  member  = "serviceAccount:${google_service_account.bootstrap["deployment"].email}"
}
