output "namespace" {
  value = kubernetes_namespace_v1.dev.metadata[0].name
}

output "cluster_dns_endpoint" {
  value = google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
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
