terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0, < 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 4.0, < 5.0"
    }
  }
}
