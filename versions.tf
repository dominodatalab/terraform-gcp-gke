terraform {
  required_version = ">= 0.12"

  required_providers {
    google     = ">=3.68"
    http       = ">=2.1"
    kubernetes = "~> 2.2"
    local      = ">=2.1"
    random     = ">=3.1"
  }
}
