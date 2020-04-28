variable "cluster" {
  type        = string
  default     = null
  description = "The Domino Cluster name and must be unique in the GCP Project. Defaults to workspace name."
}

variable "kubeconfig_output_path" {
  type        = string
  default     = ""
  description = "Specify where the cluster kubeconfig file should be generated. Defaults to current working directory."
}

variable "project" {
  type        = string
  default     = "domino-eng-platform-dev"
  description = "GCP Project ID"
}

variable "allowed_ssh_ranges" {
  type        = list(string)
  default     = ["35.235.240.0/20"]
  description = "CIDR ranges allowed to SSH to nodes in the cluster."
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

variable "filestore_disabled" {
  type        = bool
  default     = false
  description = "Do not provision a Filestore instance (mostly to avoid GCP Filestore API issues)"
}

variable "google_dns_managed_zone" {
  type = object({
    name     = string
    dns_name = string
  })
  default = {
    name     = "eng-platform-dev"
    dns_name = "eng-platform-dev.domino.tech."
  }
  description = "Cloud DNS zone"
}

variable "compute_nodes_max" {
  type    = number
  default = 10
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
  default = 400
}

variable "compute_node_type" {
  type    = string
  default = "n1-highmem-8"
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

variable "gpu_nodes_accelerator" {
  type    = string
  default = "nvidia-tesla-p100"
}

variable "gpu_nodes_max" {
  type    = number
  default = 2
}

variable "gpu_nodes_min" {
  type    = number
  default = 0
}

variable "gpu_nodes_preemptible" {
  type    = bool
  default = true
}

variable "gpu_node_type" {
  type    = string
  default = "n1-highmem-8"
}

variable "gpu_nodes_ssd_gb" {
  type    = number
  default = 400
}

variable "location" {
  type        = string
  default     = "us-west1-b"
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
      display_name = "domino-hq"
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

variable "allow_local_ip_access" {
  type        = bool
  default     = false
  description = "Adds firewall rule to allow local access to Kubernetes cluster. This is required when executing terraform outside the master authorized networks."
}

variable "platform_nodes_max" {
  type    = number
  default = 3
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

variable "platform_namespace" {
  type        = string
  description = "Platform namespace that is used for generating the service account binding for docker-registry"
  default     = "domino-platform"
}
