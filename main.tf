terraform {
  required_version = ">= 0.12.0"
  backend "gcs" {
    bucket = "domino-terraform-default" # Should specify using cli -backend-config="bucket=domino-terraform-default"
    # Override with `terraform init -backend-config="prefix=/terraform/state/[YOUR/PATH]"`
    prefix = "terraform/state"
  }
}

locals {
  cluster                 = var.cluster == null ? terraform.workspace : var.cluster
  enable_private_endpoint = length(var.master_authorized_networks_config) == 0
  uuid                    = "${local.cluster}-${random_uuid.id.result}"

  # Converts a cluster's location to a zone/region. A 'location' may be a region or zone: a region becomes the '[region]-a' zone.
  region = length(split("-", var.location)) == 2 ? var.location : substr(var.location, 0, length(var.location) - 2)
  zone   = length(split("-", var.location)) == 3 ? var.location : format("%s-a", var.location)

  authorized_networks = var.master_authorized_networks_config
}

provider "google" {
  project = var.project
  region  = local.region
}

data "google_project" "domino" {
  project_id = var.project
}

resource "random_uuid" "id" {}

resource "google_compute_global_address" "static_ip" {
  name        = local.uuid
  description = "External static IPv4 address for var.description"
}

resource "google_dns_record_set" "a" {
  name         = "${local.cluster}.${var.google_dns_managed_zone.dns_name}"
  managed_zone = var.google_dns_managed_zone.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_address.static_ip.address]
}

resource "google_dns_record_set" "caa" {
  name         = "${local.cluster}.${var.google_dns_managed_zone.dns_name}"
  managed_zone = var.google_dns_managed_zone.name
  type         = "CAA"
  ttl          = 300

  rrdatas = ["0 issue \"letsencrypt.org\"", "0 issue \"pki.goog\""]
}

resource "google_compute_network" "vpc_network" {
  name        = local.uuid
  description = var.description

  # This helps lowers our subnet quota utilization
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "default" {
  name                     = local.uuid
  ip_cidr_range            = "10.138.0.0/20"
  network                  = google_compute_network.vpc_network.self_link
  private_ip_google_access = true
  description              = "${local.cluster} default network"
}

resource "google_compute_router" "router" {
  name    = local.uuid
  network = google_compute_network.vpc_network.self_link
}

resource "google_compute_router_nat" "nat" {
  name                               = local.uuid
  router                             = google_compute_router.router.name
  region                             = local.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_storage_bucket" "bucket" {
  name     = "dominodatalab-${local.cluster}"
  location = split("-", var.location)[0]

  versioning {
    enabled = true
  }

  force_destroy = true
}

resource "google_filestore_instance" "nfs" {
  name = local.uuid
  tier = "STANDARD"
  zone = local.zone

  file_shares {
    capacity_gb = var.filestore_capacity_gb
    name        = "share1"
  }

  networks {
    network = google_compute_network.vpc_network.name
    modes   = ["MODE_IPV4"]
  }

  count = var.filestore_disabled ? 0 : 1
}

resource "google_container_cluster" "domino_cluster" {
  name        = local.cluster
  location    = var.location
  description = var.description

  release_channel {
    channel = var.gke_release_channel
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true

  # Workaround for https://github.com/terraform-providers/terraform-provider-google/issues/3385
  initial_node_count = max(1, var.compute_nodes_min) + max(0, var.gpu_nodes_min) + var.platform_nodes_max

  network    = google_compute_network.vpc_network.self_link
  subnetwork = google_compute_subnetwork.default.self_link

  enable_tpu = false

  master_auth {
    client_certificate_config {
      issue_client_certificate = true
    }
  }

  # This resource's provider has issues with reconciling the remote/local state
  # of the `issue_client_certificate` field because we use channels to
  # implicitly set a cluster version.
  #
  # We're going to ignore all changes to the `master_auth` block since we set
  # these values statically. Hopefully, this issue will be resolved in a future
  # version of the provider. See the following issue for more context.
  #
  # https://github.com/terraform-providers/terraform-provider-google/issues/3369#issuecomment-487226330
  lifecycle {
    ignore_changes = [master_auth]
  }

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
      for_each = local.authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  resource_labels = {
    "uuid" = local.uuid
  }

  # Application-layer Secrets Encryption
  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.crypto_key.self_link
  }

  workload_identity_config {
    identity_namespace = "${data.google_project.domino.project_id}.svc.id.goog"
  }

  network_policy {
    provider = "CALICO"
    enabled  = var.enable_network_policy
  }

  pod_security_policy_config {
    enabled = var.enable_pod_security_policy
  }
}

resource "google_container_node_pool" "platform" {
  name     = "platform"
  location = google_container_cluster.domino_cluster.location
  cluster  = google_container_cluster.domino_cluster.name

  initial_node_count = var.platform_nodes_max
  autoscaling {
    max_node_count = var.platform_nodes_max
    min_node_count = var.platform_nodes_min
  }

  node_config {
    image_type   = var.platform_node_image_type
    preemptible  = var.platform_nodes_preemptible
    machine_type = var.platform_node_type

    tags = [
      "iap-tcp-forwarding-allowed",
      "domino-platform-node"
    ]

    labels = {
      "dominodatalab.com/node-pool" = "platform"
    }

    disk_size_gb    = var.platform_nodes_ssd_gb
    local_ssd_count = 1
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  timeouts {
    delete = "20m"
  }

  lifecycle {
    ignore_changes = [autoscaling]
  }
}

resource "google_container_node_pool" "compute" {
  name     = "compute"
  location = google_container_cluster.domino_cluster.location
  cluster  = google_container_cluster.domino_cluster.name


  initial_node_count = max(1, var.compute_nodes_min)
  autoscaling {
    max_node_count = var.compute_nodes_max
    min_node_count = var.compute_nodes_min
  }

  node_config {
    image_type   = var.compute_node_image_type
    preemptible  = var.compute_nodes_preemptible
    machine_type = var.compute_node_type

    tags = [
      "iap-tcp-forwarding-allowed"
    ]

    labels = {
      "domino/build-node"            = "true"
      "dominodatalab.com/build-node" = "true"
      "dominodatalab.com/node-pool"  = "default"
    }

    disk_size_gb    = var.compute_nodes_ssd_gb
    local_ssd_count = 1
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  timeouts {
    delete = "20m"
  }

  lifecycle {
    ignore_changes = [autoscaling]
  }
}

resource "google_kms_key_ring" "key_ring" {
  name     = local.uuid
  location = local.region
}

resource "google_kms_crypto_key" "crypto_key" {
  name            = local.uuid
  key_ring        = google_kms_key_ring.key_ring.self_link
  rotation_period = "86400s"
  purpose         = "ENCRYPT_DECRYPT"
}

resource "google_container_node_pool" "gpu" {
  name     = "gpu"
  location = google_container_cluster.domino_cluster.location
  cluster  = google_container_cluster.domino_cluster.name

  initial_node_count = max(0, var.gpu_nodes_min)


  autoscaling {
    max_node_count = var.gpu_nodes_max
    min_node_count = var.gpu_nodes_min
  }

  node_config {
    image_type   = var.gpu_node_image_type
    preemptible  = var.gpu_nodes_preemptible
    machine_type = var.gpu_node_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring"
    ]

    dynamic "guest_accelerator" {
      for_each = [var.gpu_nodes_accelerator]
      content {
        type  = guest_accelerator.value
        count = 1
      }
    }

    tags = [
      "iap-tcp-forwarding-allowed"
    ]

    labels = {
      "dominodatalab.com/node-pool" = "default-gpu"
    }

    disk_size_gb    = var.gpu_nodes_ssd_gb
    local_ssd_count = 1
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  timeouts {
    delete = "20m"
  }

  lifecycle {
    ignore_changes = [autoscaling]
  }
}

# https://cloud.google.com/iap/docs/using-tcp-forwarding
resource "google_compute_firewall" "iap-tcp-forwarding" {
  name    = "${local.uuid}-iap"
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
resource "google_compute_firewall" "master-to-istiowebhook" {
  name        = "gke-${local.cluster}-master-to-istiowebhook"
  network     = google_compute_network.vpc_network.name
  description = "Istio Admission Controller needs to communicate with GKE master"

  allow {
    protocol = "tcp"
    ports    = ["443", "9443", "15017"]
  }

  source_ranges = [google_container_cluster.domino_cluster.private_cluster_config[0].master_ipv4_cidr_block]
  target_tags   = ["domino-platform-node"]
}
