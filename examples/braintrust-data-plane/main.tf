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

  deployment_name                    = "braintrust"
  region                             = var.region
  brainstore_license_key_secret_name = var.brainstore_license_key_secret_name
}

