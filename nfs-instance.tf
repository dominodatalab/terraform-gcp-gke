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

  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.default.self_link

    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = "apt install -y nfs-kernel-server && mkdir -p /srv/domino && chmod 777 /srv/domino && echo '/srv/domino 10.0.0.0/255.0.0.0(rw,async,no_root_squash)' >> /etc/exports && systemctl enable nfs-kernel-server --now && sleep 5 && /etc/init.d/nfs-kernel-server restart"

}

resource "google_compute_firewall" "nfs" {
  name    = "${var.deploy_id}-nfs"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["111", "2049", "20048"]
  }

  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["nfs-allowed"]
}
