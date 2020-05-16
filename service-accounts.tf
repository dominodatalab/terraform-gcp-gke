resource "google_service_account" "default" {
  account_id   = "${local.cluster}-default"
  display_name = "${local.cluster}-default"
}

resource "google_service_account" "gke" {
  account_id   = "${local.cluster}-gke"
  display_name = "${local.cluster}-gke"
}

resource "google_service_account" "kube_system" {
  account_id   = "${local.cluster}-system"
  display_name = "${local.cluster}-system"
}

resource "google_service_account" "kube_public" {
  account_id   = "${local.cluster}-public"
  display_name = "${local.cluster}-public"
}

resource "google_service_account" "compute" {
  account_id   = "${local.cluster}-compute"
  display_name = "${local.cluster}-compute"
}

resource "google_service_account" "platform" {
  account_id   = "${local.cluster}-platform"
  display_name = "${local.cluster}-platform"
}

resource "google_project_iam_member" "service_account" {
  project = var.project
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "gke_service_account_crypto_key" {
  project = var.project
  role    = "roles/aim.cloudkms.cryptoKeyEncrypterDecrypter"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "gke_service_account_agent" {
  project = var.project
  role    = "roles/roles/container.hostServiceAgentUser"
  member  = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_project_iam_member" "kube_system_service_account" {
  project = var.project
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.kube_system.email}"
}

resource "google_project_iam_member" "kube_public_service_account" {
  project = var.project
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.kube_public.email}"
}

resource "google_project_iam_member" "compute_service_account" {
  project = var.project
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.compute.email}"
}

resource "google_project_iam_member" "platform_service_account" {
  project = var.project
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.platform.email}"
}

resource "google_project_iam_member" "platform_object_admin" {
  project = var.project
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.platform.email}"
}

resource "google_project_iam_member" "platform_workload_identity_user" {
  project = var.project
  role    = "roles/iam.workloadIdentityUser"
  member  = "serviceAccount:${google_service_account.platform.email}"
}

resource "google_project_iam_member" "platform_logging" {
  project = var.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.platform.email}"
}

resource "google_project_iam_member" "platform_monitoring" {
  project = var.project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.platform.email}"
}

resource "google_service_account_iam_binding" "platform_docker_registry" {
  service_account_id = google_service_account.platform.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project}.svc.id.goog[${var.platform_namespace}/docker-registry]",
  ]
}
