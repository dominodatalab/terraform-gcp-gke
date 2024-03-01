resource "google_kms_key_ring" "key_ring" {
  count    = var.kms.database_encryption_key_name == null ? 1 : 0
  name     = var.deploy_id
  location = local.region
}

resource "google_kms_crypto_key" "crypto_key" {
  count           = var.kms.database_encryption_key_name == null ? 1 : 0
  name            = var.deploy_id
  key_ring        = google_kms_key_ring.key_ring[0].id
  rotation_period = "86400s"
  purpose         = "ENCRYPT_DECRYPT"
}
