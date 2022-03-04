variable "project" {
  type        = string
  default     = "domino-eng-platform-dev"
  description = "GCP Project ID"
}

variable "cluster_name" {
  type        = string
  description = "The Domino Cluster name and must be unique in the GCP Project."
}

variable "kubeconfig_output_path" {
  type        = string
  description = "Specify where the cluster kubeconfig file should be generated."
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

variable "static_ip_enabled" {
  type        = bool
  default     = false
  description = "Provision a static ip for use with managed zones/ingress"
}

variable "google_dns_managed_zone" {
  type = object({
    enabled  = bool
    name     = string
    dns_name = string
  })
  default = {
    enabled  = false
    name     = ""
    dns_name = ""
  }
  description = "Cloud DNS zone"
}

variable "enable_pod_security_policy" {
  type    = bool
  default = true
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
  default     = "STABLE"
  description = "GKE K8s release channel for master"
}

variable "location" {
  type        = string
  default     = "us-west1-b"
  description = "The location (region or zone) of the cluster. A zone creates a single master. Specifying a region creates replicated masters accross all zones"
}

variable "master_firewall_ports" {
  type        = list(string)
  default     = []
  description = "Firewall ports to open from the master, e.g., webhooks"
}

variable "master_authorized_networks_config" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "global-access"
    }
  ]
  description = "Configuration options for master authorized networks. Default is for debugging only, and should be removed for production."
}

variable "node_pools" {
  type = map(object({
    min_count       = number
    max_count       = number
    max_pods        = number
    initial_count   = number
    preemptible     = bool
    disk_size_gb    = number
    image_type      = string
    instance_type   = string
    gpu_accelerator = string
    labels          = map(string)
    taints          = list(string)
    node_locations  = list(string)
  }))
  default = {
    compute = {
      min_count       = 0
      max_count       = 10
      initial_count   = 1
      max_pods        = 30
      preemptible     = false
      image_type      = "COS_CONTAINERD"
      disk_size_gb    = 400
      instance_type   = "n2-highmem-8"
      gpu_accelerator = ""
      labels = {
        "dominodatalab.com/node-pool" = "default"
      }
      taints         = []
      node_locations = []
    }
    gpu = {
      min_count       = 0
      max_count       = 2
      initial_count   = 0
      max_pods        = 30
      preemptible     = false
      image_type      = "COS_CONTAINERD"
      disk_size_gb    = 400
      instance_type   = "n1-highmem-8"
      gpu_accelerator = "nvidia-tesla-p100"
      labels = {
        "dominodatalab.com/node-pool" = "default-gpu"
        "nvidia.com/gpu"              = "true"
      }
      taints = [
        "nvidia.com/gpu=true:NoExecute"
      ]
      node_locations = []
    }
    platform = {
      min_count       = 1
      max_count       = 3
      initial_count   = 1
      max_pods        = 60
      preemptible     = false
      image_type      = "COS_CONTAINERD"
      disk_size_gb    = 100
      instance_type   = "n2-standard-8"
      gpu_accelerator = ""
      labels = {
        "dominodatalab.com/node-pool" = "platform"
      }
      taints         = []
      node_locations = []
    }
  }
}

variable "node_pool_overrides" {
  default = {}
}

variable "namespaces" {
  type        = object({ platform = string, compute = string })
  description = "Namespace that are used for generating the service account bindings"
}

variable "kubernetes_version" {
  type        = string
  description = "Desired Kubernetes version of the cluster"
}
