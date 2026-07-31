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

# GCNV requires at least a /24 PSA range; GCP selects the address.
resource "google_compute_global_address" "gcnv" {
  count = var.storage.gcnv.enabled ? 1 : 0

  name          = "${var.deploy_id}-gcnv"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.vpc_network.self_link
}

resource "google_service_networking_connection" "gcnv" {
  count = var.storage.gcnv.enabled ? 1 : 0

  network                 = google_compute_network.vpc_network.self_link
  service                 = "netapp.servicenetworking.goog"
  reserved_peering_ranges = [google_compute_global_address.gcnv[0].name]
}

resource "google_compute_network_peering_routes_config" "gcnv" {
  count = var.storage.gcnv.enabled ? 1 : 0

  peering = google_service_networking_connection.gcnv[0].peering
  network = google_compute_network.vpc_network.name

  # Propagate routes across the NetApp service peering.
  import_custom_routes = true
  export_custom_routes = true
}
