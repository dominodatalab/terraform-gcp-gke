resource "google_compute_address" "nfs" {
  count    = var.storage.nfs_instance.enabled ? 1 : 0

  name = "${var.deploy_id}-nfs"
}

resource "google_compute_disk" "nfs" {
  count    = var.storage.nfs_instance.enabled ? 1 : 0

  name = "${var.deploy_id}-nfs-data"
  type = "pd-ssd" // TODO: Cheapest type?
  zone = local.zone
  size = var.storage.nfs_instance.capacity_gb
}

resource "google_compute_instance" "nfs" {
  count    = var.storage.nfs_instance.enabled ? 1 : 0

  name         = "${var.deploy_id}-nfs"
  machine_type = "n2-standard-2"
  zone         = local.zone

  tags = ["iap-tcp-forwarding-allowed", "nfs-allowed"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  attached_disk {
    source = google_compute_disk.nfs[0].self_link
    device_name = "nfs"
  }

  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.default.self_link

    access_config {
        nat_ip = google_compute_address.nfs[0].address
    }
  }

  metadata_startup_script = file("${path.module}/templates/nfs-install.sh")

  lifecycle {
    ignore_changes = [attached_disk]
  }
}

resource "google_compute_firewall" "nfs" {
  count    = var.storage.nfs_instance.enabled ? 1 : 0
  name    = "${var.deploy_id}-nfs"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["111", "2049", "20048"]
  }

  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["nfs-allowed"]
}
