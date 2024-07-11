variable "deploy_id" {
  description = "deploy id"
  type        = string
}

variable "filestore_enabled" {
  type        = bool
  default     = false
  description = "Do not provision a Filestore instance (mostly to avoid GCP Filestore API issues)"
}

variable "nfs_instance_enabled" {
  type        = bool
  default     = false
  description = "Provision an NFS instance (for testing use only)"
}
