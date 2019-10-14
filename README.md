# Domino GKE Terraform

## Usage

### Create a development GKE cluster
```hcl
module "rancher" {
  source   = "github.com/cerebrotech/terraform-gcp-gke"

  cluster_name   = "cluster-name"
}
```

### Create a prod GKE cluster
```hcl
module "rancher" {
  source   = "github.com/cerebrotech/terraform-gcp-gke"

  cluster_name   = "cluster-name"
  project = "gcp-project"
  location = "us-west1"
  
  # Some more variables may need to be configured to meet specific needs
}
```

## IAM Permissions
The following project [IAM permissions](https://console.cloud.google.com/iam-admin/iam) must be granted to the provisioning user/service:
- Cloud KMS Admin
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

### Manual Deployment
1. Install [gcloud](https://cloud.google.com/sdk/docs/quickstarts) and configure the environment
    ```
    gcloud auth application-default login
    export TF_VAR_cluster_name=[cluster-name]
    terraform init -backend-config="prefix=/terraform/state/${TF_VAR_cluster_name}"
    ```
    
    1. If recreating a cluster: GCP [Key Rings](https://cloud.google.com/kms/docs/creating-keys) persist 
    indefinitely so the existing key ring must be added to terraform:
        ```
        terraform import google_kms_key_ring.key_ring projects/domino-eng-platform-dev/locations/us-west1/keyRings/${TF_VAR_cluster_name}
        ```

1. With the environment setup, you can now apply the terraform module
    ```
    terraform apply -auto-approve
    ```

1. Be sure to cleanup the cluster after you are done working
    ```
    terraform destroy -auto-approve
    ```
