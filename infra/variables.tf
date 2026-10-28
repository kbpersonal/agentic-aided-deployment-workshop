variable "name" {
  type        = string
  default     = "agentic-workshop"
  description = "Name of the resource group, AKS cluster, and PAM connector. Use a unique name in a shared Azure subscription."
}

variable "azure_subscription_id" {
  type = string
}

variable "azure_location" {
  type    = string
  default = "eastus2"
}

variable "node_vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "tailzero_image_tag" {
  type    = string
  default = "v0.2-114-g71177e3"
}

variable "tailscale_operator_version" {
  type    = string
  default = "1.104.1"
}

variable "github_repo" {
  type        = string
  description = "Your fork of the workshop repository, as owner/name."
}

variable "tailscale_client_id" {
  type        = string
  description = "Client ID of the federated identity Terraform signs in to Tailscale with."
}

variable "border0_token" {
  type        = string
  sensitive   = true
  description = "Tailscale PAM service-account token (Member role), from Settings → PAM → Service accounts."
}
