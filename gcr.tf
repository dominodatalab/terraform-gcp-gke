resource "google_artifact_registry_repository" "domino" {
  for_each = toset(["model", "environment"])
  provider = google-beta

  location      = local.region
  repository_id = "${var.cluster_name}-${each.value}"
  format        = "DOCKER"
}
