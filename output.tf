output "cluster" {
  value = map(
    "client_certificate", google_container_cluster.domino_cluster.master_auth[0].client_certificate,
    "client_key", google_container_cluster.domino_cluster.master_auth[0].client_key,
    "cluster_ca_certificate", google_container_cluster.domino_cluster.master_auth[0].cluster_ca_certificate,
    "cluster_ipv4_cidr", google_container_cluster.domino_cluster.cluster_ipv4_cidr,
    "name", google_container_cluster.domino_cluster.name,
    "public_endpoint", google_container_cluster.domino_cluster.private_cluster_config[0].public_endpoint,
    "pod_cidr", google_compute_subnetwork.default.ip_cidr_range
  )
  description = "GKE cluster information"
}

output "dns" {
  value       = google_dns_record_set.a.name
  description = "The external (public) DNS name for the Domino UI"
}

output "google_filestore_instance" {
  value = {
    file_share = ! var.filestore_disabled ? google_filestore_instance.nfs[0].file_shares[0].name : "",
    ip_address = ! var.filestore_disabled ? google_filestore_instance.nfs[0].networks[0].ip_addresses[0] : "",
  }
}

output "static_ip" {
  value       = google_compute_global_address.static_ip.address
  description = "The external (public) static IPv4 for the Domino UI"
}

output "uuid" {
  value       = local.uuid
  description = "Cluster UUID"
}

output "workload_identity_service_accounts" {
  value = map(
    "default", google_service_account.default.email,
    "kube-system", google_service_account.kube_system.email,
    "kube-public", google_service_account.kube_public.email,
    "compute", google_service_account.compute.email,
    "platform", google_service_account.platform.email,
  )
  description = "GKE cluster Workload Identity namespace IAM service accounts"
}
