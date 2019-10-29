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
  enable_private_endpoint = length(var.master_authorized_networks_config.cidr_block) == 0

  # Converts a cluster's location to a zone/region. A 'location' may be a region or zone: a region becomes the '[region]-a' zone.
  region = length(split("-", var.location)) == 2 ? var.location : substr(var.location, 0, length(var.location) - 2)
  zone   = length(split("-", var.location)) == 3 ? var.location : format("%s-a", var.location)
}

provider "google" {
  version = "2.17.0"
  project = var.project
  region  = local.region
}

provider "google-beta" {
  version = "2.17.0"
  project = var.project
  region  = local.region
}

data "google_project" "domino" {
  project_id = var.project
}

resource "google_compute_address" "static_ip" {
  name        = local.cluster
  description = "External static IPv4 address for var.description"
}

resource "google_dns_record_set" "a" {
  name         = "${local.cluster}.${var.google_dns_managed_zone.dns_name}"
  managed_zone = var.google_dns_managed_zone.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_address.static_ip.address]
}

resource "google_compute_network" "vpc_network" {
  name        = local.cluster
  description = var.description

  # This helps lowers our subnet quota utilization
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "default" {
  name                     = local.cluster
  ip_cidr_range            = "10.138.0.0/20"
  network                  = google_compute_network.vpc_network.self_link
  private_ip_google_access = false
  description              = "${local.cluster} default network"
}

resource "google_compute_router" "router" {
  name    = local.cluster
  network = google_compute_network.vpc_network.self_link
}

resource "google_compute_router_nat" "nat" {
  name                               = local.cluster
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

  # TODO: this won't work ...
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365
    }
  }

  force_destroy = true
}

resource "google_filestore_instance" "nfs" {
  name = local.cluster
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
}

resource "google_container_cluster" "domino_cluster" {
  provider = "google-beta"

  name               = local.cluster
  location           = var.location
  description        = var.description
  min_master_version = var.gke_version

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc_network.self_link
  subnetwork = google_compute_subnetwork.default.self_link

  # TODO ??
  enable_tpu = true

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = true
    }
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
    cidr_blocks {
      cidr_block   = var.master_authorized_networks_config.cidr_block
      display_name = var.master_authorized_networks_config.display_name
    }
  }

  # Application-layer Secrets Encryption
  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.crypto_key.self_link
  }

  workload_identity_config {
    identity_namespace = "${data.google_project.domino.project_id}.svc.id.goog"
  }

}

resource "google_container_node_pool" "platform" {
  name     = "platform"
  location = google_container_cluster.domino_cluster.location
  cluster  = google_container_cluster.domino_cluster.name
  version  = var.gke_version

  initial_node_count = var.platform_nodes_max
  autoscaling {
    max_node_count = var.platform_nodes_max
    min_node_count = var.platform_nodes_min
  }

  node_config {
    preemptible  = var.platform_nodes_preemptible
    machine_type = var.platform_node_type

    labels = {
      "dominodatalab.com/node-pool" = "platform"
    }

    disk_size_gb    = var.platform_nodes_ssd_gb
    local_ssd_count = 1
  }

  management {
    auto_repair = true
  }

  timeouts {
    delete = "20m"
  }
}

resource "google_container_node_pool" "compute" {
  name     = "compute"
  location = google_container_cluster.domino_cluster.location
  cluster  = google_container_cluster.domino_cluster.name
  version  = var.gke_version

  initial_node_count = max(1, var.compute_nodes_min)
  autoscaling {
    max_node_count = var.compute_nodes_max
    min_node_count = var.compute_nodes_min
  }

  node_config {
    preemptible  = var.compute_nodes_preemptible
    machine_type = var.platform_node_type

    labels = {
      "domino/build-node"            = "true"
      "dominodatalab.com/build-node" = "true"
      "dominodatalab.com/node-pool"  = "default"
    }

    disk_size_gb    = var.compute_nodes_ssd_gb
    local_ssd_count = 1
  }

  management {
    auto_repair = true
  }

  timeouts {
    delete = "20m"
  }
}

resource "google_container_node_pool" "gpu" {
  provider = "google-beta"

  name     = "gpu"
  location = google_container_cluster.domino_cluster.location
  cluster  = google_container_cluster.domino_cluster.name
  version  = var.gke_version

  initial_node_count = min(0, var.gpu_nodes_min)
  autoscaling {
    max_node_count = var.gpu_nodes_max
    min_node_count = var.gpu_nodes_min
  }

  node_config {
    preemptible  = var.gpu_nodes_preemptible
    machine_type = var.gpu_node_type

    guest_accelerator {
      type  = var.gpu_nodes_accelerator
      count = 1
    }

    labels = {
      "dominodatalab.com/node-pool" = "default-gpu"
    }

    disk_size_gb    = var.gpu_nodes_ssd_gb
    local_ssd_count = 1
  }

  management {
    auto_repair = true
  }

  timeouts {
    delete = "20m"
  }
}

resource "random_id" "kms" {
  byte_length = 8
  prefix      = "${local.cluster}-"
}

resource "google_kms_key_ring" "key_ring" {
  name     = random_id.kms.b64_url
  location = local.region
}

resource "google_kms_crypto_key" "crypto_key" {
  name            = random_id.kms.b64_url
  key_ring        = google_kms_key_ring.key_ring.self_link
  rotation_period = "86400s"
  purpose         = "ENCRYPT_DECRYPT"
}
