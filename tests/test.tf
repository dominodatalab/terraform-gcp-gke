terraform {
  required_version = ">= 0.12"

  required_providers {
    google = {
      version = ">=3.68"
    }
    google-beta = {
      version = ">=3.68"
    }
    random = {
      version = ">=3.1"
    }
  }

  backend "gcs" {
    bucket = "domino-terraform-default" # Should specify using cli -backend-config="bucket=domino-terraform-default"
    # Override with `terraform init -backend-config="prefix=/terraform/state/[YOUR/PATH]"`
    prefix = "terraform/state"
  }
}


variable "description" {
  type    = string
  default = "The Domino K8s Cluster"
}

variable "filestore_disabled" {
  type        = bool
  default     = false
  description = "Do not provision a Filestore instance (mostly to avoid GCP Filestore API issues)"
}

module "gke" {
  source = "./.."

  cluster_name           = terraform.workspace
  project                = "domino-eng-platform-dev"
  description            = var.description
  filestore_disabled     = var.filestore_disabled
  namespaces             = { platform = "domino-platform", compute = "domino-compute" }
  kubeconfig_output_path = "${path.cwd}/kubeconfig"
}
