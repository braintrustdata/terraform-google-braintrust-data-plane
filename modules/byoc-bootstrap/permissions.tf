# This module owns the draft permissions during internal iteration.
locals {
  impersonation_role = "roles/iam.serviceAccountTokenCreator"
  observer_principal = "group:byoc-support@braintrustdata.com"
  foundation_roles = {
    observer = {
      permissions = [
        "monitoring.metricDescriptors.get",
        "monitoring.metricDescriptors.list",
        "monitoring.monitoredResourceDescriptors.get",
        "monitoring.monitoredResourceDescriptors.list",
        "monitoring.timeSeries.list",
        "resourcemanager.projects.get",
        "serviceusage.services.get",
        "serviceusage.services.list",
      ]
    }
    state = {
      permissions = [
        "storage.buckets.get",
        "storage.objects.create",
        "storage.objects.delete",
        "storage.objects.get",
        "storage.objects.list",
        "storage.objects.update",
      ]
    }
    evidence = {
      permissions = [
        "storage.buckets.get",
        "storage.objects.create",
        "storage.objects.list",
      ]
    }
  }
}
