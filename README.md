[![CircleCI](https://circleci.com/gh/dominodatalab/terraform-gcp-gke.svg?style=svg&circle-token=dfa46ce0cbeb40ea61fd9e96f7c6a05d5a87c3f7)](https://circleci.com/gh/dominodatalab/terraform-gcp-gke)
# Domino GKE Terraform

Terraform module which creates a Domino deployment inside of GCP's GKE.

## Usage

### Create a Domino development GKE cluster
```hcl
module "gke_cluster" {
  source  = "github.com/dominodatalab/terraform-gcp-gke"

  cluster = "cluster-name"
}
```

### Create a prod GKE cluster
```hcl
module "gke_cluster" {
  source   = "github.com/dominodatalab/terraform-gcp-gke"

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

# Terraform Docs
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 4.0, < 5.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 4.0, < 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.17.0 |
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | 4.17.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.1.2 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google-beta_google_artifact_registry_repository.domino](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_artifact_registry_repository) | resource |
| [google-beta_google_artifact_registry_repository_iam_member.gcr](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_artifact_registry_repository_iam_member) | resource |
| [google-beta_google_container_cluster.domino_cluster](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_container_cluster) | resource |
| [google_compute_firewall.iap_tcp_forwarding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.master_webhooks](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_global_address.static_ip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_network.vpc_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_node_pool.node_pools](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_dns_record_set.a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.caa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_filestore_instance.nfs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/filestore_instance) | resource |
| [google_kms_crypto_key.crypto_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key) | resource |
| [google_kms_key_ring.key_ring](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring) | resource |
| [google_project_iam_member.platform_roles](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.accounts](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.gcr](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_binding.platform_gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_storage_bucket.bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [random_uuid.id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [google_project.domino](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_ssh_ranges"></a> [allowed\_ssh\_ranges](#input\_allowed\_ssh\_ranges) | CIDR ranges allowed to SSH to nodes in the cluster. | `list(string)` | <pre>[<br>  "35.235.240.0/20"<br>]</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The Domino Cluster name and must be unique in the GCP Project. | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | GKE cluster description | `string` | `"The Domino K8s Cluster"` | no |
| <a name="input_enable_network_policy"></a> [enable\_network\_policy](#input\_enable\_network\_policy) | Enable network policy switch | `bool` | `true` | no |
| <a name="input_enable_pod_security_policy"></a> [enable\_pod\_security\_policy](#input\_enable\_pod\_security\_policy) | Enable pod security policy switch | `bool` | `true` | no |
| <a name="input_enable_vertical_pod_autoscaling"></a> [enable\_vertical\_pod\_autoscaling](#input\_enable\_vertical\_pod\_autoscaling) | Enable GKE vertical scaling | `bool` | `true` | no |
| <a name="input_filestore_capacity_gb"></a> [filestore\_capacity\_gb](#input\_filestore\_capacity\_gb) | Filestore Instance size (GB) for the cluster nfs shared storage | `number` | `1024` | no |
| <a name="input_filestore_disabled"></a> [filestore\_disabled](#input\_filestore\_disabled) | Do not provision a Filestore instance (mostly to avoid GCP Filestore API issues) | `bool` | `false` | no |
| <a name="input_gke_release_channel"></a> [gke\_release\_channel](#input\_gke\_release\_channel) | GKE K8s release channel for master | `string` | `"STABLE"` | no |
| <a name="input_google_dns_managed_zone"></a> [google\_dns\_managed\_zone](#input\_google\_dns\_managed\_zone) | Cloud DNS zone | <pre>object({<br>    enabled  = bool<br>    name     = string<br>    dns_name = string<br>  })</pre> | <pre>{<br>  "dns_name": "",<br>  "enabled": false,<br>  "name": ""<br>}</pre> | no |
| <a name="input_kubeconfig_output_path"></a> [kubeconfig\_output\_path](#input\_kubeconfig\_output\_path) | Specify where the cluster kubeconfig file should be generated. | `string` | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Desired Kubernetes version of the cluster | `string` | `""` | no |
| <a name="input_location"></a> [location](#input\_location) | The location (region or zone) of the cluster. A zone creates a single master. Specifying a region creates replicated masters accross all zones | `string` | `"us-west1-b"` | no |
| <a name="input_master_authorized_networks_config"></a> [master\_authorized\_networks\_config](#input\_master\_authorized\_networks\_config) | Configuration options for master authorized networks. Default is for debugging only, and should be removed for production. | <pre>list(object({<br>    cidr_block   = string<br>    display_name = string<br>  }))</pre> | <pre>[<br>  {<br>    "cidr_block": "0.0.0.0/0",<br>    "display_name": "global-access"<br>  }<br>]</pre> | no |
| <a name="input_master_firewall_ports"></a> [master\_firewall\_ports](#input\_master\_firewall\_ports) | Firewall ports to open from the master, e.g., webhooks | `list(string)` | `[]` | no |
| <a name="input_namespaces"></a> [namespaces](#input\_namespaces) | Namespace that are used for generating the service account bindings | `object({ platform = string, compute = string })` | n/a | yes |
| <a name="input_node_pool_overrides"></a> [node\_pool\_overrides](#input\_node\_pool\_overrides) | Param override for var.node\_pools | `map(map(map(string)))` | `{}` | no |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | GKE node pool params | <pre>map(object({<br>    min_count       = number<br>    max_count       = number<br>    max_pods        = number<br>    initial_count   = number<br>    preemptible     = bool<br>    disk_size_gb    = number<br>    image_type      = string<br>    instance_type   = string<br>    gpu_accelerator = string<br>    labels          = map(string)<br>    taints          = list(string)<br>    node_locations  = list(string)<br>  }))</pre> | <pre>{<br>  "compute": {<br>    "disk_size_gb": 400,<br>    "gpu_accelerator": "",<br>    "image_type": "COS_CONTAINERD",<br>    "initial_count": 1,<br>    "instance_type": "n2-highmem-8",<br>    "labels": {<br>      "dominodatalab.com/node-pool": "default"<br>    },<br>    "max_count": 10,<br>    "max_pods": 30,<br>    "min_count": 0,<br>    "node_locations": [],<br>    "preemptible": false,<br>    "taints": []<br>  },<br>  "gpu": {<br>    "disk_size_gb": 400,<br>    "gpu_accelerator": "nvidia-tesla-p100",<br>    "image_type": "COS_CONTAINERD",<br>    "initial_count": 0,<br>    "instance_type": "n1-highmem-8",<br>    "labels": {<br>      "dominodatalab.com/node-pool": "default-gpu",<br>      "nvidia.com/gpu": "true"<br>    },<br>    "max_count": 2,<br>    "max_pods": 30,<br>    "min_count": 0,<br>    "node_locations": [],<br>    "preemptible": false,<br>    "taints": [<br>      "nvidia.com/gpu=true:NoExecute"<br>    ]<br>  },<br>  "platform": {<br>    "disk_size_gb": 100,<br>    "gpu_accelerator": "",<br>    "image_type": "COS_CONTAINERD",<br>    "initial_count": 1,<br>    "instance_type": "n2-standard-8",<br>    "labels": {<br>      "dominodatalab.com/node-pool": "platform"<br>    },<br>    "max_count": 3,<br>    "max_pods": 60,<br>    "min_count": 1,<br>    "node_locations": [],<br>    "preemptible": false,<br>    "taints": []<br>  }<br>}</pre> | no |
| <a name="input_project"></a> [project](#input\_project) | GCP Project ID | `string` | `"domino-eng-platform-dev"` | no |
| <a name="input_static_ip_enabled"></a> [static\_ip\_enabled](#input\_static\_ip\_enabled) | Provision a static ip for use with managed zones/ingress | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the cloud storage bucket |
| <a name="output_cluster"></a> [cluster](#output\_cluster) | GKE cluster information |
| <a name="output_dns"></a> [dns](#output\_dns) | The external (public) DNS name for the Domino UI |
| <a name="output_domino_artifact_repository"></a> [domino\_artifact\_repository](#output\_domino\_artifact\_repository) | Domino Google artifact repository |
| <a name="output_google_filestore_instance"></a> [google\_filestore\_instance](#output\_google\_filestore\_instance) | Domino Google Cloud Filestore instance, name and ip\_address |
| <a name="output_project"></a> [project](#output\_project) | GCP project ID |
| <a name="output_region"></a> [region](#output\_region) | Region where the cluster is deployed derived from 'location' input variable |
| <a name="output_service_accounts"></a> [service\_accounts](#output\_service\_accounts) | GKE cluster Workload Identity namespace IAM service accounts |
| <a name="output_static_ip"></a> [static\_ip](#output\_static\_ip) | The external (public) static IPv4 for the Domino UI |
| <a name="output_uuid"></a> [uuid](#output\_uuid) | Cluster UUID |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
