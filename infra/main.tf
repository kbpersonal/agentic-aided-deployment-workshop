terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.4"
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

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "tailscale" {
  oauth_client_id = var.tailscale_client_id
}

provider "border0" {
  token = var.border0_token
}

locals {
  name      = var.name
  namespace = "dev"
  proxy_tag = "tag:k8s-dev"

  github_issuer = "https://token.actions.githubusercontent.com"
}

resource "azurerm_resource_group" "this" {
  name     = local.name
  location = var.azure_location
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = local.name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = local.name

  oidc_issuer_enabled = true

  node_provisioning_profile {
    mode = "Manual"
  }

  default_node_pool {
    name       = "system"
    vm_size    = var.node_vm_size
    node_count = 2

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin = "azure"
    outbound_type  = "managedNATGateway"
  }

  identity {
    type = "SystemAssigned"
  }
}

locals {
  kube = azurerm_kubernetes_cluster.this.kube_config[0]
}

provider "kubernetes" {
  host                   = local.kube.host
  cluster_ca_certificate = base64decode(local.kube.cluster_ca_certificate)
  client_certificate     = base64decode(local.kube.client_certificate)
  client_key             = base64decode(local.kube.client_key)
}

provider "helm" {
  kubernetes = {
    host                   = local.kube.host
    cluster_ca_certificate = base64decode(local.kube.cluster_ca_certificate)
    client_certificate     = base64decode(local.kube.client_certificate)
    client_key             = base64decode(local.kube.client_key)
  }
}

resource "kubernetes_namespace_v1" "dev" {
  depends_on = [helm_release.ingress_proxygroup]

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
  dynamic "subject" {
    for_each = toset(concat(data.tailscale_users.owners.users[*].login_name, data.tailscale_users.admins.users[*].login_name))
    content {
      api_group = "rbac.authorization.k8s.io"
      kind      = "User"
      name      = subject.value
    }
  }
  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = "tag:ci-deployer@service.border0.com"
  }
}

resource "border0_connector" "this" {
  name        = local.name
  description = "PAM connector in the ${local.name} AKS cluster"
}

resource "border0_connector_token" "this" {
  connector_id = border0_connector.this.id
  name         = "${local.name}-helm"
}

resource "border0_socket" "k8s" {
  name          = "aks-dev"
  description   = "Kubernetes API of ${local.name}, scoped by cap/pam grants"
  socket_type   = "kubernetes"
  connector_ids = [border0_connector.this.id]

  kubernetes_configuration {
    service_type          = "standard"
    impersonation_enabled = true
  }
}

resource "helm_release" "tailzero" {
  depends_on = [azurerm_kubernetes_cluster.this]

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

data "tailscale_users" "owners" {
  role = "owner"
}

data "tailscale_users" "admins" {
  role = "admin"
}

resource "tailscale_federated_identity" "operator" {
  description = "AKS workshop Tailscale operator"
  issuer      = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject     = "system:serviceaccount:tailscale:operator"
  scopes      = ["devices:core", "auth_keys", "services"]
  tags        = ["tag:k8s-operator"]
}

resource "helm_release" "tailscale_operator" {
  depends_on = [azurerm_kubernetes_cluster.this]

  name             = "tailscale-operator"
  namespace        = "tailscale"
  create_namespace = true
  repository       = "https://pkgs.tailscale.com/helmcharts"
  chart            = "tailscale-operator"
  version          = var.tailscale_operator_version
  wait             = true

  values = [yamlencode({
    oauth          = { clientId = tailscale_federated_identity.operator.id, audience = tailscale_federated_identity.operator.audience }
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

resource "tailscale_federated_identity" "deploy" {
  description = "Workshop deploy workflow"
  issuer      = local.github_issuer
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
  issuer      = local.github_issuer
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
  issuer      = local.github_issuer
  subject     = "repo:*"
  audience    = "${var.github_repo}/policy-apply"
  scopes      = ["policy_file"]
  custom_claim_rules = {
    repository   = var.github_repo
    workflow_ref = "${var.github_repo}/.github/workflows/policy.yml@refs/heads/main"
  }
}
