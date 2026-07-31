terraform {
  required_version = ">= 1.4"
  required_providers {
    google = {
      source = "hashicorp/google"
      # ONTAP-mode fields require google >= 7.28.0.
      version = ">= 7.28.0, < 8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.0, < 8.0"
    }
    netapp-ontap = {
      source  = "NetApp/netapp-ontap"
      version = "2.7.0"
    }
  }
}

provider "netapp-ontap" {
  connection_profiles = [
    {
      name = var.deploy_id
      google_netapp_unified_pool = {
        project_id   = var.project
        location     = local.gcnv_location
        storage_pool = var.deploy_id
      }
    }
  ]
}
