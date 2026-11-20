terraform {
  required_version = ">= 1.9.0, < 2.0.0"

  required_providers {
    time = {
      source  = "hashicorp/time"
      version = ">= 0.13.0, < 0.14.0"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 8.4.0, < 9.0.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 8.4.0, < 9.0.0"
    }
  }
}
