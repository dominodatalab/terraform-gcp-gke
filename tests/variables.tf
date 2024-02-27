variable "deploy_id" {
  description = "deploy id"
  type        = string
}

variable "filestore_enabled" {
  type        = bool
  default     = false
  description = "Do not provision a Filestore instance (mostly to avoid GCP Filestore API issues)"
}
