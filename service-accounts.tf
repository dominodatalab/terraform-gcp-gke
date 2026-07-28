locals {
  service_accounts = toset(["platform", "gcr"])
}

resource "google_service_account" "accounts" {
  for_each = local.service_accounts

  account_id   = "${var.deploy_id}-${each.value}"
  display_name = "${var.deploy_id}-${each.value}"
}


resource "google_project_iam_member" "service_account" {
  for_each = local.service_accounts

  project = var.project
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.accounts[each.value].email}"
}

resource "google_project_iam_member" "platform_roles" {
  for_each = toset(["roles/logging.logWriter", "roles/monitoring.metricWriter"])
  project  = var.project
  role     = each.value
  member   = "serviceAccount:${google_service_account.accounts["platform"].email}"
}

resource "google_service_account_iam_binding" "platform_gcs" {
  service_account_id = google_service_account.accounts["platform"].name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.platform}/docker-registry]",
    "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.platform}/domino-data-importer]",
    "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.platform}/git]",
    "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.platform}/nucleus]",
  ]
}

resource "google_service_account_iam_binding" "gcr" {
  service_account_id = google_service_account.accounts["gcr"].name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.compute}/forge]",
    "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.compute}/hephaestus]"
  ]
}

resource "google_service_account" "gcnv" {
  count = var.storage.gcnv.enabled ? 1 : 0

  account_id   = "${var.deploy_id}-gcnv"
  display_name = "${var.deploy_id}-gcnv"
}

# ONTAP writes require a custom role.
resource "google_project_iam_custom_role" "gcnv" {
  count = var.storage.gcnv.enabled ? 1 : 0

  project     = var.project
  role_id     = replace("${var.deploy_id}_gcnv_trident", "-", "_")
  title       = "${var.deploy_id} GCNV Trident"
  description = "Least-privilege GCNV access for the Trident controller in ${var.deploy_id}"
  permissions = [
    "netapp.ontap.get",
    "netapp.ontap.post",
    "netapp.ontap.patch",
    "netapp.ontap.delete",
  ]
}

resource "google_project_iam_member" "gcnv" {
  count = var.storage.gcnv.enabled ? 1 : 0

  project = var.project
  role    = google_project_iam_custom_role.gcnv[0].name
  member  = "serviceAccount:${google_service_account.gcnv[0].email}"
}

resource "google_project_iam_member" "gcnv_viewer" {
  count = var.storage.gcnv.enabled ? 1 : 0

  project = var.project
  role    = "roles/netapp.viewer"
  member  = "serviceAccount:${google_service_account.gcnv[0].email}"
}

resource "google_service_account_iam_binding" "gcnv" {
  count = var.storage.gcnv.enabled ? 1 : 0

  service_account_id = google_service_account.gcnv[0].name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project}.svc.id.goog[${var.storage.gcnv.trident_namespace}/trident-controller]",
  ]
}
