output "domino_ipv4_addr" {
  value       = google_compute_address.static_ip_address.address
  description = "The external (public) IPv4 address of the Domino UI."
}