# The cluster resource now supports Autopilot and Standard modes.
moved {
  from = google_container_cluster.braintrust_autopilot
  to   = google_container_cluster.braintrust
}
