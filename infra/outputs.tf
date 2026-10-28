output "namespace" {
  value = kubernetes_namespace_v1.dev.metadata[0].name
}

output "cluster_fqdn" {
  value = azurerm_kubernetes_cluster.this.fqdn
}

output "TS_DEPLOY_CLIENT_ID" {
  value = tailscale_federated_identity.deploy.id
}

output "TS_POLICY_TEST_CLIENT_ID" {
  value = tailscale_federated_identity.policy_test.id
}

output "TS_POLICY_APPLY_CLIENT_ID" {
  value = tailscale_federated_identity.policy_apply.id
}
