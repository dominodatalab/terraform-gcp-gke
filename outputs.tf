output "bucket_name" {
  value       = var.storage.gcs.create ? google_storage_bucket.bucket[0].name : null
  description = "Name of the cloud storage bucket (null when storage.gcs.create=false)"
}

output "cluster" {
  value = {
    "client_certificate"     = google_container_cluster.domino_cluster.master_auth[0].client_certificate,
    "client_key"             = google_container_cluster.domino_cluster.master_auth[0].client_key,
    "cluster_ca_certificate" = google_container_cluster.domino_cluster.master_auth[0].cluster_ca_certificate,
    "cluster_ipv4_cidr"      = google_container_cluster.domino_cluster.cluster_ipv4_cidr,
    "name"                   = google_container_cluster.domino_cluster.name,
    "public_endpoint"        = google_container_cluster.domino_cluster.private_cluster_config[0].public_endpoint,
    "pod_cidr"               = google_compute_subnetwork.default.ip_cidr_range
  }
  description = "GKE cluster information"
}

output "dns" {
  value       = var.managed_dns.enabled ? google_dns_record_set.a[0].name : ""
  description = "The external (public) DNS name for the Domino UI"
}

output "google_filestore_instance" {
  value = {
    file_share = var.storage.filestore.enabled ? google_filestore_instance.nfs[0].file_shares[0].name : "",
    ip_address = var.storage.filestore.enabled ? google_filestore_instance.nfs[0].networks[0].ip_addresses[0] : "",
  }
  description = "Domino Google Cloud Filestore instance, name and ip_address"
}

output "project" {
  value       = var.project
  description = "GCP project ID"
}

output "region" {
  value       = local.region
  description = "Region where the cluster is deployed derived from 'location' input variable"
}

output "static_ip" {
  value       = var.managed_dns.enabled ? google_compute_global_address.static_ip[0].address : ""
  description = "The external (public) static IPv4 for the Domino UI"
}

output "uuid" {
  value       = var.deploy_id
  description = "Cluster UUID"
}

output "service_accounts" {
  value       = { for sa in local.service_accounts : sa => google_service_account.accounts[sa] }
  description = "GKE cluster Workload Identity namespace IAM service accounts"
}

output "domino_artifact_repository" {
  value       = var.registry.create ? google_artifact_registry_repository.domino[0] : null
  description = "Domino Google artifact repository (null when registry.create=false)"
}

output "gcr_credential_refresher" {
  value = var.registry.create ? {
    service_account_email = google_service_account.gcr_credential_refresher[0].email
    registry_server       = "${google_artifact_registry_repository.domino[0].location}-docker.pkg.dev"
  } : null
  description = "Configuration for the GCR credential refresher Helm chart values (null when registry.create=false)"
}

output "nfs_instance_ip" {
  value       = var.storage.nfs_instance.enabled ? google_compute_instance.nfs[0].network_interface[0].network_ip : ""
  description = "NFS instance IP"
}
output "nfs_instance" {
  value = {
    nfs_path   = var.storage.nfs_instance.enabled ? local.nfs_path : "",
    ip_address = var.storage.nfs_instance.enabled ? google_compute_instance.nfs[0].network_interface[0].network_ip : "",
  }
  description = "Domino Google Cloud Filestore instance, name and ip_address"
}

output "gcnv" {
  value = {
    project_number        = var.storage.gcnv.enabled ? data.google_project.domino.number : null
    location              = var.storage.gcnv.enabled ? local.gcnv_location : null
    storage_pool_name     = var.storage.gcnv.enabled ? google_netapp_storage_pool.gcnv[0].name : null
    service_account_email = var.storage.gcnv.enabled ? google_service_account.gcnv[0].email : null
    client_cidr           = var.storage.gcnv.enabled ? google_compute_subnetwork.default.ip_cidr_range : null
    root_volume_name      = var.storage.gcnv.enabled ? local.gcnv_root_volume.name : null
    export_policy_name    = var.storage.gcnv.enabled ? local.gcnv_root_volume.nas.export_policy_name : null
  }
  description = "GCNV ONTAP-mode pool and Trident service account."
}

output "dns_zone" {
  value = {
    name         = var.managed_dns.zone_create ? google_dns_managed_zone.dataplane[0].name : null
    dns_name     = var.managed_dns.zone_create ? google_dns_managed_zone.dataplane[0].dns_name : null
    name_servers = var.managed_dns.zone_create ? google_dns_managed_zone.dataplane[0].name_servers : null
  }
  description = "Per-dataplane Cloud DNS zone (fields null when managed_dns.zone_create=false). name_servers is consumed by the control plane to create the NS delegation record."
}

output "external_dns_identity" {
  value = var.managed_dns.zone_create ? {
    service_account_email = google_service_account.external_dns[0].email
  } : null
  description = "Workload identity for external-dns (null when managed_dns.zone_create=false)"
}

output "cert_manager_identity" {
  value = var.managed_dns.zone_create ? {
    service_account_email = google_service_account.cert_manager[0].email
  } : null
  description = "Workload identity for cert-manager (null when managed_dns.zone_create=false)"
}
