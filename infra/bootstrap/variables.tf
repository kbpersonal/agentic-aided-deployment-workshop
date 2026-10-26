variable "github_repo" {
  type        = string
  description = "Your fork of the workshop repository, as owner/name."
}

variable "tailscale_api_key" {
  type        = string
  sensitive   = true
  description = "Tailscale API access token, from Settings → Keys."
}
