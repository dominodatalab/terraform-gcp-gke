locals {
  #  webhooks: prometheus-adapter, vault-agent, newrelic, hephaestus, cert-manager, istio
  required_webhooks = ["6443", "8080", "8443", "9443", "10250", "15017"]
}

resource "google_container_cluster" "domino_cluster" {
  name     = var.deploy_id
  location = var.location

  # min_master_version sets the desired Kubernetes version of the cluster. If it is not set, GCP will default to latest stable release of GKE engine.
  # GKE releases can be found in  https://cloud.google.com/kubernetes-engine/docs/release-notes
  min_master_version = var.gke.k8s_version

  release_channel {
    channel = var.gke.release_channel
  }

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true

  # On version 5.0.0+ of the provider, you must explicitly set deletion_protection = false
  # and run terraform apply to write the field to state in order to destroy a cluster.
  deletion_protection = false

  # Workaround for https://github.com/terraform-providers/terraform-provider-google/issues/3385
  # sum function introduced in 0.13
  initial_node_count = local.node_pools.platform.initial_count + local.node_pools.compute.initial_count + local.node_pools.gpu.initial_count

  network    = google_compute_network.vpc_network.self_link
  subnetwork = google_compute_subnetwork.default.self_link

  enable_tpu = false

  vertical_pod_autoscaling {
    enabled = var.gke.vertical_pod_autoscaling
  }

  private_cluster_config {
    enable_private_endpoint = !var.gke.public_access.enabled
    enable_private_nodes    = true
    master_ipv4_cidr_block  = "172.16.1.0/28"
  }

  ip_allocation_policy {}

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.gke.public_access.enabled ? var.gke.public_access.cidrs : []
      content {
        cidr_block = cidr_blocks.value
      }
    }
  }

  resource_labels = {
    "deploy_id" = var.deploy_id
  }

  # Application-layer Secrets Encryption
  database_encryption {
    state    = "ENCRYPTED"
    key_name = var.kms.database_encryption_key_name == null ? google_kms_crypto_key.crypto_key[0].id : var.kms.database_encryption_key_name
  }

  workload_identity_config {
    workload_pool = "${data.google_project.domino.project_id}.svc.id.goog"
  }

  datapath_provider = var.gke.advanced_datapath ? "ADVANCED_DATAPATH" : null

  network_policy {
    provider = var.gke.advanced_datapath ? "PROVIDER_UNSPECIFIED" : "CALICO"
    enabled  = var.gke.network_policies
  }

  provisioner "local-exec" {
    environment = {
      KUBECONFIG                 = var.gke.kubeconfig.path
      USE_GKE_GCLOUD_AUTH_PLUGIN = "True"
    }
    command = <<-EOF
      if ! gcloud auth print-identity-token 2>/dev/null; then
        printf "%s" "$GOOGLE_CREDENTIALS" | gcloud auth activate-service-account --project="${var.project}" --key-file=-
      fi
      gcloud container clusters get-credentials ${var.deploy_id} --project="${var.project}" ${local.is_regional ? "--region" : "--zone"} ${var.location}
    EOF
  }

  lifecycle {
    ignore_changes = [description]
  }
}

resource "google_compute_firewall" "master_webhooks" {
  name    = "gke-${var.deploy_id}-master-to-webhook"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = local.required_webhooks
  }

  source_ranges = [google_container_cluster.domino_cluster.private_cluster_config[0].master_ipv4_cidr_block]
}
