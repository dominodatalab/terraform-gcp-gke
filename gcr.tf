resource "google_artifact_registry_repository" "domino" {
  location      = local.region
  repository_id = "${var.deploy_id}-domino"
  format        = "DOCKER"
}

resource "google_artifact_registry_repository_iam_member" "gcr" {
  repository = google_artifact_registry_repository.domino.name
  location   = google_artifact_registry_repository.domino.location

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.accounts["gcr"].email}"
}
