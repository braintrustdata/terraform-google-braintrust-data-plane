terraform {
  required_version = ">= 1.9"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4, < 4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 8.2.0, < 9.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 8.2.0, < 9.0.0"
    }
  }
}
