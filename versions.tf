terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0, < 8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0, < 8.0"
    }
  }
}
