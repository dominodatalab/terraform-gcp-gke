locals {
  node_pools    = merge(var.node_pools, var.additional_node_pools)
  taint_effects = { "NoSchedule" : "NO_SCHEDULE", "PreferNoSchedule" : "PREFER_NO_SCHEDULE", "NoExecute" : "NO_EXECUTE" }
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

    # Google Container Filesystem - required to enable Image Streaming
    gcfs_config {
      enabled = true
    }

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

    disk_size_gb = each.value.disk_size_gb

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
