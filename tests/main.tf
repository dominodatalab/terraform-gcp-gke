terraform {
  required_version = ">= 0.12"

  backend "gcs" {
    bucket = "domino-terraform-default" # Should specify using cli -backend-config="bucket=domino-terraform-default"
    # Override with `terraform init -backend-config="prefix=/terraform/state/[YOUR/PATH]"`
    prefix = "terraform/state"
  }
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
