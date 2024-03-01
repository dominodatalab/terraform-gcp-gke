locals {
  # Converts a cluster's location to a zone/region. A 'location' may be a region or zone: a region becomes the '[region]-a' zone.
  is_regional = length(split("-", var.location)) == 2
  region      = local.is_regional ? var.location : substr(var.location, 0, length(var.location) - 2)
  zone        = local.is_regional ? format("%s-a", var.location) : var.location
}

provider "google" {
  project        = var.project
  region         = local.region
  default_labels = var.tags
}

data "google_project" "domino" {
  project_id = var.project
}
