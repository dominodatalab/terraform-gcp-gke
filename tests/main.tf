terraform {
  required_version = ">= 1.0"

  backend "gcs" {
    bucket = "domino-terraform-default" # Should specify using cli -backend-config="bucket=domino-terraform-default"
    # Override with `terraform init -backend-config="prefix=/terraform/state/[YOUR/PATH]"`
    prefix = "terraform/state"
  }
}
