resource "google_compute_global_address" "static_ip" {
  count = var.managed_dns.enabled ? 1 : 0
  name  = var.deploy_id
}

resource "google_dns_record_set" "a" {
  count        = var.managed_dns.enabled ? 1 : 0
  name         = "${var.deploy_id}.${var.managed_dns.dns_name}"
  managed_zone = var.managed_dns.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_address.static_ip[0].address]
}

resource "google_dns_record_set" "a_services" {
  for_each     = var.managed_dns.enabled ? var.managed_dns.service_prefixes : []
  name         = "${each.value}${var.deploy_id}.${var.managed_dns.dns_name}"
  managed_zone = var.managed_dns.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_address.static_ip[0].address]
}

resource "google_dns_record_set" "caa" {
  count        = var.managed_dns.enabled ? 1 : 0
  name         = "${var.deploy_id}.${var.managed_dns.dns_name}"
  managed_zone = var.managed_dns.name
  type         = "CAA"
  ttl          = 300

  rrdatas = ["0 issue \"letsencrypt.org\"", "0 issue \"pki.goog\""]
}

# Per-dataplane zone; the caller NS-delegates it from the control plane's Route53 zone.
# Signing is opt-in: every parent up to domino.tech is unsigned, so a DS record could never
# be authenticated.
# tfsec:ignore:google-dns-enable-dnssec
resource "google_dns_managed_zone" "dataplane" {
  count       = var.managed_dns.zone_create ? 1 : 0
  name        = var.deploy_id
  dns_name    = "${trimsuffix(var.managed_dns.zone_fqdn, ".")}."
  description = "Domino dataplane DNS zone for ${var.deploy_id}"

  dynamic "dnssec_config" {
    for_each = var.managed_dns.dnssec ? [1] : []
    content {
      state = "on"
    }
  }
}

resource "google_service_account" "external_dns" {
  count = var.managed_dns.zone_create ? 1 : 0

  account_id   = "${var.deploy_id}-ext-dns"
  display_name = "${var.deploy_id}-external-dns"
}

resource "google_service_account_iam_member" "external_dns_workload_identity" {
  count = var.managed_dns.zone_create ? 1 : 0

  service_account_id = google_service_account.external_dns[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.platform}/external-dns]"
}

resource "google_dns_managed_zone_iam_member" "external_dns" {
  count = var.managed_dns.zone_create ? 1 : 0

  project      = var.project
  managed_zone = google_dns_managed_zone.dataplane[0].name
  role         = "roles/dns.admin"
  member       = "serviceAccount:${google_service_account.external_dns[0].email}"
}

# external-dns discovers its zone by listing zones at project scope, which the zone-scoped
# grant above cannot satisfy. dns.reader is read-only; writes stay zone-scoped.
resource "google_project_iam_member" "external_dns_zone_reader" {
  count = var.managed_dns.zone_create ? 1 : 0

  project = var.project
  role    = "roles/dns.reader"
  member  = "serviceAccount:${google_service_account.external_dns[0].email}"
}

resource "google_service_account" "cert_manager" {
  count = var.managed_dns.zone_create ? 1 : 0

  account_id   = "${var.deploy_id}-cert-mgr"
  display_name = "${var.deploy_id}-cert-manager"
}

resource "google_service_account_iam_member" "cert_manager_workload_identity" {
  count = var.managed_dns.zone_create ? 1 : 0

  service_account_id = google_service_account.cert_manager[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project}.svc.id.goog[${var.namespaces.platform}/cert-manager]"
}

resource "google_dns_managed_zone_iam_member" "cert_manager" {
  count = var.managed_dns.zone_create ? 1 : 0

  project      = var.project
  managed_zone = google_dns_managed_zone.dataplane[0].name
  role         = "roles/dns.admin"
  member       = "serviceAccount:${google_service_account.cert_manager[0].email}"
}

resource "google_dns_record_set" "caa_services" {
  for_each     = var.managed_dns.enabled ? var.managed_dns.service_prefixes : []
  name         = "${each.value}${var.deploy_id}.${var.managed_dns.dns_name}"
  managed_zone = var.managed_dns.name
  type         = "CAA"
  ttl          = 300

  rrdatas = ["0 issue \"letsencrypt.org\"", "0 issue \"pki.goog\""]
}
