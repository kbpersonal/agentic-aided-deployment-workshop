# Tailnet policy repository

This folder is the starting point for a separate, private repository that owns the tailnet policy. Every change to who can reach what is a pull request there:

- Pull requests run `tailscale/gitops-acl-action` with `action: test`, using a GitHub OIDC trust credential limited to `policy_file:read`.
- Merges to `main` apply the exact merged file, using a separate trust credential limited to `policy_file`, behind the `tailnet-policy` environment.
- No Tailscale API key or OAuth secret is stored in GitHub. The workflow reads only repository variables, which are identifiers, not secrets.

Keep the repository private: the policy file contains login names.

## Create the repository

From the workshop repository root:

```bash
gh repo create agentic-aided-deployment-policy --private
cp -R policy/. ../agentic-aided-deployment-policy/
cd ../agentic-aided-deployment-policy
git init -b main && git add -A && git commit -m "Baseline workshop tailnet policy"
git remote add origin git@github.com:<your-github-user>/agentic-aided-deployment-policy.git
git push -u origin main
gh api -X PUT repos/<your-github-user>/agentic-aided-deployment-policy/environments/tailnet-policy
```

Add a required reviewer to the `tailnet-policy` environment if you want a human approval before every apply.

## Fill in the policy

In `policy.hujson`, replace:

- `AUTHOR_LOGIN` with the developer's login name, exactly as shown on the **Users** page of the admin console.
- `TEAMMATE_LOGIN` with the second user's login name.

If the tailnet already has a policy, merge these sections into it instead of replacing it, and remove any blanket `* → *` grant so default deny is visible. Apply this first version once by hand in the admin console: the trust credentials the workflow uses are created by Terraform, which needs the workshop tags to exist first.

## Repository variables

After `terraform apply` in the workshop repository:

```bash
P=--repo=<your-github-user>/agentic-aided-deployment-policy
gh variable set TS_TAILNET                $P --body "<tailnet-id>"
gh variable set TS_POLICY_TEST_CLIENT_ID  $P --body "$(terraform -chdir=../agentic-aided-deployment-workshop/infra output -raw policy_test_client_id)"
gh variable set TS_POLICY_TEST_AUDIENCE   $P --body "$(terraform -chdir=../agentic-aided-deployment-workshop/infra output -raw policy_test_audience)"
gh variable set TS_POLICY_APPLY_CLIENT_ID $P --body "$(terraform -chdir=../agentic-aided-deployment-workshop/infra output -raw policy_apply_client_id)"
gh variable set TS_POLICY_APPLY_AUDIENCE  $P --body "$(terraform -chdir=../agentic-aided-deployment-workshop/infra output -raw policy_apply_audience)"
```

The tailnet ID is under **Settings → General** in the admin console. Run the workflow once with `gh workflow run tailscale.yml` to confirm the apply credential works.

## What the policy says

| Who | Reaches | How |
| --- | --- | --- |
| The developer | `svc:workshop-app` (the operator's Ingress) and its `tag:k8s-dev` proxies on 443 | `ip` grant |
| The developer, `tag:ci-deployer` | `svc:gke-dev`, the PAM Kubernetes service | `tailscale.com/cap/pam`, limited to namespace `dev` |
| The developer | `tag:aperture` on 80 | `tailscale.com/cap/aperture` |
| Every member | their own devices | `autogroup:self` |
| `group:workshop-team` | nothing yet | the two access pull requests below |

The Tailscale operator owns `tag:k8s-dev`: its `dev-ingress` ProxyGroup devices and the Tailscale Services they advertise carry it, and `autoApprovers.services` lets those devices host those Services.

The tests prove the developer reaches `svc:workshop-app`, while the teammate and `tag:ci-deployer` do not.

## Access pull request 1: share the laptop

The developer runs `tailscale serve --bg 3000` on their laptop. This grants the team the developer's devices on 443:

```diff
 "grants": [
+  {
+    "src": ["group:workshop-team"],
+    "dst": ["AUTHOR_LOGIN"],
+    "ip":  ["tcp:443"],
+  },
```

## Access pull request 2: the dev-cluster Service

```diff
 {
-  "src": ["AUTHOR_LOGIN"],
+  "src": ["AUTHOR_LOGIN", "group:workshop-team"],
   "dst": ["svc:workshop-app", "tag:k8s-dev"],
   "ip":  ["tcp:443"],
 },
```

Change the teammate's `deny` test to `accept` in the same pull request. Revert either pull request to revoke that access; the app and cluster are untouched.
