# Terraform owns the GCNV pool; Trident manages its ONTAP volumes.
locals {
  gcnv_regional     = var.storage.gcnv.regional
  gcnv_zone_lookup  = var.storage.gcnv.enabled && !local.gcnv_regional && local.is_regional
  gcnv_location     = local.gcnv_zone_lookup ? sort(data.google_compute_zones.gcnv[0].names)[0] : (local.gcnv_regional ? local.region : local.zone)
  gcnv_primary_zone = local.gcnv_regional ? var.storage.gcnv.primary_zone : null
  gcnv_replica_zone = local.gcnv_regional ? var.storage.gcnv.replica_zone : null
  gcnv_root_volume = var.storage.gcnv.enabled ? one([
    for volume in data.netapp-ontap_volumes.gcnv[0].storage_volumes : volume
    if endswith(lower(volume.name), "_root")
    && volume.nas.junction_path == "/"
    && lower(volume.state) == "online"
    && lower(volume.type) == "rw"
  ]) : null
}

data "google_compute_zones" "gcnv" {
  count = local.gcnv_zone_lookup ? 1 : 0

  project = var.project
  region  = local.region
}

resource "google_netapp_storage_pool" "gcnv" {
  count = var.storage.gcnv.enabled ? 1 : 0

  name         = var.deploy_id
  location     = local.gcnv_location
  zone         = local.gcnv_primary_zone
  replica_zone = local.gcnv_replica_zone
  # ONTAP-mode is only supported by Flex Unified.
  service_level = "FLEX"
  capacity_gib  = tostring(var.storage.gcnv.pool_capacity_gib)

  # The API requires a relative network ID.
  network = google_compute_network.vpc_network.id
  type    = "UNIFIED"
  mode    = "ONTAP"

  depends_on = [google_compute_network_peering_routes_config.gcnv[0]]

  lifecycle {
    precondition {
      condition = !local.gcnv_regional || (
        can(regex("^${local.region}-[a-z]$", local.gcnv_primary_zone)) &&
        can(regex("^${local.region}-[a-z]$", local.gcnv_replica_zone)) &&
        local.gcnv_replica_zone != local.gcnv_primary_zone
      )
      error_message = "Regional GCNV pools require distinct primary_zone and replica_zone values in the deployment region."
    }

    # Preserve a zone switch performed by GCNV failover.
    ignore_changes = [zone, replica_zone]
  }
}

resource "terraform_data" "gcnv_ontap_ready" {
  count = var.storage.gcnv.enabled ? 1 : 0

  input = {
    project      = var.project
    location     = google_netapp_storage_pool.gcnv[0].location
    storage_pool = google_netapp_storage_pool.gcnv[0].name
    script       = "${path.module}/scripts/wait_gcnv_ontap_ready.py"
  }
  triggers_replace = [google_netapp_storage_pool.gcnv[0].id]

  provisioner "local-exec" {
    environment = {
      GCNV_READINESS_SCRIPT = self.input.script
      GCNV_PROJECT          = self.input.project
      GCNV_LOCATION         = self.input.location
      GCNV_STORAGE_POOL     = self.input.storage_pool
    }

    command = <<-EOF
      python3 "$GCNV_READINESS_SCRIPT" \
        --project "$GCNV_PROJECT" \
        --location "$GCNV_LOCATION" \
        --storage-pool "$GCNV_STORAGE_POOL"
    EOF
  }
}

data "netapp-ontap_volumes" "gcnv" {
  count = var.storage.gcnv.enabled ? 1 : 0

  cx_profile_name = var.deploy_id

  depends_on = [terraform_data.gcnv_ontap_ready]
}

resource "netapp-ontap_nfs_export_policy_rule" "gcnv_node_access" {
  count = var.storage.gcnv.enabled ? 1 : 0

  cx_profile_name    = var.deploy_id
  svm_name           = local.gcnv_root_volume.svm_name
  export_policy_name = local.gcnv_root_volume.nas.export_policy_name
  clients_match      = [google_compute_subnetwork.default.ip_cidr_range]
  protocols          = ["nfs"]
  ro_rule            = ["any"]
  rw_rule            = ["any"]
  superuser          = ["none"]
}

# Delete Trident-owned volumes before Terraform deletes their pool.
resource "terraform_data" "gcnv_volume_cleanup" {
  count = var.storage.gcnv.enabled ? 1 : 0

  input = {
    project      = var.project
    location     = google_netapp_storage_pool.gcnv[0].location
    storage_pool = google_netapp_storage_pool.gcnv[0].name
    script       = "${path.module}/scripts/delete_gcnv_ontap_volumes.py"
  }
  triggers_replace = [google_netapp_storage_pool.gcnv[0].id]

  provisioner "local-exec" {
    when = destroy

    environment = {
      GCNV_CLEANUP_SCRIPT = self.input.script
      GCNV_PROJECT        = self.input.project
      GCNV_LOCATION       = self.input.location
      GCNV_STORAGE_POOL   = self.input.storage_pool
    }

    command = <<-EOF
      python3 "$GCNV_CLEANUP_SCRIPT" \
        --project "$GCNV_PROJECT" \
        --location "$GCNV_LOCATION" \
        --storage-pool "$GCNV_STORAGE_POOL"
    EOF
  }
}
