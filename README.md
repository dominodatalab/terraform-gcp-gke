[![CircleCI](https://circleci.com/gh/cerebrotech/terraform-gcp-gke.svg?style=svg&circle-token=dfa46ce0cbeb40ea61fd9e96f7c6a05d5a87c3f7)](https://circleci.com/gh/cerebrotech/terraform-gcp-gke)
# Domino GKE Terraform

Terraform module which creates a Domino deployment inside of GCP's GKE.

## Usage

### Create a Domino development GKE cluster
```hcl
module "gke_cluster" {
  source  = "github.com/cerebrotech/terraform-gcp-gke"

  cluster = "cluster-name"
}
```

### Create a prod GKE cluster
```hcl
module "gke_cluster" {
  source   = "github.com/cerebrotech/terraform-gcp-gke"

  cluster  = "cluster-name"
  project  = "gcp-project"
  location = "us-west1"

  # Some more variables may need to be configured to meet specific needs
}
```

## Manual Deployment
1. Install [gcloud](https://cloud.google.com/sdk/docs/quickstarts) and configure the [Terraform workspace](https://www.terraform.io/docs/state/workspaces.html)
    ```
    gcloud auth application-default login
    terraform init
    terraform workspace new [your-cluster-name]
    ```

1. With the environment setup, you can now apply the terraform module
    ```
    terraform apply -auto-approve
    ```

1. Be sure to cleanup the cluster after you are done working
    ```
    terraform destroy -auto-approve
    ```

## IAM Permissions
The following project [IAM permissions](https://console.cloud.google.com/iam-admin/iam) must be granted to the provisioning user/service:
- Cloud KMS Admin
- Compute Admin
- Compute Instance Admin (v1)
- Compute Network Admin
- Kubernetes Engine Admin
- DNS Administrator
- Cloud Filestore Editor
- Security Admin
- Service Account Admin
- Service Account User
- Storage Admin

It may be possible to lower the "admin" privilage levels to a "creator" level if provisioning cleanup is not required. However, the permissions level for "creator-only" has not been tested. It is assume that a cluster creator can also cleanup (i.e. destroy) the cluster.

## Development

Please submit any feature enhancements, bug fixes, or ideas via pull requests or issues.
