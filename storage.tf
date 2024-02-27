data "google_storage_project_service_account" "gcs_account" {
}

resource "google_kms_crypto_key_iam_binding" "binding" {
  count         = var.kms.database_encryption_key_name == null ? 1 : 0
  crypto_key_id = google_kms_crypto_key.crypto_key[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_storage_bucket_iam_binding" "bucket" {
  bucket = google_storage_bucket.bucket.name
  role   = "roles/storage.admin"
  members = [
    "serviceAccount:${google_service_account.accounts["platform"].email}"
  ]
}

resource "google_storage_bucket" "bucket" {
  name     = "dominodatalab-${var.deploy_id}"
  location = local.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  encryption {
    default_kms_key_name = var.kms.database_encryption_key_name == null ? google_kms_crypto_key.crypto_key[0].id : var.kms.database_encryption_key_name
  }

  versioning {
    enabled = true
  }

  force_destroy = var.storage.gcs.force_destroy_on_deletion

  depends_on = [google_kms_crypto_key_iam_binding.binding]
}

resource "google_filestore_instance" "nfs" {
  count    = var.storage.filestore.enabled ? 1 : 0
  provider = google

  name     = var.deploy_id
  project  = var.project
  tier     = "STANDARD"
  location = local.zone

  file_shares {
    capacity_gb = var.storage.filestore.capacity_gb
    name        = "share1"
  }

  networks {
    network = google_compute_network.vpc_network.name
    modes   = ["MODE_IPV4"]
  }
}
