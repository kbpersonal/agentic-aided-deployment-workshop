# Agentic-Aided Deployment Beyond Localhost

A developer has a small Node.js app that works on their laptop. They know nothing about Kubernetes. The platform team has given them one namespace in a private GKE cluster and a kubeconfig that reaches it only through Tailscale. Their agent, GitHub Copilot CLI launched through the Aperture CLI, writes the manifests and opens the pull request. GitHub Actions deploys it through Tailscale PAM, and the Tailscale Kubernetes operator puts it on the tailnet.

Nobody in this story holds a Kubernetes credential, a cloud credential, a Tailscale auth key, or a model API key. Tailscale identity is the credential at every step, and every access change is a pull request.

## The story

1. **Localhost.** `npm start`. The app runs on the developer's laptop.
2. **Share it.** `tailscale serve --bg 3000` publishes it at `https://<laptop>.<tailnet>.ts.net`. A pull request in the policy repository lets the team in.
3. **Ship it with an agent.** `aperture copilot` starts Copilot CLI with Aperture as its model gateway, so every model call is attributed to the developer's tailnet identity. The agent reads the platform contract, writes `k8s/`, checks the namespace through PAM, and opens a pull request.
4. **Deploy.** Merging runs `deploy.yml`. The runner joins the tailnet as an ephemeral `tag:ci-deployer` with GitHub OIDC and applies `k8s/` through the Tailscale PAM Kubernetes service `kb-gke-dev`, which only allows namespace `dev-kartik`.
5. **On the tailnet.** The agent's `Ingress` is served by the operator's `dev-ingress` ProxyGroup as the Tailscale Service `svc:workshop-app`, at `https://workshop-app.<tailnet>.ts.net`, from two proxy replicas.
6. **Team access.** A second policy pull request grants the team the dev-cluster Service. Reverting it revokes access.

The app is plain Node.js and contains no Tailscale code. Reachability, identity, and access all come from the tailnet.

## Architecture

```mermaid
flowchart TB
  subgraph laptop["Developer laptop"]
    app["npm start<br/>localhost:3000"]
    serve["tailscale serve<br/>https://laptop.&lt;tailnet&gt;.ts.net"]
    copilot["aperture copilot<br/>GitHub Copilot CLI"]
    app --- serve
  end

  aperture["Aperture<br/>http://ai"]

  subgraph github["GitHub"]
    pr["Pull request"] --> ci["CI: npm test, image build, manifest checks"] --> merge["Merge to main"]
    merge --> deploy["deploy.yml"]
  end

  runner["Ephemeral runner<br/>tag:ci-deployer"]
  pam["svc:kb-gke-dev<br/>Tailscale PAM Kubernetes service<br/>cap/pam: namespace dev-kartik only"]

  subgraph gke["Private GKE Standard cluster"]
    subgraph ns0["namespace tailzero"]
      connector["PAM connector<br/>impersonates the caller"]
    end
    subgraph ns1["namespace dev-kartik"]
      dep["Deployment workshop-app x2"]
      svc["Service workshop-app"]
      ing["Ingress workshop-app<br/>proxy-group: dev-ingress"]
      dep --- svc --- ing
    end
    subgraph ns2["namespace tailscale"]
      operator["Tailscale operator"]
      pg["ProxyGroup dev-ingress<br/>2 proxies, tag:k8s-dev"]
    end
  end

  tsvc["svc:workshop-app<br/>https://workshop-app.&lt;tailnet&gt;.ts.net"]
  team["Granted users"]

  copilot -- "model calls, attributed" --> aperture
  copilot -- "writes k8s/, opens" --> pr
  copilot -- "kubectl via ./kubeconfig" --> pam
  deploy -- "GitHub OIDC" --> runner
  runner -- "kubectl apply" --> pam
  pam --> connector
  connector -- "Kubernetes API, impersonated" --> ns1
  operator -. "watches Ingress" .-> ing
  operator --> pg
  pg -- "advertises" --> tsvc
  pg -- "proxies to" --> svc
  team -- "tcp:443, per policy grant" --> tsvc
  team -- "tcp:443, per policy grant" --> serve
```

## Security boundaries

- The cluster's IP control-plane endpoint is disabled. The platform team uses the IAM-gated DNS endpoint; developers and CI reach the API only through the PAM service.
- The developer and CI hold Kubernetes `edit` in `dev-kartik` only, bound to the identities the connector impersonates: the developer's login and `tag:ci-deployer@service.border0.com`.
- The `tailscale.com/cap/pam` grant restricts Kubernetes requests to `namespaces: ["dev-kartik"]` before RBAC is evaluated.
- GitHub Actions logs in with GitHub OIDC, scoped by `workflow_ref` to `deploy.yml` on `main`. No secret is stored in GitHub.
- Copilot CLI runs in offline BYOK mode against Aperture. It needs no GitHub Copilot sign-in and no model key; Aperture authorizes the developer's tailnet identity.
- The app's identity card comes from `Tailscale-User-*` headers that Tailscale Serve and the operator's Ingress add. Neither the laptop nor the cluster exposes the app any other way.
- Tailscale Funnel is not used.

## Repositories

1. This application repository: app, platform contract, kubeconfig, workflows, and `infra/`. Each developer works on their own fork.
2. A private policy repository, for example [`kbpersonal/agentic-aided-deployment-policy`](https://github.com/kbpersonal/agentic-aided-deployment-policy). `policy/policy.hujson` here is the template. Keep it private because it contains login names.

## Prerequisites

- A tailnet with HTTPS certificates and Tailscale PAM enabled (**Settings → PAM**), where you are an Admin or Owner.
- An Aperture instance on the tailnet, tagged `tag:aperture`, reachable at `http://ai` (the launcher's default; any other hostname works with `--endpoint`).
- Two Tailscale users for the access steps.
- A Google Cloud project with GKE enabled.
- Node.js 24, `kubectl`, and `gh` installed locally. Presenters also need `terraform` and `gcloud`.
- The [Aperture launcher](https://github.com/tailscale/aperture-cli) v0.1.0 or later, and GitHub Copilot CLI:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/tailscale/aperture-cli/main/install.sh | APERTURE_INSTALL_DIR=$HOME/.local/bin sh
  npm install -g @github/copilot
  ```

  Running `aperture` with no arguments and choosing **GitHub Copilot** also offers to install Copilot CLI.

## Platform setup (before the workshop)

### Tailnet policy

Copy `policy/policy.hujson` into the private policy repository and replace `AUTHOR_LOGIN` and `TEAMMATE_LOGIN`. If the tailnet already has a policy, merge these sections in, and remove any blanket `* → *` grant so default deny is visible. Apply this first version once by hand; after that, the policy repository's workflow owns the file.

### Infrastructure

Terraform builds everything: the cluster, the Tailscale operator and its ingress ProxyGroup, the PAM connector and Kubernetes service, the trust credentials, and the developer namespace. It needs two admin credentials from the environment:

- `TAILSCALE_API_KEY`: an API access token for the tailnet.
- `BORDER0_TOKEN`: a Tailscale PAM service-account token. Create a service account with the **Member** role under **Settings → PAM → Service accounts**, then create a token for it. Tailscale PAM is managed through the [Border0 Terraform provider](https://tailscale.com/docs/privileged-access-management/how-to/manage-resources-terraform).

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# GitHub OIDC subjects use immutable owner and repository IDs; read each prefix with:
gh api repos/OWNER/REPO/actions/oidc/customization/sub -q .sub_claim_prefix
export TAILSCALE_API_KEY=...
export BORDER0_TOKEN=...
terraform init
terraform apply -target=google_container_cluster.this
terraform apply
```

The first apply creates the cluster so the Kubernetes and Helm providers have an endpoint. The second creates:

- **Network:** a VPC with Cloud NAT and a private GKE Standard cluster with two nodes. The Tailscale operator is not supported on platforms that forbid privileged pods, such as GKE Autopilot.
- **Tailscale operator:** an OAuth client tagged `tag:k8s-operator`, the operator Helm release, and the `dev-ingress` ProxyGroup with two `tag:k8s-dev` proxies.
- **Tailscale PAM:** connector `kb-agentic-workshop`, its token, and the Kubernetes service `kb-gke-dev` with impersonation on. The connector exchanges its token for its own Tailscale auth key.
- **Trust credentials:** deploy, policy test, and policy apply, all GitHub OIDC.
- **Developer namespace:** `dev-kartik` and its `edit` RoleBinding for the developer and `tag:ci-deployer`.

### Repository variables

```bash
gh variable set TS_DEPLOY_CLIENT_ID --body "$(terraform -chdir=infra output -raw deploy_client_id)"
gh variable set TS_DEPLOY_AUDIENCE  --body "$(terraform -chdir=infra output -raw deploy_audience)"

P=--repo=OWNER/agentic-aided-deployment-policy
gh variable set TS_TAILNET                $P --body "<tailnet-id>"
gh variable set TS_POLICY_TEST_CLIENT_ID  $P --body "$(terraform -chdir=infra output -raw policy_test_client_id)"
gh variable set TS_POLICY_TEST_AUDIENCE   $P --body "$(terraform -chdir=infra output -raw policy_test_audience)"
gh variable set TS_POLICY_APPLY_CLIENT_ID $P --body "$(terraform -chdir=infra output -raw policy_apply_client_id)"
gh variable set TS_POLICY_APPLY_AUDIENCE  $P --body "$(terraform -chdir=infra output -raw policy_apply_audience)"
```

These are identifiers, not secrets. A token is issued only to a workflow whose OIDC claims match.

## Step 1: Localhost

```bash
npm test
HOST=127.0.0.1 npm start
curl http://127.0.0.1:3000/health
```

## Step 2: Share it with tailscale serve

```bash
tailscale serve --bg 3000
tailscale serve status
```

Open the `https://<laptop>.<tailnet>.ts.net` address it prints. The identity card shows your name: Serve adds the `Tailscale-User-*` headers. A teammate who opens the same URL can't connect.

To let the team in, open a pull request in the policy repository that adds them to `group:workshop-team` and grants the group your devices on `tcp:443` (see the policy repository README). The pull request runs `action: test`; merging applies it. The agent in Step 3 can open this pull request for you.

Stop sharing with `tailscale serve --https=443 off`.

## Step 3: Ship it with an agent

From the repository root:

```bash
aperture copilot
```

The launcher connects to Aperture at `http://ai`, lists the models Aperture offers, and starts Copilot CLI pointed at the one you pick. Copilot needs no GitHub sign-in, no Copilot plan, and no model key. Every request appears in the Aperture dashboard under your tailnet identity. To skip the menu:

```bash
aperture copilot --model anthropic/claude-sonnet-5.5
aperture copilot --endpoint http://<aperture-hostname> --model anthropic/claude-sonnet-5.5
```

Everything after `--` goes to `copilot` unchanged. `aperture copilot --debug` prints the environment the launcher sets.

Prompt:

> Ship this app to my dev namespace, highly available and reachable on the tailnet. Follow the platform contract, then open a pull request.

The agent reads `.github/copilot-instructions.md`, writes a `Deployment`, `Service`, and Tailscale `Ingress` like `docs/reference/workshop-app.yaml`, and opens the pull request with `gh`. It can check the namespace with `KUBECONFIG=./kubeconfig kubectl get all`. Ask it to try `-n kube-system`; PAM refuses.

## Step 4: Deploy

Merge the pull request. CI runs the tests, builds the image, and checks `k8s/`. `deploy.yml` then:

1. Builds and pushes `ghcr.io/<owner>/<repo>:<sha>`.
2. Joins the tailnet as an ephemeral `tag:ci-deployer` with GitHub OIDC, using the official [Tailscale GitHub Action](https://github.com/tailscale/github-action).
3. Uses the same `./kubeconfig` the developer has.
4. Substitutes the image into every workload in `k8s/`, applies the manifests through PAM, and waits for the rollout.

A container package pushed from a public repository's workflow inherits public visibility, so the cluster pulls without credentials.

## Step 5: The app on the tailnet

```bash
KUBECONFIG=./kubeconfig kubectl get ingress workshop-app
```

When `ADDRESS` shows `workshop-app.<tailnet>.ts.net`, open `https://workshop-app.<tailnet>.ts.net`. The operator created the Tailscale Service `svc:workshop-app`, and both `dev-ingress` proxies advertise it. The identity card shows you again, this time added by the operator's ingress proxy.

## Step 6: Team access to the dev cluster

Before the change, the teammate's connection to `https://workshop-app.<tailnet>.ts.net` fails. Tailscale drops the traffic before the app sees it, so there is no HTTP 403.

Open a pull request in the policy repository adding `group:workshop-team` to the `svc:workshop-app` grant. Merge it, and the teammate gets in with their own identity. Revert it to revoke access; the app and cluster are untouched.

## Repository protection

Protect `main`: require pull requests, an approval, CODEOWNER review for workflows and policy, passing checks, and resolved conversations. Disable force pushes. Do not let the agent approve or merge its own change. Pin third-party actions to full commit SHAs before using this outside a workshop.

## Cleanup

```bash
tailscale serve reset
terraform -chdir=infra destroy
```

This removes the cluster, the operator, the PAM connector and service, and the trust credentials. Remove any leftover `kb-agentic-workshop*` and `dev-ingress-*` machines from the tailnet.

## Troubleshooting

### The Ingress never gets an address

- `KUBECONFIG=./kubeconfig kubectl describe ingress workshop-app` shows the operator's events.
- The `tailscale.com/proxy-group` annotation must be `dev-ingress`, and `ingressClassName` must be `tailscale`.
- The policy's `autoApprovers.services` must map `tag:k8s-dev` to `tag:k8s-dev`, and `tag:k8s-dev` must be owned by `tag:k8s-operator`.

### The Service resolves but connections time out

On some tailnets clients only receive a Service's hosts when a grant also names the hosts' tag. The grant therefore lists both `svc:workshop-app` and `tag:k8s-dev` on `tcp:443`.

### kubectl through PAM is refused

- `Forbidden` naming `tag:ci-deployer@service.border0.com` or your login: PAM let the request through, and RBAC refused it. Check the `pam-edit` RoleBinding.
- `no policy rule allows access ... resource name "..."` inside `dev-kartik`: the `cap/pam` Kubernetes rule needs `"resource_names": ["*"]`.
- `failed to download openapi`: client-side validation reads the cluster-scoped `/openapi` path, which a namespace-scoped grant refuses. Apply with `--validate=false`, as `deploy.yml` does.
- Connection refused or timeout: the grant to `svc:kb-gke-dev` is missing, or the device is not on the tailnet.

## Workshop runbook

See `docs/RUNBOOK.md` for the on-stage sequence and `docs/SETUP.md` for the rehearsal checklist.
