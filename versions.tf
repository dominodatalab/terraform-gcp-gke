terraform {
  required_version = ">= 0.12"

  required_providers {
    google      = ">=3.10.0"
    google-beta = ">=3.10.0"
    http        = ">=1.1.1"
    kubernetes  = "~> 1.10.0"
    local       = ">=1.4.0"
    random      = ">=2.2"
  }
}
