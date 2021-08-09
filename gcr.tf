resource "google_artifact_registry_repository" "domino" {
  provider = google-beta

  location      = local.region
  repository_id = "${var.cluster_name}-domino"
  format        = "DOCKER"
}
