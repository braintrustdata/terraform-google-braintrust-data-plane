# The cluster resource now supports Autopilot and Standard modes.
moved {
  from = google_container_cluster.braintrust_autopilot
  to   = google_container_cluster.braintrust
}

moved {
  from = google_project_iam_member.gke_object_viewer
  to   = google_project_iam_member.gke_object_viewer[0]
}

moved {
  from = google_project_iam_member.gke_artifact_reader
  to   = google_project_iam_member.gke_artifact_reader[0]
}