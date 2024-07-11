# tfsec:ignore:google-compute-disk-encryption-customer-key
resource "google_compute_disk" "nfs" {
  #checkov:skip=CKV_GCP_37:Avoid extra churn for testing-only instance
  count = var.storage.nfs_instance.enabled ? 1 : 0

  name = "${var.deploy_id}-nfs-data"
  type = "pd-standard"
  zone = local.zone
  size = var.storage.nfs_instance.capacity_gb
}

# tfsec:ignore:google-compute-no-project-wide-ssh-keys
resource "google_compute_instance" "nfs" {
  #checkov:skip=CKV_GCP_37:Avoid extra churn for testing-only instance
  #checkov:skip=CKV_GCP_38:Avoid extra churn for testing-only instance
  #checkov:skip=CKV_GCP_32:SSH is useful for troubleshooting, and this is for testing only
  #checkov:skip=CKV_GCP_40:This is need for ssh
  count = var.storage.nfs_instance.enabled ? 1 : 0

  name                      = "${var.deploy_id}-nfs"
  machine_type              = "n2-standard-2"
  zone                      = local.zone
  allow_stopping_for_update = true

  tags = ["iap-tcp-forwarding-allowed", "nfs-allowed"]

  # tfsec:ignore:google-compute-vm-disk-encryption-customer-key
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  # tfsec:ignore:google-compute-vm-disk-encryption-customer-key
  attached_disk {
    source      = google_compute_disk.nfs[0].self_link
    device_name = "nfs"
  }

  network_interface {
    network    = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.default.self_link

    # tfsec:ignore:google-compute-no-public-ip
    access_config {
      # Ephemeral public IP
    }
  }

  shielded_instance_config {
    enable_vtpm = true
  }

  metadata_startup_script = templatefile("${path.module}/templates/nfs-install.sh", { nfs_path = local.nfs_path })

  lifecycle {
    ignore_changes = [attached_disk]
  }
}

resource "google_compute_firewall" "nfs" {
  count   = var.storage.nfs_instance.enabled ? 1 : 0
  name    = "${var.deploy_id}-nfs"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["111", "2049", "20048"]
  }

  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["nfs-allowed"]
}
