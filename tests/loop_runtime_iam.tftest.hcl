mock_provider "google" {
  mock_resource "google_service_account" {
    defaults = {
      id    = "projects/braintrust-test/serviceAccounts/test-account@braintrust-test.iam.gserviceaccount.com"
      email = "test-account@braintrust-test.iam.gserviceaccount.com"
    }
  }
}

variables {
  deployment_name          = "braintrust"
  loop_runtime_enabled     = true
  workload_identity_pool   = "braintrust-test.svc.id.goog"
  braintrust_api_bucket_id = "braintrust-api"
  brainstore_gcs_bucket_id = "braintrust-storage"
}

run "enabled_creates_dedicated_identity_and_bucket_access" {
  command = apply
  module { source = "./modules/gke-iam" }

  assert {
    condition     = google_service_account.loop_runtime[0].account_id == "braintrust-loop"
    error_message = "Loop must use a dedicated service account."
  }

  assert {
    condition = (
      google_service_account_iam_binding.loop_runtime_workload_identity[0].role == "roles/iam.workloadIdentityUser" &&
      google_service_account_iam_binding.loop_runtime_workload_identity[0].service_account_id == google_service_account.loop_runtime[0].id &&
      google_service_account_iam_binding.loop_runtime_workload_identity[0].members == toset([
        "serviceAccount:braintrust-test.svc.id.goog[braintrust/braintrust-loop-runtime]"
      ])
    )
    error_message = "Only the Loop Kubernetes account must receive access to the Loop Google account."
  }

  assert {
    condition = alltrue(flatten([
      for bucket, grants in {
        "braintrust-storage" = {
          "roles/storage.objectAdmin"        = google_storage_bucket_iam_member.loop_runtime_brainstore_gcs_object_admin[0]
          "roles/storage.legacyBucketReader" = google_storage_bucket_iam_member.loop_runtime_brainstore_gcs_reader[0]
        }
        "braintrust-api" = {
          "roles/storage.objectAdmin"        = google_storage_bucket_iam_member.loop_runtime_api_bucket_gcs_object_admin[0]
          "roles/storage.legacyBucketReader" = google_storage_bucket_iam_member.loop_runtime_api_bucket_gcs_reader[0]
        }
        } : [for role, grant in grants :
        grant.bucket == bucket && grant.role == role && grant.member == "serviceAccount:${google_service_account.loop_runtime[0].email}"
      ]
    ]))
    error_message = "Loop requires object writes and bucket reads scoped to both deployment buckets and its own identity."
  }

  assert {
    condition     = output.loop_runtime_service_account == google_service_account.loop_runtime[0].email
    error_message = "The output must expose the Loop account email for Helm."
  }

  assert {
    condition = (
      google_service_account_iam_binding.brainstore_workload_identity.members == toset([
        "serviceAccount:braintrust-test.svc.id.goog[braintrust/brainstore]",
        "serviceAccount:braintrust-test.svc.id.goog[braintrust/braintrust-api]"
      ]) &&
      google_service_account_iam_binding.braintrust_workload_identity.members == toset([
        "serviceAccount:braintrust-test.svc.id.goog[braintrust/braintrust-api]"
      ])
    )
    error_message = "Loop must preserve the existing API and Brainstore Workload Identity bindings."
  }
}

run "custom_kubernetes_identity" {
  command = plan
  module { source = "./modules/gke-iam" }
  variables {
    braintrust_kube_namespace     = "custom-namespace"
    loop_runtime_kube_svc_account = "custom-loop"
    workload_identity_pool        = "custom-project.svc.id.goog"
  }

  assert {
    condition = google_service_account_iam_binding.loop_runtime_workload_identity[0].members == toset([
      "serviceAccount:custom-project.svc.id.goog[custom-namespace/custom-loop]"
    ])
    error_message = "The Loop binding must honor the configured pool, namespace, and Kubernetes account."
  }
}

run "disabled_creates_no_loop_identity_or_grants" {
  command = plan
  module { source = "./modules/gke-iam" }
  variables { loop_runtime_enabled = false }
  assert {
    condition = (
      output.loop_runtime_service_account == null &&
      length(google_service_account.loop_runtime) == 0 &&
      length(google_service_account_iam_binding.loop_runtime_workload_identity) == 0 &&
      length(google_storage_bucket_iam_member.loop_runtime_brainstore_gcs_object_admin) == 0 &&
      length(google_storage_bucket_iam_member.loop_runtime_brainstore_gcs_reader) == 0 &&
      length(google_storage_bucket_iam_member.loop_runtime_api_bucket_gcs_object_admin) == 0 &&
      length(google_storage_bucket_iam_member.loop_runtime_api_bucket_gcs_reader) == 0
    )
    error_message = "Disabled workers must create no Loop identity or bucket access and return a null identity output."
  }
}
