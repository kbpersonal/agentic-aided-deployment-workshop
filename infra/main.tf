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
    border0 = {
      source  = "borderzero/border0"
      version = "~> 3.0"
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

provider "border0" {}

locals {
  name      = "kb-agentic-workshop"
  namespace = "dev-${var.developer}"
  proxy_tag = "tag:k8s-dev"
}

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
  deletion_protection = false

  remove_default_node_pool = true
  initial_node_count       = 1

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

resource "google_container_node_pool" "this" {
  name           = "${local.name}-pool"
  cluster        = google_container_cluster.this.id
  node_locations = ["${var.gcp_region}-a", "${var.gcp_region}-b"]
  node_count     = 1

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 50
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
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

resource "tailscale_federated_identity" "deploy" {
  description = "GitHub Actions deploy workflow"
  issuer      = "https://token.actions.githubusercontent.com"
  subject     = "${var.github_repo_subject_prefix}:ref:refs/heads/main"
  scopes      = ["auth_keys"]
  tags        = ["tag:ci-deployer"]
  custom_claim_rules = {
    workflow_ref = "${var.github_repo}/.github/workflows/deploy.yml@refs/heads/main"
  }
}

resource "tailscale_federated_identity" "policy_test" {
  description = "Policy repository pull request tests"
  issuer      = "https://token.actions.githubusercontent.com"
  subject     = "${var.policy_repo_subject_prefix}:pull_request"
  scopes      = ["policy_file:read"]
}

resource "tailscale_federated_identity" "policy_apply" {
  description = "Policy repository apply from main"
  issuer      = "https://token.actions.githubusercontent.com"
  subject     = "${var.policy_repo_subject_prefix}:environment:tailnet-policy"
  scopes      = ["policy_file"]
  custom_claim_rules = {
    ref = "refs/heads/main"
  }
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

resource "border0_connector" "this" {
  name        = local.name
  description = "PAM connector in the ${local.name} GKE cluster"
}

resource "border0_connector_token" "this" {
  connector_id = border0_connector.this.id
  name         = "${local.name}-helm"
}

resource "border0_socket" "k8s" {
  name          = "kb-gke-dev"
  description   = "Kubernetes API of ${local.name}, scoped by cap/pam grants"
  socket_type   = "kubernetes"
  connector_ids = [border0_connector.this.id]

  kubernetes_configuration {
    service_type          = "standard"
    impersonation_enabled = true
  }
}

resource "helm_release" "tailzero" {
  depends_on = [google_container_node_pool.this]

  name             = "tailzero"
  namespace        = "tailzero"
  create_namespace = true
  repository       = "https://borderzero.github.io/helm-charts"
  chart            = "tailzero-connector"
  version          = "0.5.0"

  values = [yamlencode({
    image  = { tag = var.tailzero_image_tag, pullPolicy = "IfNotPresent" }
    config = { token = border0_connector_token.this.token, hostname = local.name }
  })]
}

resource "tailscale_oauth_client" "operator" {
  description = "GKE workshop Tailscale operator"
  scopes      = ["devices:core", "auth_keys", "services"]
  tags        = ["tag:k8s-operator"]
}

resource "helm_release" "tailscale_operator" {
  depends_on = [google_container_node_pool.this]

  name             = "tailscale-operator"
  namespace        = "tailscale"
  create_namespace = true
  repository       = "https://pkgs.tailscale.com/helmcharts"
  chart            = "tailscale-operator"
  version          = var.tailscale_operator_version
  wait             = true

  values = [yamlencode({
    oauth          = { clientId = tailscale_oauth_client.operator.id, clientSecret = tailscale_oauth_client.operator.key }
    operatorConfig = { hostname = "${local.name}-operator" }
  })]
}

resource "helm_release" "ingress_proxygroup" {
  name      = "ingress-proxygroup"
  namespace = "tailscale"
  chart     = "${path.module}/charts/proxygroup"

  values = [yamlencode({
    name     = "dev-ingress"
    replicas = 2
    tags     = [local.proxy_tag]
  })]

  depends_on = [helm_release.tailscale_operator]
}
