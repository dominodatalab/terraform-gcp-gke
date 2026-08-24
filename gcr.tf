provider "google-beta" {
  project = var.project
  region  = local.region
}

resource "google_artifact_registry_repository" "domino" {
  count = var.registry.create ? 1 : 0

  location      = local.region
  repository_id = "${var.deploy_id}-domino"
  format        = "DOCKER"

  docker_config {
    immutable_tags = true
  }
}

resource "google_artifact_registry_repository_iam_member" "gcr" {
  count      = var.registry.create ? 1 : 0
  repository = google_artifact_registry_repository.domino[0].name
  location   = google_artifact_registry_repository.domino[0].location

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.accounts["gcr"].email}"
}

resource "google_artifact_registry_repository_iam_member" "platform" {
  count      = var.registry.create && var.migration_permissions ? 1 : 0
  repository = google_artifact_registry_repository.domino[0].name
  location   = google_artifact_registry_repository.domino[0].location

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.accounts["platform"].email}"
}

moved {
  from = google_artifact_registry_repository.domino
  to   = google_artifact_registry_repository.domino[0]
}

moved {
  from = google_artifact_registry_repository_iam_member.gcr
  to   = google_artifact_registry_repository_iam_member.gcr[0]
}
