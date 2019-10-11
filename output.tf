output "app_secrets_key" {
  value       = google_kms_crypto_key.crypto_key.self_link
  description = "Application-layer Secrets Encryption Key"
}

output "workload_identity_service_accounts" {
  value = map(
    "default", google_service_account.default.unique_id,
    "kube-system", google_service_account.kube_system.unique_id,
    "kube-public", google_service_account.kube_public.unique_id,
    "compute", google_service_account.compute.unique_id,
    "platform", google_service_account.platform.unique_id,
  )
  description = "GKE cluster workload identity namespace IAM service accounts"
}

output "domino_ipv4_addr" {
  value       = google_compute_address.static_ip_address.address
  description = "The external (public) IPv4 address of the Domino UI."
}