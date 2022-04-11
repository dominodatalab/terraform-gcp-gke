terraform {
  required_version = ">= 1.0"
  required_providers {
    google-beta = {
      source  = "registry.terraform.io/hashicorp/google-beta"
      version = "~> 3.68"
    }
    google = {
      source  = "registry.terraform.io/hashicorp/google"
      version = "~> 3.68"
    }
    random = {
      source  = "registry.terraform.io/hashicorp/random"
      version = "~> 3.1"
    }
  }
}
