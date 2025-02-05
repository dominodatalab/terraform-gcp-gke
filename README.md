# Domino GKE Terraform

Terraform module which creates a Domino deployment inside of GCP's GKE.

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/dominodatalab/terraform-gcp-gke/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/dominodatalab/terraform-gcp-gke/tree/main)

:warning: Important: If you have existing infrastructure created with a version of this module < `v3.0.0` you will need to update the input variable structure.

The following configuration has been removed:
* `description`
* `static_ip_enabled`

The following configuration has been moved:

| Original variable                   | New variable                            | Notes                                                       |
|-------------------------------------|-----------------------------------------|-------------------------------------------------------------|
| `filestore_disabled`                | `storage.filestore.enabled`             |                                                             |
| `filestore_capacity_gb`             | `storage.filestore.capacity_gb`         |                                                             |
| `gcs_force_destroy`                 | `storage.gcs.force_destroy_on_deletion` |                                                             |
| `kubeconfig_output_path`            | `gke.kubeconfig.path`                   |                                                             |
| `enable_network_policy`             | `gke.network_policies`                  |                                                             |
| `kubernetes_version`                | `gke.k8s_version`                       |                                                             |
| `gke_release_channel`               | `gke.release_channel`                   |                                                             |
| `enable_vertical_pod_autoscaling`   | `gke.vertical_pod_autoscaling`          |                                                             |
| `master_firewall_ports`             | `gke.control_plane_ports`               |                                                             |
| `master_authorized_networks_config` | `gke.public_access.cidrs`               | `gke.public_access.enabled` must also be set to take effect |
| `google_dns_managed_zone`           | `managed_dns`                           |                                                             |
| `database_encryption_key_name`      | `kms.database_encryption_key_name`      |                                                             |

A new, enabled-by-default variable to control [GKE dataplane v2](https://cloud.google.com/kubernetes-engine/docs/how-to/dataplane-v2) has been introduced: `gke.advanced_datapath`. For existing infrastructure, make sure to set it to `false` otherwise it will **recreate your cluster**.

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 5.0, < 6.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 5.0, < 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 5.0, < 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_artifact_registry_repository.domino](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository) | resource |
| [google_artifact_registry_repository_iam_member.gcr](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_artifact_registry_repository_iam_member.platform](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_compute_disk.nfs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_disk) | resource |
| [google_compute_firewall.iap_tcp_forwarding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.master_webhooks](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_firewall.nfs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall) | resource |
| [google_compute_global_address.static_ip](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address) | resource |
| [google_compute_instance.nfs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance) | resource |
| [google_compute_network.vpc_network](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network) | resource |
| [google_compute_router.router](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router) | resource |
| [google_compute_router_nat.nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat) | resource |
| [google_compute_subnetwork.default](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork) | resource |
| [google_container_cluster.domino_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster) | resource |
| [google_container_node_pool.node_pools](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool) | resource |
| [google_dns_record_set.a](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.a_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.caa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_dns_record_set.caa_services](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set) | resource |
| [google_filestore_instance.nfs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/filestore_instance) | resource |
| [google_kms_crypto_key.crypto_key](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key) | resource |
| [google_kms_crypto_key_iam_binding.binding](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key_iam_binding) | resource |
| [google_kms_key_ring.key_ring](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring) | resource |
| [google_project_iam_member.platform_roles](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_iam_member.service_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_service_account.accounts](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account) | resource |
| [google_service_account_iam_binding.gcr](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_service_account_iam_binding.platform_gcs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam_binding) | resource |
| [google_storage_bucket.bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [google_storage_bucket_iam_binding.bucket](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket_iam_binding) | resource |
| [google_project.domino](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |
| [google_storage_project_service_account.gcs_account](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_node_pools"></a> [additional\_node\_pools](#input\_additional\_node\_pools) | additional node pool definitions | <pre>map(object({<br>    min_count       = optional(number, 0)<br>    max_count       = optional(number, 10)<br>    initial_count   = optional(number, 1)<br>    max_pods        = optional(number, 30)<br>    preemptible     = optional(bool, false)<br>    disk_size_gb    = optional(number, 400)<br>    image_type      = optional(string, "COS_CONTAINERD")<br>    instance_type   = optional(string, "n2-standard-8")<br>    gpu_accelerator = optional(string, "")<br>    labels          = optional(map(string), {})<br>    taints          = optional(list(string), [])<br>    node_locations  = optional(list(string), [])<br>  }))</pre> | `{}` | no |
| <a name="input_allowed_ssh_ranges"></a> [allowed\_ssh\_ranges](#input\_allowed\_ssh\_ranges) | CIDR ranges allowed to SSH to nodes in the cluster. | `list(string)` | <pre>[<br>  "35.235.240.0/20"<br>]</pre> | no |
| <a name="input_deploy_id"></a> [deploy\_id](#input\_deploy\_id) | Domino Deployment ID. | `string` | n/a | yes |
| <a name="input_gke"></a> [gke](#input\_gke) | gke = {<br>    k8s\_version = Cluster k8s version<br>    release\_channel = GKE release channel<br>    public\_access = {<br>      enabled = Enable API public endpoint<br>      cidrs = List of CIDR ranges permitted for accessing the public endpoint<br>    }<br>    control\_plane\_ports =  Firewall ports to open from the master, e.g., webhooks<br>    advanced\_datapath = Enable the ADVANCED\_DATAPATH provider<br>    network\_policies = Enable network policy switch. Cannot be enabled when enable\_advanced\_datapath is true<br>    vertical\_pod\_autoscaling = Enable GKE vertical scaling<br>    kubeconfig = {<br>      path = Specify where the cluster kubeconfig file should be generated.<br>    }<br>  } | <pre>object({<br>    k8s_version     = optional(string, "1.31"),<br>    release_channel = optional(string, "STABLE"),<br>    public_access = optional(object({<br>      enabled = optional(bool, false),<br>      cidrs   = optional(list(string), [])<br>    }), {}),<br>    control_plane_ports      = optional(list(string), [])<br>    advanced_datapath        = optional(bool, true),<br>    network_policies         = optional(bool, false),<br>    vertical_pod_autoscaling = optional(bool, true),<br>    kubeconfig = optional(object({<br>      path = optional(string, null)<br>    }), {})<br>  })</pre> | `{}` | no |
| <a name="input_kms"></a> [kms](#input\_kms) | kms = {<br>    database\_encryption\_key\_name = Use an existing KMS key for the Application-layer Secrets Encryption settings. (Optional)<br>  } | <pre>object({<br>    database_encryption_key_name = optional(string, null)<br>  })</pre> | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | The location (region or zone) of the cluster. A zone creates a single master. Specifying a region creates replicated masters accross all zones | `string` | `"us-west1-b"` | no |
| <a name="input_managed_dns"></a> [managed\_dns](#input\_managed\_dns) | managed\_dns = {<br>    enabled = Whether to create DNS records in the given zone<br>    name = Managed zone to modify<br>    dns\_name = DNS record name to create<br>    service\_prefixes = List of additional prefixes to the dns\_name to create<br>  } | <pre>object({<br>    enabled          = optional(bool, false)<br>    name             = optional(string, "")<br>    dns_name         = optional(string, "")<br>    service_prefixes = optional(set(string), [])<br><br>  })</pre> | `{}` | no |
| <a name="input_migration_permissions"></a> [migration\_permissions](#input\_migration\_permissions) | Add registry permissions to platform service account for migration purposes | `bool` | `false` | no |
| <a name="input_namespaces"></a> [namespaces](#input\_namespaces) | Namespace that are used for generating the service account bindings | `object({ platform = string, compute = string })` | n/a | yes |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | GKE node pool params | <pre>object(<br>    {<br>      compute = object({<br>        min_count       = optional(number, 0)<br>        max_count       = optional(number, 10)<br>        initial_count   = optional(number, 1)<br>        max_pods        = optional(number, 30)<br>        preemptible     = optional(bool, false)<br>        disk_size_gb    = optional(number, 400)<br>        image_type      = optional(string, "COS_CONTAINERD")<br>        instance_type   = optional(string, "n2-highmem-8")<br>        gpu_accelerator = optional(string, "")<br>        labels = optional(map(string), {<br>          "dominodatalab.com/node-pool" = "default"<br>        })<br>        taints         = optional(list(string), [])<br>        node_locations = optional(list(string), [])<br>      }),<br>      platform = object({<br>        min_count       = optional(number, 1)<br>        max_count       = optional(number, 5)<br>        initial_count   = optional(number, 1)<br>        max_pods        = optional(number, 60)<br>        preemptible     = optional(bool, false)<br>        disk_size_gb    = optional(number, 100)<br>        image_type      = optional(string, "COS_CONTAINERD")<br>        instance_type   = optional(string, "n2-standard-8")<br>        gpu_accelerator = optional(string, "")<br>        labels = optional(map(string), {<br>          "dominodatalab.com/node-pool" = "platform"<br>        })<br>        taints         = optional(list(string), [])<br>        node_locations = optional(list(string), [])<br>      }),<br>      gpu = object({<br>        min_count       = optional(number, 0)<br>        max_count       = optional(number, 2)<br>        initial_count   = optional(number, 0)<br>        max_pods        = optional(number, 30)<br>        preemptible     = optional(bool, false)<br>        disk_size_gb    = optional(number, 400)<br>        image_type      = optional(string, "COS_CONTAINERD")<br>        instance_type   = optional(string, "n1-highmem-8")<br>        gpu_accelerator = optional(string, "nvidia-tesla-p100")<br>        labels = optional(map(string), {<br>          "dominodatalab.com/node-pool" = "default-gpu"<br>          "nvidia.com/gpu"              = "true"<br>        })<br>        taints = optional(list(string), [<br>          "nvidia.com/gpu=true:NoExecute"<br>        ])<br>        node_locations = optional(list(string), [])<br>      })<br>  })</pre> | <pre>{<br>  "compute": {},<br>  "gpu": {},<br>  "platform": {}<br>}</pre> | no |
| <a name="input_project"></a> [project](#input\_project) | GCP Project ID | `string` | `"domino-eng-platform-dev"` | no |
| <a name="input_storage"></a> [storage](#input\_storage) | storage = {<br>    filestore = {<br>      enabled = Provision a Filestore instance (for production installs)<br>      capacity\_gb = Filestore Instance size (GB) for the cluster NFS shared storage<br>    }<br>    nfs\_instance = {<br>      enabled = Provision an instance as an NFS server (to avoid filestore churn during testing)<br>      capacity\_gb = NFS instance disk size<br>    }<br>    gcs = {<br>      force\_destroy\_on\_deletion = Toogle to allow recursive deletion of all objects in the bucket. if 'false' terraform will NOT be able to delete non-empty buckets.<br>    } | <pre>object({<br>    filestore = optional(object({<br>      enabled     = optional(bool, true)<br>      capacity_gb = optional(number, 1024)<br>    }), {}),<br>    nfs_instance = optional(object({<br>      enabled     = optional(bool, false)<br>      capacity_gb = optional(number, 100)<br>    }), {}),<br>    gcs = optional(object({<br>      force_destroy_on_deletion = optional(bool, false)<br>    }), {})<br>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Deployment tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the cloud storage bucket |
| <a name="output_cluster"></a> [cluster](#output\_cluster) | GKE cluster information |
| <a name="output_dns"></a> [dns](#output\_dns) | The external (public) DNS name for the Domino UI |
| <a name="output_domino_artifact_repository"></a> [domino\_artifact\_repository](#output\_domino\_artifact\_repository) | Domino Google artifact repository |
| <a name="output_google_filestore_instance"></a> [google\_filestore\_instance](#output\_google\_filestore\_instance) | Domino Google Cloud Filestore instance, name and ip\_address |
| <a name="output_nfs_instance"></a> [nfs\_instance](#output\_nfs\_instance) | Domino Google Cloud Filestore instance, name and ip\_address |
| <a name="output_nfs_instance_ip"></a> [nfs\_instance\_ip](#output\_nfs\_instance\_ip) | NFS instance IP |
| <a name="output_project"></a> [project](#output\_project) | GCP project ID |
| <a name="output_region"></a> [region](#output\_region) | Region where the cluster is deployed derived from 'location' input variable |
| <a name="output_service_accounts"></a> [service\_accounts](#output\_service\_accounts) | GKE cluster Workload Identity namespace IAM service accounts |
| <a name="output_static_ip"></a> [static\_ip](#output\_static\_ip) | The external (public) static IPv4 for the Domino UI |
| <a name="output_uuid"></a> [uuid](#output\_uuid) | Cluster UUID |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
