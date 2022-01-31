locals {
  enable_private_endpoint = length(var.master_authorized_networks_config) == 0
  uuid                    = "${var.cluster_name}-${random_uuid.id.result}"

  # Converts a cluster's location to a zone/region. A 'location' may be a region or zone: a region becomes the '[region]-a' zone.
  region = length(split("-", var.location)) == 2 ? var.location : substr(var.location, 0, length(var.location) - 2)
  zone   = length(split("-", var.location)) == 3 ? var.location : format("%s-a", var.location)

  node_pools = {
    for node_pool, attrs in var.node_pools :
    node_pool => merge(attrs, lookup(var.node_pool_overrides, node_pool, {}))
  }
  taint_effects = { "NoSchedule" : "NO_SCHEDULE", "PreferNoSchedule" : "PREFER_NO_SCHEDULE", "NoExecute" : "NO_EXECUTE" }
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
  name         = "${var.cluster_name}.${var.google_dns_managed_zone.dns_name}"
  managed_zone = var.google_dns_managed_zone.name
  type         = "A"
  ttl          = 300

  rrdatas = [google_compute_global_address.static_ip.address]
}

resource "google_dns_record_set" "caa" {
  name         = "${var.cluster_name}.${var.google_dns_managed_zone.dns_name}"
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
  description              = "${var.cluster_name} default network"
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
  name     = "dominodatalab-${var.cluster_name}"
  location = split("-", var.location)[0]

  versioning {
    enabled = true
  }

  force_destroy = true
}

resource "google_filestore_instance" "nfs" {
  count = var.filestore_disabled ? 0 : 1

  name = local.uuid
  tier = "STANDARD"
  zone = var.location

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
  name        = var.cluster_name
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

  # deprecated
  pod_security_policy_config {
    enabled = var.enable_pod_security_policy
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_output_path
    }
    command = <<-EOF
      if ! gcloud auth print-identity-token 2>/dev/null; then
        printf "%s" "$GOOGLE_CREDENTIALS" | gcloud auth activate-service-account --project="${var.project}" --key-file=-
      fi
      gcloud container clusters get-credentials ${var.cluster_name} --zone ${local.zone}
    EOF
  }
}

resource "google_kms_key_ring" "key_ring" {
  name     = local.uuid
  location = local.region
}

resource "google_kms_crypto_key" "crypto_key" {
  name            = local.uuid
  key_ring        = google_kms_key_ring.key_ring.id
  rotation_period = "86400s"
  purpose         = "ENCRYPT_DECRYPT"
}

resource "google_container_node_pool" "node_pools" {
  for_each = local.node_pools

  name     = each.key
  location = google_container_cluster.domino_cluster.location
  cluster  = google_container_cluster.domino_cluster.name

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
    ignore_changes = [autoscaling, node_config[0].taint]
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
resource "google_compute_firewall" "master-webhooks" {
  name    = "gke-${var.cluster_name}-master-to-webhook"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = var.master_firewall_ports
  }

  source_ranges = [google_container_cluster.domino_cluster.private_cluster_config[0].master_ipv4_cidr_block]
  target_tags   = ["domino-platform-node"]
}
