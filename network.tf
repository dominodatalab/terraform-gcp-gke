resource "google_compute_network" "vpc_network" {
  name = var.deploy_id

  # This helps lowers our subnet quota utilization
  auto_create_subnetworks = false

  lifecycle {
    ignore_changes = [description]
  }
}

resource "google_compute_subnetwork" "default" {
  name                     = var.deploy_id
  ip_cidr_range            = "10.138.0.0/20"
  network                  = google_compute_network.vpc_network.self_link
  private_ip_google_access = true
  description              = "${var.deploy_id} default network"
}

resource "google_compute_router" "router" {
  name    = var.deploy_id
  network = google_compute_network.vpc_network.self_link
}

resource "google_compute_router_nat" "nat" {
  name                               = var.deploy_id
  router                             = google_compute_router.router.name
  region                             = local.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
