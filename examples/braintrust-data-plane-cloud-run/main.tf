provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

module "braintrust" {
  source = "../../"

  deployment_name                    = var.deployment_name
  deployment_type                    = "cloud-run"
  region                             = var.region
  brainstore_license_key_secret_name = var.brainstore_license_key_secret_name
  postgres_deletion_protection       = var.postgres_deletion_protection
  gcs_force_destroy                  = var.gcs_force_destroy
  gke_deletion_protection            = var.gke_deletion_protection
  gke_control_plane_authorized_cidr  = var.gke_control_plane_authorized_cidr
  cloud_run_deletion_protection      = var.cloud_run_deletion_protection
  org_name                           = "jeff-k8s"
  cloud_run_enable_public_access     = true
}

