# Rehearsal Checklist

Use the root `README.md` for full commands.

## Tailnet

- [ ] HTTPS certificates enabled; Funnel not used.
- [ ] Tailscale PAM enabled (**Settings → PAM**) and a Member service-account token for Terraform.
- [ ] Aperture online at `http://ai` and tagged `tag:aperture`.
- [ ] Second user has the Member role, not Admin.
- [ ] Baseline `policy/policy.hujson` applied; no blanket `* → *` grant.

## Infrastructure

- [ ] `infra/bootstrap` applied once; its three client IDs set as repository variables.
- [ ] `infra` applied; `terraform plan` shows no changes.
- [ ] Operator and both `dev-ingress` proxies online.
- [ ] PAM connector online and PAM service `gke-dev` active.
- [ ] `KUBECONFIG=./kubeconfig kubectl get pods` works; `-n kube-system` is refused.

## Repository

- [ ] Fork is public; `main` has no `k8s/`.
- [ ] `policy.yml` runs: a test on a policy pull request, an apply on merge.

## Presenter machine

- [ ] `aperture --version` reports v0.1.0 or later; `copilot` installed.

## End-to-end evidence

- [ ] Laptop Serve URL reachable by the developer only, then by the second user after the first policy pull request.
- [ ] `aperture copilot` starts Copilot CLI and it answers through Aperture, attributed to the developer.
- [ ] The agent pushes a branch; the pull request opens from the printed link.
- [ ] Deploy run succeeds from GitHub OIDC through PAM.
- [ ] Ingress has an address; the Service answers with the developer's identity.
- [ ] Second user denied before the Service pull request, allowed after, denied again after the revert.
