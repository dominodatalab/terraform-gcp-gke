variable "action_type" {
  type        = string
  default     = "Delete"
  description = "The type of the action of the Lifecyle Rule. Supported values are : Delete and SetStorageClass. If empty defaults to Delete"
}

variable "action_storage_class" {
  type        = string
  default     = "REGIONAL"
  description = "The target storage class of objects under this rule. We default to Regional for now"
}
variable "cluster" {
  type        = string
  default     = null
  description = "The Domino Cluster name and must be unique in the GCP Project. Defaults to workspace name."
}

variable "project" {
  type        = string
  default     = "domino-eng-platform-dev"
  description = "GCP Project ID"
}

variable "build_nodes_max" {
  type    = number
  default = 2
}

variable "build_nodes_min" {
  type    = number
  default = 0
}

variable "build_nodes_preemptible" {
  type    = bool
  default = true
}

variable "build_nodes_ssd_gb" {
  type    = number
  default = 100
}

variable "build_node_type" {
  type    = string
  default = "n1-standard-8"
}

variable "description" {
  type    = string
  default = "The Domino K8s Cluster"
}

variable "filestore_capacity_gb" {
  type        = number
  default     = 1024
  description = "Filestore Instance size (GB) for the cluster nfs shared storage"
}

variable "google_dns_managed_zone" {
  type = object({
    name     = string
    dns_name = string
  })
  default = {
    name     = "domino-tech"
    dns_name = "domino-eng-platform-dev.domino.tech."
  }
  description = "Cloud DNS zone"
}

variable "compute_nodes_max" {
  type    = number
  default = 5
}

variable "compute_nodes_min" {
  type    = number
  default = 0
}

variable "compute_nodes_preemptible" {
  type    = bool
  default = true
}

variable "compute_nodes_ssd_gb" {
  type    = number
  default = 100
}

variable "compute_node_type" {
  type    = string
  default = "n1-standard-1"
}

variable "enable_pod_security_policy" {
  type    = bool
  default = false
}

variable "enable_network_policy" {
  type    = bool
  default = true
}

variable "enable_vertical_pod_autoscaling" {
  type        = bool
  default     = true
  description = "Enable GKE vertical scaling"
}

variable "gke_release_channel" {
  type        = string
  default     = "REGULAR"
  description = "GKE K8s release channel for master"
}

variable "location" {
  type        = string
  default     = "us-west1-a"
  description = "The location (region or zone) of the cluster. A zone creates a single master. Specifying a region creates replicated masters accross all zones"
}

variable "master_authorized_networks_config" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "12.245.82.18/32"
      display_name = "domino-hq-for-testing"
    },
    {
      cidr_block   = "52.206.158.130/32"
      display_name = "aviatrix-east"
    },
    {
      cidr_block   = "52.25.178.121/32"
      display_name = "aviatrix-west"
    },
    {
      cidr_block   = "52.56.39.158/32"
      display_name = "aviatrix-eu"
    },
    {
      cidr_block   = "13.126.91.85/32"
      display_name = "aviatrix-ap"
    }
  ]
  description = "Configuration options for master authorized networks. Default is for debugging only, and should be removed for production."
}

variable "platform_nodes_max" {
  type    = number
  default = 5
}

variable "platform_nodes_min" {
  type    = number
  default = 1
}

variable "platform_nodes_preemptible" {
  type    = bool
  default = true
}

variable "platform_nodes_ssd_gb" {
  type    = number
  default = 100
}

variable "platform_node_type" {
  type    = string
  default = "n1-standard-8"
}
