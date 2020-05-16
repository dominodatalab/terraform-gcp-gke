terraform {
  required_version = ">= 0.12"

  required_providers {
    google      = ">=3.21.0"
    google-beta = ">=3.21.0"
    http        = ">=1.2.0"
    kubernetes  = "~> 1.11.2"
    local       = ">=1.4.0"
    random      = ">=2.2.1"
  }
}
