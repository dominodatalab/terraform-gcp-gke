locals {
  service_accounts = toset(["default", "system", "public", "compute", "platform"])
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
    "serviceAccount:${var.project}.svc.id.goog[${var.platform_namespace}/docker-registry]",
    "serviceAccount:${var.project}.svc.id.goog[${var.platform_namespace}/git]",
    "serviceAccount:${var.project}.svc.id.goog[${var.platform_namespace}/nucleus]",
  ]
}
