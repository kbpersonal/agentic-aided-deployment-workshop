output "namespace" {
  value = kubernetes_namespace_v1.dev.metadata[0].name
}

output "deploy_client_id" {
  value = tailscale_federated_identity.deploy.id
}

output "deploy_audience" {
  value = tailscale_federated_identity.deploy.audience
}

output "agent_client_id" {
  value = tailscale_federated_identity.agent.id
}

output "agent_audience" {
  value = tailscale_federated_identity.agent.audience
}

output "cluster_dns_endpoint" {
  value = google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
}

output "policy_test_client_id" {
  value = tailscale_federated_identity.policy_test.id
}

output "policy_test_audience" {
  value = tailscale_federated_identity.policy_test.audience
}

output "policy_apply_client_id" {
  value = tailscale_federated_identity.policy_apply.id
}

output "policy_apply_audience" {
  value = tailscale_federated_identity.policy_apply.audience
}
