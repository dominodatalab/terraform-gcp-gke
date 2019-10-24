output "app_secrets_key" {
  value       = google_kms_crypto_key.crypto_key.self_link
  description = "Application-layer Secrets Encryption Key"
}

output "dns" {
  value       = google_dns_record_set.a.name
  description = "The external (public) DNS name for the Domino UI"
}

output "static_ip" {
  value       = google_compute_address.static_ip
  description = "The external (public) static IPv4 for the Domino UI"
}

output "google_container_cluster" {
  value = google_container_cluster.domino_cluster
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