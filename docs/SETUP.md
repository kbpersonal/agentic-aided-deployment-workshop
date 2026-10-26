# Administrator Checklist

Use the root `README.md` for full commands. This checklist is for rehearsal.

## Tailnet

- [ ] HTTPS certificates enabled; Funnel not used.
- [ ] Tailscale PAM enabled (**Settings → PAM**) and a Member service-account token for Terraform.
- [ ] Aperture online at `http://ai` and tagged `tag:aperture`; the author has a model grant.
- [ ] Author and teammate login names recorded and substituted in the policy.
- [ ] No blanket `* → *` grant.
- [ ] `tag:k8s-operator` and `tag:ci-deployer` in `tagOwners`, `tag:k8s-dev` owned by `tag:k8s-operator`.
- [ ] `autoApprovers.services` maps `tag:k8s-dev` to `tag:k8s-dev`.
- [ ] The `cap/pam` grant for `svc:gke-dev` lists only `dev` in `namespaces`, with `resource_names: ["*"]`.
- [ ] Policy tests pass.

## Infrastructure

- [ ] `terraform apply` completed; `terraform plan` shows no changes.
- [ ] Operator and both `dev-ingress` proxies online.
- [ ] PAM connector online and PAM service `gke-dev` active.

## GitHub

- [ ] App repository variables: `TS_DEPLOY_CLIENT_ID`, `TS_DEPLOY_AUDIENCE`.
- [ ] Policy repository created from `policy/`, with `TS_TAILNET` and both policy trust credential IDs and audiences set.
- [ ] No Tailscale, cloud, or model secret stored in either repository.
- [ ] `main` of the template has no `k8s/`.

## Attendee machines

- [ ] `aperture --version` reports v0.1.0 or later; `copilot` installed; `gh auth status` succeeds.

## End-to-end evidence

- [ ] Laptop Serve URL reachable by the author only, then by the teammate after the policy pull request.
- [ ] `aperture copilot` starts Copilot CLI and it answers through Aperture, attributed to the author.
- [ ] The agent opens the pull request itself.
- [ ] `KUBECONFIG=./kubeconfig kubectl get pods` works; `-n kube-system` is refused.
- [ ] Deploy run succeeds from GitHub OIDC through PAM.
- [ ] Ingress has an address; the Service answers with the author's identity.
- [ ] Teammate denied before the access pull request, allowed after, denied again after the revert.
