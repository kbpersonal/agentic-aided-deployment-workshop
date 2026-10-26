terraform {
  required_version = ">= 1.9"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }
  }
}

provider "tailscale" {}

locals {
  issuer = "https://token.actions.githubusercontent.com"
}

resource "tailscale_federated_identity" "deploy" {
  description = "Workshop deploy workflow"
  issuer      = local.issuer
  subject     = "repo:*"
  audience    = "${var.github_repo}/deploy"
  scopes      = ["auth_keys"]
  tags        = ["tag:ci-deployer"]
  custom_claim_rules = {
    repository   = var.github_repo
    workflow_ref = "${var.github_repo}/.github/workflows/deploy.yml@refs/heads/main"
  }
}

resource "tailscale_federated_identity" "policy_test" {
  description = "Workshop policy tests on pull requests"
  issuer      = local.issuer
  subject     = "repo:*"
  audience    = "${var.github_repo}/policy-test"
  scopes      = ["policy_file:read"]
  custom_claim_rules = {
    repository   = var.github_repo
    workflow_ref = "${var.github_repo}/.github/workflows/policy.yml@refs/pull/*"
  }
}

resource "tailscale_federated_identity" "policy_apply" {
  description = "Workshop policy apply from main"
  issuer      = local.issuer
  subject     = "repo:*"
  audience    = "${var.github_repo}/policy-apply"
  scopes      = ["policy_file"]
  custom_claim_rules = {
    repository   = var.github_repo
    workflow_ref = "${var.github_repo}/.github/workflows/policy.yml@refs/heads/main"
  }
}
