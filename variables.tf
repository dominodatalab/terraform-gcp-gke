variable "project" {
  type        = string
  default     = "domino-eng-platform-dev"
  description = "GCP Project ID"
}

variable "migration_permissions" {
  type        = bool
  default     = false
  description = "Add registry permissions to platform service account for migration purposes"
}

variable "tags" {
  type        = map(string)
  description = "Deployment tags."
  default     = {}
}

variable "location" {
  type        = string
  default     = "us-west1-b"
  description = "The location (region or zone) of the cluster. A zone creates a single master. Specifying a region creates replicated masters accross all zones"
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

variable "namespaces" {
  type        = object({ platform = string, compute = string })
  description = "Namespace that are used for generating the service account bindings"
}

variable "allowed_ssh_ranges" {
  type        = list(string)
  default     = ["35.235.240.0/20"]
  description = "CIDR ranges allowed to SSH to nodes in the cluster."
}

variable "storage" {
  description = <<EOF
  storage = {
    filestore = {
      enabled = Provision a Filestore instance (for production installs)
      capacity_gb = Filestore Instance size (GB) for the cluster NFS shared storage
    }
    nfs_instance = {
      enabled = Provision an instance as an NFS server (to avoid filestore churn during testing)
      capacity_gb = NFS instance disk size
    }
    gcs = {
      force_destroy_on_deletion = Toogle to allow recursive deletion of all objects in the bucket. if 'false' terraform will NOT be able to delete non-empty buckets.
    }
  EOF

  type = object({
    filestore = optional(object({
      enabled     = optional(bool, true)
      capacity_gb = optional(number, 1024)
    }), {}),
    nfs_instance = optional(object({
      enabled     = optional(bool, false)
      capacity_gb = optional(number, 100)
    }), {}),
    gcs = optional(object({
      force_destroy_on_deletion = optional(bool, false)
    }), {})
  })

  default = {}
}

variable "managed_dns" {
  description = <<EOF
  managed_dns = {
    enabled = Whether to create DNS records in the given zone
    name = Managed zone to modify
    dns_name = DNS record name to create
    service_prefixes = List of additional prefixes to the dns_name to create
  }
  EOF
  type = object({
    enabled          = optional(bool, false)
    name             = optional(string, "")
    dns_name         = optional(string, "")
    service_prefixes = optional(set(string), [])

  })
  default = {}
}

variable "kms" {
  description = <<EOF
  kms = {
    database_encryption_key_name = Use an existing KMS key for the Application-layer Secrets Encryption settings. (Optional)
  }
  EOF

  type = object({
    database_encryption_key_name = optional(string, null)
  })

  default = {}
}

variable "gke" {
  description = <<EOF
  gke = {
    k8s_version = Cluster k8s version
    release_channel = GKE release channel
    public_access = {
      enabled = Enable API public endpoint
      cidrs = List of CIDR ranges permitted for accessing the public endpoint
    }
    control_plane_ports =  Firewall ports to open from the master, e.g., webhooks
    advanced_datapath = Enable the ADVANCED_DATAPATH provider
    network_policies = Enable network policy switch. Cannot be enabled when enable_advanced_datapath is true
    vertical_pod_autoscaling = Enable GKE vertical scaling
    kubeconfig = {
      path = Specify where the cluster kubeconfig file should be generated.
    }
  }
  EOF

  type = object({
    k8s_version     = optional(string, "1.30"),
    release_channel = optional(string, "STABLE"),
    public_access = optional(object({
      enabled = optional(bool, false),
      cidrs   = optional(list(string), [])
    }), {}),
    control_plane_ports      = optional(list(string), [])
    advanced_datapath        = optional(bool, true),
    network_policies         = optional(bool, false),
    vertical_pod_autoscaling = optional(bool, true),
    kubeconfig = optional(object({
      path = optional(string, null)
    }), {})
  })

  default = {}

  validation {
    condition     = !var.gke.advanced_datapath || (var.gke.advanced_datapath && !var.gke.network_policies)
    error_message = "GKE network policies cannot be enabled with advanced datapath"
  }
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
        max_count       = optional(number, 5)
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
