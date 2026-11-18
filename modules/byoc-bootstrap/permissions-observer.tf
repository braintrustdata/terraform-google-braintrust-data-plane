# Cloud health and metrics only. No Kubernetes workload, secret payload, object payload, or log reads.
locals {
  observer_permissions = [
    "cloudkms.cryptoKeyVersions.get",
    "cloudkms.cryptoKeyVersions.list",
    "cloudkms.cryptoKeys.get",
    "cloudsql.backupRuns.get",
    "cloudsql.backupRuns.list",
    "cloudsql.instances.get",
    "cloudsql.instances.list",
    "compute.addresses.get",
    "compute.addresses.list",
    "compute.backendServices.get",
    "compute.backendServices.list",
    "compute.firewalls.get",
    "compute.firewalls.list",
    "compute.globalAddresses.get",
    "compute.globalAddresses.list",
    "compute.networks.get",
    "compute.networks.list",
    "compute.routers.get",
    "compute.routers.list",
    "compute.subnetworks.get",
    "compute.subnetworks.list",
    "container.clusters.get",
    "container.clusters.list",
    "container.operations.get",
    "dns.managedZones.get",
    "dns.resourceRecordSets.list",
    "monitoring.alertPolicies.get",
    "monitoring.alertPolicies.list",
    "monitoring.alerts.get",
    "monitoring.alerts.list",
    "monitoring.metricDescriptors.get",
    "monitoring.metricDescriptors.list",
    "monitoring.monitoredResourceDescriptors.get",
    "monitoring.monitoredResourceDescriptors.list",
    "monitoring.timeSeries.list",
    "redis.instances.get",
    "redis.instances.list",
    "redis.operations.get",
    "resourcemanager.projects.get",
    "serviceusage.services.get",
    "serviceusage.services.list",
    "storage.buckets.get",
  ]
}

resource "google_service_account_iam_member" "observer_group" {
  service_account_id = google_service_account.bootstrap["observer"].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "group:byoc-support@braintrustdata.com"
}

resource "google_project_iam_member" "observer" {
  project = data.google_project.customer.project_id
  role    = google_project_iam_custom_role.foundation["observer"].name
  member  = "serviceAccount:${google_service_account.bootstrap["observer"].email}"
}
