provider "google-beta" {
  project = var.project
  region  = local.region
}

resource "google_artifact_registry_repository" "domino" {
  location      = local.region
  repository_id = "${var.deploy_id}-domino"
  format        = "DOCKER"

  docker_config {
    immutable_tags = true
  }
}

resource "google_artifact_registry_repository_iam_member" "gcr" {
  repository = google_artifact_registry_repository.domino.name
  location   = google_artifact_registry_repository.domino.location

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.accounts["gcr"].email}"
}

resource "google_artifact_registry_repository_iam_member" "platform" {
  count      = var.migration_permissions ? 1 : 0
  repository = google_artifact_registry_repository.domino.name
  location   = google_artifact_registry_repository.domino.location

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.accounts["platform"].email}"
}
