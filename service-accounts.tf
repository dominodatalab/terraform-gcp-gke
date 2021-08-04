locals {
  service_accounts = toset(["platform", "gcr"])
}

resource "google_service_account" "accounts" {
  for_each = local.service_accounts

  account_id   = "${var.cluster_name}-${each.value}"
  display_name = "${var.cluster_name}-${each.value}"
}


resource "google_project_iam_member" "service_account" {
  for_each = local.service_accounts

  project = var.project
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.accounts[each.value].email}"
}

resource "google_project_iam_member" "platform_roles" {
  for_each = toset(["roles/storage.objectAdmin", "roles/logging.logWriter", "roles/monitoring.metricWriter"])
  project  = var.project
  role     = each.value
  member   = "serviceAccount:${google_service_account.accounts["platform"].email}"
}

resource "google_service_account_iam_binding" "platform_gcs" {
  service_account_id = google_service_account.accounts["platform"].name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.platform}/docker-registry]",
    "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.platform}/git]",
    "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.platform}/nucleus]",
  ]
}

resource "google_artifact_registry_repository_iam_member" "gcr" {
  for_each = google_artifact_registry_repository.domino
  provider = google-beta

  repository = each.value.name
  location   = each.value.location

  role   = "roles/artifactregistry.writer"
  member = "serviceAccount:${google_service_account.accounts["gcr"].email}"
}

resource "google_service_account_iam_binding" "gcr" {
  service_account_id = google_service_account.accounts["gcr"].name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.compute}/forge]",
  ]
}
