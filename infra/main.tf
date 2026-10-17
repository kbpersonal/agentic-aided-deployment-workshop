terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

provider "tailscale" {
  tailnet = var.tailnet
}

locals {
  name      = "kb-agentic-workshop"
  namespace = "dev-${var.developer}"
  ksa       = "workshop-app"
}

data "google_project" "this" {}

data "google_client_config" "this" {}

resource "google_compute_network" "this" {
  name                    = "${local.name}-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  name                     = "${local.name}-subnet"
  network                  = google_compute_network.this.id
  ip_cidr_range            = "10.240.0.0/20"
  private_ip_google_access = true
}

resource "google_compute_router" "this" {
  name    = "${local.name}-router"
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  name                               = "${local.name}-nat"
  router                             = google_compute_router.this.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_container_cluster" "this" {
  name                = local.name
  location            = var.gcp_region
  network             = google_compute_network.this.id
  subnetwork          = google_compute_subnetwork.this.id
  enable_autopilot    = true
  deletion_protection = false

  ip_allocation_policy {}

  private_cluster_config {
    enable_private_nodes = true
  }

  control_plane_endpoints_config {
    ip_endpoints_config {
      enabled = false
    }
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }
}

provider "kubernetes" {
  host  = "https://${google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint}"
  token = data.google_client_config.this.access_token
}

provider "helm" {
  kubernetes = {
    host  = "https://${google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint}"
    token = data.google_client_config.this.access_token
  }
}

resource "google_service_account" "app" {
  account_id   = "${local.name}-app"
  display_name = "Workshop app Tailscale identity"
}

resource "google_service_account_iam_member" "app_workload_identity" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${data.google_project.this.project_id}.svc.id.goog[${local.namespace}/${local.ksa}]"
}

resource "tailscale_federated_identity" "app" {
  description = "GKE workshop app replicas"
  issuer      = "https://accounts.google.com"
  subject     = google_service_account.app.unique_id
  scopes      = ["auth_keys"]
  tags        = ["tag:workshop-app"]
}

resource "tailscale_federated_identity" "deploy" {
  description = "GitHub Actions deploy workflow"
  issuer      = "https://token.actions.githubusercontent.com"
  subject     = "repo:${var.github_repo}:ref:refs/heads/main"
  scopes      = ["auth_keys"]
  tags        = ["tag:ci-deployer"]
  custom_claim_rules = {
    workflow_ref = "${var.github_repo}/.github/workflows/deploy.yml@refs/heads/main"
  }
}

resource "tailscale_federated_identity" "agent" {
  description = "GitHub Actions Copilot agent workflow"
  issuer      = "https://token.actions.githubusercontent.com"
  subject     = "repo:${var.github_repo}:*"
  scopes      = ["auth_keys"]
  tags        = ["tag:ci-agent"]
  custom_claim_rules = {
    workflow_ref = "${var.github_repo}/.github/workflows/copilot.yml@*"
  }
}

resource "tailscale_federated_identity" "policy_test" {
  description = "Policy repository pull request tests"
  issuer      = "https://token.actions.githubusercontent.com"
  subject     = "repo:${var.policy_repo}:pull_request"
  scopes      = ["policy_file:read"]
}

resource "tailscale_federated_identity" "policy_apply" {
  description = "Policy repository apply from main"
  issuer      = "https://token.actions.githubusercontent.com"
  subject     = "repo:${var.policy_repo}:ref:refs/heads/main"
  scopes      = ["policy_file"]
}

resource "tailscale_service" "app" {
  name    = "svc:workshop-app"
  comment = "Agentic-aided deployment workshop app"
  ports   = ["tcp:443"]
}

resource "kubernetes_namespace_v1" "dev" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_role_binding_v1" "dev_edit" {
  metadata {
    name      = "pam-edit"
    namespace = kubernetes_namespace_v1.dev.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }
  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = var.developer_login
  }
  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = "tag:ci-deployer@service.border0.com"
  }
}

resource "kubernetes_config_map_v1" "tailscale" {
  metadata {
    name      = "tailscale"
    namespace = kubernetes_namespace_v1.dev.metadata[0].name
  }
  data = {
    TS_CLIENT_ID = "${tailscale_federated_identity.app.id}?ephemeral=false&preauthorized=true"
    TS_AUDIENCE  = tailscale_federated_identity.app.audience
    TS_TAG       = "tag:workshop-app"
    TS_SERVICE   = tailscale_service.app.name
  }
}

resource "kubernetes_service_account_v1" "app" {
  metadata {
    name      = local.ksa
    namespace = kubernetes_namespace_v1.dev.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.app.email
    }
  }
}

resource "kubernetes_role_v1" "app_state" {
  metadata {
    name      = "workshop-app-state"
    namespace = kubernetes_namespace_v1.dev.metadata[0].name
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "update", "patch", "create"]
  }
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch", "get"]
  }
}

resource "kubernetes_role_binding_v1" "app_state" {
  metadata {
    name      = "workshop-app-state"
    namespace = kubernetes_namespace_v1.dev.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.app_state.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = local.ksa
    namespace = kubernetes_namespace_v1.dev.metadata[0].name
  }
}

resource "helm_release" "tailzero" {
  name             = "tailzero"
  namespace        = "tailzero"
  create_namespace = true
  repository       = "https://borderzero.github.io/helm-charts"
  chart            = "tailzero-connector"
  version          = "0.5.0"

  values = [yamlencode({
    image  = { tag = var.tailzero_image_tag, pullPolicy = "IfNotPresent" }
    config = { inviteCode = var.tailzero_invite_code, hostname = local.name }
  })]
}
