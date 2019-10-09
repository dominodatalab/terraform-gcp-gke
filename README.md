# Domino GKE Terraform

## Usage

### Create a development GKE cluster containing autoscalers
```hcl
module "rancher" {
  source   = "github.com/cerebrotech/terraform-gcp-gke"

  cluster_name   = "cluster-name"
}
```


## Development

Please submit any feature enhancements, bug fixes, or ideas via pull requests or issues.

### Manual Deployment
First configure the environment
```
gcloud auth application-default login
export CLUSTER_NAME=[cluster-name]
terraform init -backend-config="prefix=/terraform/state/${CLUSTER_NAME}"
```

```
terraform apply -var cluster_name=${CLUSTER_NAME} -auto-approve
```

Be sure to cleanup the cluster after you are done working
```
terraform destroy -var cluster_name=${CLUSTER_NAME} -auto-approve
```
