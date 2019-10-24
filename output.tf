output "cluster" {
  value = {
    "client_certificate" : google_container_cluster.domino_cluster.master_auth[0].client_certificate,
    "client_key" : google_container_cluster.domino_cluster.master_auth[0].client_key,
    "cluster_ca_certificate" : google_container_cluster.domino_cluster.master_auth[0].cluster_ca_certificate,
    "cluster_ipv4_cidr" : google_container_cluster.domino_cluster.cluster_ipv4_cidr,
    "name" : google_container_cluster.domino_cluster.name
    "public_endpoint" : google_container_cluster.domino_cluster.private_cluster_config[0].public_endpoint
  }
  description = "GKE cluster information"
}

output "dns" {
  value       = google_dns_record_set.a.name
  description = "The external (public) DNS name for the Domino UI"
}

output "static_ip" {
  value       = google_compute_address.static_ip.address
  description = "The external (public) static IPv4 for the Domino UI"
}

output "google_filestore_instance" {
  value = {
    file_share = google_filestore_instance.nfs.file_shares[0].name,
    ip_address = google_filestore_instance.nfs.networks[0].ip_addresses[0],
  }
}

output "workload_identity_service_accounts" {
  value = map(
    "default", google_service_account.default.unique_id,
    "kube-system", google_service_account.kube_system.unique_id,
    "kube-public", google_service_account.kube_public.unique_id,
    "compute", google_service_account.compute.unique_id,
    "platform", google_service_account.platform.unique_id,
  )
  description = "GKE cluster Workload Identity namespace IAM service accounts"
}