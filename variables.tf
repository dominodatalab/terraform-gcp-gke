variable "cluster_name" {
  type = string
}

variable "project" {
  type    = string
  default = "domino-eng-platform-dev"
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

variable "build_node_type" {
  type    = string
  default = "n1-standard-1"
}

variable "description" {
  type    = string
  default = "The Domino K8s Cluster"
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

variable "compute_node_type" {
  type    = string
  default = "n1-standard-1"
}

variable "location" {
  type        = string
  default     = "us-west1-a"
  description = "The location (region or zone) of the cluster. A zone creates a single master. Specifying a region creates replicated masters accross all zones"
}

variable "master_authorized_networks_config" {
  type = object({
    cidr_block   = string
    display_name = string
  })
  default = {
    cidr_block   = "12.245.82.18/32"
    display_name = "domino-hq-for-testing"
  }
  description = "Configuration options for master authorized networks. Default is for debugging only, and should be removed for production."
}

variable "platform_nodes_max" {
  type    = number
  default = 4
}

variable "platform_nodes_min" {
  type    = number
  default = 1
}

variable "platform_nodes_preemptible" {
  type    = bool
  default = true
}

variable "platform_node_type" {
  type    = string
  default = "n1-standard-8"
}

variable "enable_vertical_pod_autoscaling" {
  type        = bool
  default     = true
  description = "Enable GKE vertical scaling"
}