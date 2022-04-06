provider "google-beta" {
  project = var.project
  region  = local.region
}

resource "google_artifact_registry_repository" "domino" {
  provider = google-beta

  location      = local.region
  repository_id = "${var.cluster_name}-domino"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_member" "gcr" {
  provider = google-beta

  repository = google_artifact_registry_repository.domino.name
  location   = google_artifact_registry_repository.domino.location

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.accounts["gcr"].email}"
}
