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

resource "google_service_account_iam_binding" "service_account" {
  service_account_id = google_service_account.default.name
  role               = "roles/iam.serviceAccountUser"
  members            = ["serviceAccount:${google_service_account.default.email}"]
}

resource "google_service_account_iam_binding" "kube_system_service_account" {
  service_account_id = google_service_account.kube_system.name
  role               = "roles/iam.serviceAccountUser"
  members            = ["serviceAccount:${google_service_account.kube_system.email}"]
}

resource "google_service_account_iam_binding" "kube_public_service_account" {
  service_account_id = google_service_account.kube_public.name
  role               = "roles/iam.serviceAccountUser"
  members            = ["serviceAccount:${google_service_account.kube_public.email}"]
}

resource "google_service_account_iam_binding" "compute_service_account" {
  service_account_id = google_service_account.compute.name
  role               = "roles/iam.serviceAccountUser"
  members            = ["serviceAccount:${google_service_account.compute.email}"]
}

resource "google_service_account_iam_binding" "platform_service_account" {
  service_account_id = google_service_account.platform.name
  role               = "roles/iam.serviceAccountUser"
  members            = ["serviceAccount:${google_service_account.platform.email}"]
}