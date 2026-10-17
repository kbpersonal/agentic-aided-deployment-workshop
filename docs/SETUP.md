# Administrator Checklist

Use the root `README.md` for full commands. This checklist is for rehearsal.

## Tailnet

- [ ] HTTPS certificates enabled; Funnel not used.
- [ ] Tailscale PAM enabled (**Settings → PAM**).
- [ ] Aperture online and tagged `tag:aperture`; the author has a model grant.
- [ ] Author and teammate login names recorded and substituted in the policy.
- [ ] No blanket `* → *` grant.
- [ ] `tag:ci-deployer`, `tag:ci-agent`, `tag:workshop-app`, `tag:border0-managed`, `tag:aperture` in `tagOwners`.
- [ ] `autoApprovers.services` maps `svc:workshop-app` to `tag:workshop-app`.
- [ ] The `cap/pam` grant for `svc:kb-gke-dev` lists only `dev-kartik` in `namespaces`.
- [ ] Policy tests pass: author accepted on `svc:workshop-app:443`, `tag:ci-deployer` denied.

## Infrastructure

- [ ] `terraform apply` completed; `terraform plan` shows no changes.
- [ ] GKE IP control-plane endpoint disabled.
- [ ] Connector `kb-agentic-workshop` online.
- [ ] PAM service `kb-gke-dev` exists with impersonation on.
- [ ] `svc:workshop-app` exists with port `tcp:443`.

## GitHub

- [ ] App repository variables: `TS_DEPLOY_CLIENT_ID`, `TS_DEPLOY_AUDIENCE`, `TS_AGENT_CLIENT_ID`, `TS_AGENT_AUDIENCE`, `APERTURE_URL`, `COPILOT_MODEL`.
- [ ] Policy repository variables: `TS_TAILNET` and both policy trust credential IDs and audiences.
- [ ] Policy repository `tailnet-policy` environment exists, ideally with a required reviewer.
- [ ] No Tailscale, cloud or model secret is stored in either repository.
- [ ] GHCR package public.
- [ ] Branch protection and CODEOWNERS on both repositories.

## End-to-end evidence

- [ ] Laptop tsnet node reachable by the author only.
- [ ] Copilot CLI answers through Aperture.
- [ ] `kubectl --server=http://kb-gke-dev -n dev-kartik get pods` works for the author.
- [ ] Same command with `-n kube-system` is refused.
- [ ] Deploy run succeeds from GitHub OIDC through PAM.
- [ ] Two Ready pods; the Service answers with either replica.
- [ ] Teammate denied before PR 2, allowed after, denied again after the revert.
