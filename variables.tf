variable "project" {
  type        = string
  default     = "domino-eng-platform-dev"
  description = "GCP Project ID"
}

variable "deploy_id" {
  type        = string
  description = "Domino Deployment ID."
  nullable    = false

  validation {
    condition     = length(var.deploy_id) >= 3 && length(var.deploy_id) <= 20 && can(regex("^([a-z][-a-z0-9]*[a-z0-9])$", var.deploy_id))
    error_message = <<EOT
      Variable deploy_id must:
      1. Length must be between 3 and 20 characters.
      2. Start with a letter.
      3. End with a letter or digit.
      4. May contain lowercase Alphanumeric characters and hyphens.
    EOT
  }
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
  description = "GKE cluster description"
  type        = string
  default     = "The Domino K8s Cluster"
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
  description = "Enable pod security policy switch"
  type        = bool
  default     = true
}

variable "enable_network_policy" {
  description = "Enable network policy switch"
  type        = bool
  default     = true
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
  description = "GKE node pool params"
  type = object(
    {
      compute = object({
        min_count       = optional(number, 0)
        max_count       = optional(number, 10)
        initial_count   = optional(number, 1)
        max_pods        = optional(number, 30)
        preemptible     = optional(bool, false)
        disk_size_gb    = optional(number, 400)
        image_type      = optional(string, "COS_CONTAINERD")
        instance_type   = optional(string, "n2-highmem-8")
        gpu_accelerator = optional(string, "")
        labels = optional(map(string), {
          "dominodatalab.com/node-pool" = "default"
        })
        taints         = optional(list(string), [])
        node_locations = optional(list(string), [])
      }),
      platform = object({
        min_count       = optional(number, 1)
        max_count       = optional(number, 3)
        initial_count   = optional(number, 1)
        max_pods        = optional(number, 60)
        preemptible     = optional(bool, false)
        disk_size_gb    = optional(number, 100)
        image_type      = optional(string, "COS_CONTAINERD")
        instance_type   = optional(string, "n2-standard-8")
        gpu_accelerator = optional(string, "")
        labels = optional(map(string), {
          "dominodatalab.com/node-pool" = "platform"
        })
        taints         = optional(list(string), [])
        node_locations = optional(list(string), [])
      }),
      gpu = object({
        min_count       = optional(number, 0)
        max_count       = optional(number, 2)
        initial_count   = optional(number, 0)
        max_pods        = optional(number, 30)
        preemptible     = optional(bool, false)
        disk_size_gb    = optional(number, 400)
        image_type      = optional(string, "COS_CONTAINERD")
        instance_type   = optional(string, "n1-highmem-8")
        gpu_accelerator = optional(string, "nvidia-tesla-p100")
        labels = optional(map(string), {
          "dominodatalab.com/node-pool" = "default-gpu"
          "nvidia.com/gpu"              = "true"
        })
        taints = optional(list(string), [
          "nvidia.com/gpu=true:NoExecute"
        ])
        node_locations = optional(list(string), [])
      })
  })
  default = {
    compute  = {}
    platform = {}
    gpu      = {}
  }
}

variable "additional_node_pools" {
  description = "additional node pool definitions"
  type = map(object({
    min_count       = optional(number, 0)
    max_count       = optional(number, 10)
    initial_count   = optional(number, 1)
    max_pods        = optional(number, 30)
    preemptible     = optional(bool, false)
    disk_size_gb    = optional(number, 400)
    image_type      = optional(string, "COS_CONTAINERD")
    instance_type   = optional(string, "n2-standard-8")
    gpu_accelerator = optional(string, "")
    labels          = optional(map(string), {})
    taints          = optional(list(string), [])
    node_locations  = optional(list(string), [])
  }))
  default = {}
}

variable "namespaces" {
  type        = object({ platform = string, compute = string })
  description = "Namespace that are used for generating the service account bindings"
}

variable "kubernetes_version" {
  type        = string
  description = "Desired Kubernetes version of the cluster"
  default     = ""
}
