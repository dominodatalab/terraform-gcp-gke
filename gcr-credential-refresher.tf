#===============================================================================
# GCR Credential Refresher for Gen AI Model Operations
#
# Provisions a dedicated GCP service account with Artifact Registry read access
# and GKE Workload Identity binding. The GcrCredentialRefresher CronJob
# (deployed via Helm) uses this identity to obtain short-lived access tokens
# and populate the domino-registry Kubernetes secret.
#
# This follows the same pattern as EcrCredentialRefresher (EKS) and
# AcrCredentialRefresher (AKS).
#===============================================================================

resource "google_service_account" "gcr_credential_refresher" {
  account_id   = "${var.deploy_id}-gcr-cred"
  display_name = "${var.deploy_id} GCR Credential Refresher"
  description  = "Used by the GCR credential refresher CronJob to obtain access tokens for Artifact Registry"
  project      = var.project
}

resource "google_artifact_registry_repository_iam_member" "gcr_credential_refresher_reader" {
  repository = google_artifact_registry_repository.domino.name
  location   = google_artifact_registry_repository.domino.location

  role   = "roles/artifactregistry.reader"
  member = "serviceAccount:${google_service_account.gcr_credential_refresher.email}"
}

resource "google_service_account_iam_member" "gcr_credential_refresher_workload_identity" {
  service_account_id = google_service_account.gcr_credential_refresher.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.platform}/nucleus-gcr-credential-refresher]"
}
