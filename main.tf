locals {
  enable_private_endpoint = length(var.master_authorized_networks_config) == 0

  # Converts a cluster's location to a zone/region. A 'location' may be a region or zone: a region becomes the '[region]-a' zone.
  is_regional = length(split("-", var.location)) == 2
  region      = local.is_regional ? var.location : substr(var.location, 0, length(var.location) - 2)
  zone        = local.is_regional ? format("%s-a", var.location) : var.location

  node_pools    = merge(var.node_pools, var.additional_node_pools)
  taint_effects = { "NoSchedule" : "NO_SCHEDULE", "PreferNoSchedule" : "PREFER_NO_SCHEDULE", "NoExecute" : "NO_EXECUTE" }

  crypto_key_id = var.database_encryption_key_name == null ? google_kms_crypto_key.crypto_key[0].id : var.database_encryption_key_name
}

provider "google" {
  project = var.project
  region  = local.region
}

data "google_project" "domino" {
  project_id = var.project
}

resource "google_compute_global_address" "static_ip" {
  count       = var.static_ip_enabled ? 1 : 0
  name        = var.deploy_id
  description = "External static IPv4 address for var.description"
}

resource "google_dns_record_set" "a" {
  count        = var.google_dns_managed_zone.enabled ? 1 : 0
  name         = "${var.deploy_id}.${var.google_dns_managed_zone.dns_name}"
  managed_zone = var.google_dns_managed_zone.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_address.static_ip[0].address]
}

resource "google_dns_record_set" "caa" {
  count        = var.google_dns_managed_zone.enabled ? 1 : 0
  name         = "${var.deploy_id}.${var.google_dns_managed_zone.dns_name}"
  managed_zone = var.google_dns_managed_zone.name
  type         = "CAA"
  ttl          = 300

  rrdatas = ["0 issue \"letsencrypt.org\"", "0 issue \"pki.goog\""]
}

resource "google_compute_network" "vpc_network" {
  name        = var.deploy_id
  description = var.description

  # This helps lowers our subnet quota utilization
  auto_create_subnetworks = false
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

data "google_storage_project_service_account" "gcs_account" {
}

resource "google_kms_crypto_key_iam_binding" "binding" {
  count         = var.database_encryption_key_name == null ? 1 : 0
  crypto_key_id = google_kms_crypto_key.crypto_key[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_storage_bucket" "bucket" {
  name     = "dominodatalab-${var.deploy_id}"
  location = local.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  encryption {
    default_kms_key_name = local.crypto_key_id
  }

  versioning {
    enabled = true
  }

  force_destroy = true

  depends_on = [google_kms_crypto_key_iam_binding.binding]
}

resource "google_storage_bucket_iam_binding" "bucket" {
  bucket = google_storage_bucket.bucket.name
  role   = "roles/storage.admin"
  members = [
    "serviceAccount:${google_service_account.accounts["platform"].email}"
  ]
}

resource "google_filestore_instance" "nfs" {
  count    = var.filestore_disabled ? 0 : 1
  provider = google

  name     = var.deploy_id
  project  = var.project
  tier     = "STANDARD"
  location = local.zone

  file_shares {
    capacity_gb = var.filestore_capacity_gb
    name        = "share1"
  }

  networks {
    network = google_compute_network.vpc_network.name
    modes   = ["MODE_IPV4"]
  }
}

resource "google_kms_key_ring" "key_ring" {
  count    = var.database_encryption_key_name == null ? 1 : 0
  name     = var.deploy_id
  location = local.region
}

resource "google_kms_crypto_key" "crypto_key" {
  count           = var.database_encryption_key_name == null ? 1 : 0
  name            = var.deploy_id
  key_ring        = google_kms_key_ring.key_ring[0].id
  rotation_period = "86400s"
  purpose         = "ENCRYPT_DECRYPT"
}

resource "google_container_cluster" "domino_cluster" {
  name        = var.deploy_id
  location    = var.location
  description = var.description

  # min_master_version sets the desired Kubernetes version of the cluster. If it is not set, GCP will default to latest stable release of GKE engine.
  # GKE releases can be found in  https://cloud.google.com/kubernetes-engine/docs/release-notes
  min_master_version = var.kubernetes_version

  release_channel {
    channel = var.gke_release_channel
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true

  # Workaround for https://github.com/terraform-providers/terraform-provider-google/issues/3385
  # sum function introduced in 0.13
  initial_node_count = local.node_pools.platform.initial_count + local.node_pools.compute.initial_count + local.node_pools.gpu.initial_count

  network    = google_compute_network.vpc_network.self_link
  subnetwork = google_compute_subnetwork.default.self_link

  enable_tpu = false

  vertical_pod_autoscaling {
    enabled = var.enable_vertical_pod_autoscaling
  }

  private_cluster_config {
    enable_private_endpoint = local.enable_private_endpoint
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "172.16.1.0/28"
  }

  ip_allocation_policy {}

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks_config
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  resource_labels = {
    "deploy_id" = var.deploy_id
  }

  # Application-layer Secrets Encryption
  database_encryption {
    state    = "ENCRYPTED"
    key_name = local.crypto_key_id
  }

  workload_identity_config {
    workload_pool = "${data.google_project.domino.project_id}.svc.id.goog"
  }

  network_policy {
    provider = "CALICO"
    enabled  = var.enable_network_policy
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG                 = var.kubeconfig_output_path
      USE_GKE_GCLOUD_AUTH_PLUGIN = "True"
    }
    command = <<-EOF
      if ! gcloud auth print-identity-token 2>/dev/null; then
        printf "%s" "$GOOGLE_CREDENTIALS" | gcloud auth activate-service-account --project="${var.project}" --key-file=-
      fi
      gcloud container clusters get-credentials ${var.deploy_id} ${local.is_regional ? "--region" : "--zone"} ${var.location}
    EOF
  }

}

resource "google_container_node_pool" "node_pools" {
  for_each = local.node_pools

  name           = each.key
  location       = google_container_cluster.domino_cluster.location
  cluster        = google_container_cluster.domino_cluster.name
  node_locations = length(each.value.node_locations) != 0 ? each.value.node_locations : google_container_cluster.domino_cluster.node_locations

  initial_node_count = each.value.initial_count
  max_pods_per_node  = each.value.max_pods

  autoscaling {
    max_node_count = each.value.max_count
    min_node_count = each.value.min_count
  }

  node_config {
    image_type   = each.value.image_type
    preemptible  = each.value.preemptible
    machine_type = each.value.instance_type

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    dynamic "guest_accelerator" {
      for_each = compact([each.value.gpu_accelerator])
      content {
        type  = guest_accelerator.value
        count = 1
      }
    }

    tags = [
      "iap-tcp-forwarding-allowed",
      "domino-${each.key}-node"
    ]

    labels = each.value.labels
    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = split("=", taint.value)[0]
        value  = split(":", split("=", taint.value)[1])[0]
        effect = local.taint_effects[reverse(split(":", taint.value))[0]]
      }
    }

    disk_size_gb    = each.value.disk_size_gb
    local_ssd_count = 1

    metadata = {
      "disable-legacy-endpoints" = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  timeouts {
    delete = "20m"
  }

  lifecycle {
    ignore_changes = [autoscaling, node_config[0].taint, node_locations]
  }
}

# https://cloud.google.com/iap/docs/using-tcp-forwarding
resource "google_compute_firewall" "iap_tcp_forwarding" {
  name    = "${var.deploy_id}-iap"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_ranges
  target_tags   = ["iap-tcp-forwarding-allowed"]
}

# https://github.com/istio/istio/issues/19532
# https://github.com/istio/istio/issues/21991
resource "google_compute_firewall" "master_webhooks" {
  name    = "gke-${var.deploy_id}-master-to-webhook"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = var.master_firewall_ports
  }

  source_ranges = [google_container_cluster.domino_cluster.private_cluster_config[0].master_ipv4_cidr_block]
  target_tags   = ["domino-platform-node"]
}
