terraform {
  required_version = ">= 0.12.0"
  backend "gcs" {
    bucket  = "domino-terraform-default"  # Should specify using cli -backend-config="bucket=domino-terraform-default"
    # prefix  = "terraform/state"  # Specify using cli -backend-config="prefix=domino-[cluster-name]/terraform/state"
  }
}

provider "google" {
  project = "${var.project}"
}

locals {
  # Converts a cluster's location to a zone. A 'location' may be a region or zone: a region becomes the '[region]-a' zone.
  zone = length(split("-", google_container_cluster.domino_cluster.location)) == 3 ? google_container_cluster.domino_cluster.location : format("%s-a", google_container_cluster.domino_cluster.location)
}

resource "google_filestore_instance" "nfs" {
  name = "${var.cluster_name}"  
  tier = "STANDARD"
  zone = "${local.zone}"

  file_shares {
    capacity_gb = 2660
    name        = "share1"
  }

  networks {
    network = "default"
    modes   = ["MODE_IPV4"]
  }
}

resource "google_container_cluster" "domino_cluster" {
  name     = "${var.cluster_name}"
  location = "${var.location}"
  description = "The primary Domino K8s Cluster for ${var.cluster_name}"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = true
    }
  }
}

resource "google_container_node_pool" "platform" {
  name       = "platform"
  location   = "${google_container_cluster.domino_cluster.location}"
  cluster    = "${google_container_cluster.domino_cluster.name}"

  initial_node_count = "${var.platform_nodes_min}"
  autoscaling {
    max_node_count = "${var.platform_nodes_max}"
    min_node_count = "${var.platform_nodes_min}"
  }

  node_config {
    preemptible  = "${var.platform_nodes_preemptible}"
    machine_type = "${var.platform_node_type}"

    labels = {
      "dominodatalab.com/node-pool" = "platform"
    }

    disk_size_gb = 100
    local_ssd_count = 2
  }

  management {
    auto_repair = true
  }
}

resource "google_container_node_pool" "compute" {
  name       = "compute"
  location   = "${google_container_cluster.domino_cluster.location}"
  cluster    = "${google_container_cluster.domino_cluster.name}"

  initial_node_count = "${var.compute_nodes_min}"
  autoscaling {
    max_node_count = "${var.compute_nodes_max}"
    min_node_count = "${var.compute_nodes_min}"
  }

  node_config {
    preemptible  = "${var.compute_nodes_preemptible}"
    machine_type = "${var.platform_node_type}"

    labels = {
      "dominodatalab.com/node-pool" = "compute"
    }

    disk_size_gb = 100
    local_ssd_count = 2
  }

  management {
    auto_repair = true
  }
}

resource "google_container_node_pool" "build" {
  name       = "build"
  location   = "${google_container_cluster.domino_cluster.location}"
  cluster    = "${google_container_cluster.domino_cluster.name}"

  initial_node_count = "${var.build_nodes_min}"
  autoscaling {
    max_node_count = "${var.build_nodes_max}"
    min_node_count = "${var.build_nodes_min}"
  }

  node_config {
    preemptible  = "${var.build_nodes_preemptible}"
    machine_type = "${var.build_node_type}"

    labels = {
      "domino/build-node" = "true"
      "dominodatalab.com/node-pool" = "build"
    }

    disk_size_gb = 100
    local_ssd_count = 2
  }

  management {
    auto_repair = true
  }
}