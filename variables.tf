variable "cluster_name" {
  type = string
}

variable "project" {
  type = string
  default = "domino-eng-platform-dev"
}

variable "build_nodes_max" {
  type = number
  default = 2
}

variable "build_nodes_min" {
  type = number
  default = 0
}

variable "build_nodes_preemptible" {
  type = bool
  default = true
}

variable "build_node_type" {
  type = string
  default = "n1-standard-1"
}

variable "compute_nodes_max" {
  type = number
  default = 5
}

variable "compute_nodes_min" {
  type = number
  default = 0
}

variable "compute_nodes_preemptible" {
  type = bool
  default = true
}

variable "compute_node_type" {
  type = string
  default = "n1-standard-1"
}

variable "location" {
  type = string
  default = "us-west1-a"
  description = "The location (region or zone) of the cluster. A zone creates a single master. Specifying a region creates replicated masters accross all zones"
}

variable "platform_nodes_max" {
  type = number
  default = 3
}

variable "platform_nodes_min" {
  type = number
  default = 1
}

variable "platform_nodes_preemptible" {
  type = bool
  default = true
}

variable "platform_node_type" {
  type = string
  default = "n1-standard-8"
}