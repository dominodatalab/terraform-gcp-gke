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

resource "google_dns_record_set" "caa_services" {
  for_each     = var.managed_dns.enabled ? var.managed_dns.service_prefixes : []
  name         = "${each.value}${var.deploy_id}.${var.managed_dns.dns_name}"
  managed_zone = var.managed_dns.name
  type         = "CAA"
  ttl          = 300

  rrdatas = ["0 issue \"letsencrypt.org\"", "0 issue \"pki.goog\""]
}
