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


## Development

Please submit any feature enhancements, bug fixes, or ideas via pull requests or issues.

### Manual Deployment
1. Install [gcloud](https://cloud.google.com/sdk/docs/quickstarts) and configure the environment
    ```
    gcloud auth application-default login
    export TF_VAR_cluster_name=[cluster-name]
    terraform init -backend-config="prefix=/terraform/state/${TF_VAR_cluster_name}"
    ```

1. With the environment setup, you can now apply the terraform module
    ```
    terraform apply -auto-approve
    ```

1. Be sure to cleanup the cluster after you are done working
    ```
    terraform destroy -auto-approve
    ```
