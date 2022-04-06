variable "description" {
  type    = string
  default = "The Domino K8s Cluster"
}

variable "filestore_disabled" {
  type        = bool
  default     = false
  description = "Do not provision a Filestore instance (mostly to avoid GCP Filestore API issues)"
}
