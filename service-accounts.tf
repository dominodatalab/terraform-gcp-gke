resource "google_service_account" "default" {
  account_id   = "${var.cluster_name}-default"
  display_name = "${var.cluster_name}-default"
}

resource "google_service_account" "kube_system" {
  account_id   = "${var.cluster_name}-system"
  display_name = "${var.cluster_name}-system"
}

resource "google_service_account" "kube_public" {
  account_id   = "${var.cluster_name}-public"
  display_name = "${var.cluster_name}-public"
}

resource "google_service_account" "compute" {
  account_id   = "${var.cluster_name}-compute"
  display_name = "${var.cluster_name}-compute"
}

resource "google_service_account" "platform" {
  account_id   = "${var.cluster_name}-platform"
  display_name = "${var.cluster_name}-platform"
}

resource "google_project_iam_member" "service_account" {
  project = var.project
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.default.email}"
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