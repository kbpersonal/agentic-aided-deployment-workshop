variable "gcp_project" {
  type = string
}

variable "gcp_region" {
  type    = string
  default = "us-central1"
}

variable "tailnet" {
  type        = string
  description = "Tailnet ID from Admin console > Settings > General."
}

variable "github_repo" {
  type        = string
  description = "owner/name of the application repository."
}

variable "developer" {
  type        = string
  description = "Short name for the developer; the namespace is dev-<developer>."
}

variable "developer_login" {
  type        = string
  description = "The developer's Tailscale login name, exactly as shown on the Users page."
}

variable "tailzero_image_tag" {
  type    = string
  default = "v0.2-114-g71177e3"
}

variable "policy_repo" {
  type        = string
  description = "owner/name of the private tailnet policy repository."
}

variable "github_repo_subject_prefix" {
  type        = string
  description = "GitHub OIDC sub prefix for the app repository: gh api repos/OWNER/REPO/actions/oidc/customization/sub -q .sub_claim_prefix"
}

variable "policy_repo_subject_prefix" {
  type        = string
  description = "GitHub OIDC sub prefix for the policy repository, read the same way."
}

variable "tailscale_operator_version" {
  type    = string
  default = "1.104.1"
}
