variable "name" {
  type        = string
  default     = "agentic-workshop"
  description = "Prefix for the GKE cluster, network, and PAM connector. Use a unique prefix in a shared GCP project."
}

variable "gcp_project" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "developer_login" {
  type        = string
  description = "The developer's Tailscale login name, exactly as shown on the Users page."
}

variable "tailzero_image_tag" {
  type    = string
  default = "v0.2-114-g71177e3"
}

variable "tailscale_operator_version" {
  type    = string
  default = "1.104.1"
}
