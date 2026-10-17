# Agentic-Aided Deployment Beyond Localhost

A developer has an app that runs on their laptop. The platform team has given them one Kubernetes namespace in a private GKE cluster and nothing else. They know nothing about Kubernetes. Their agent, GitHub Copilot CLI, turns the app into manifests and opens a pull request. GitHub Actions deploys it through Tailscale, and the team reaches it at one private HTTPS name served by several replicas.

Nobody in this story holds a kubeconfig, a cloud credential, a Tailscale auth key, or a model API key.

## The story in three acts

**Act 1: localhost to tailnet.** The app is a Go program built with [tsnet](https://tailscale.com/docs/features/tsnet). Run it with `TS_HOSTNAME` set and it joins the tailnet as its own device, with HTTPS, reachable by its owner and nobody else. No Tailscale Service, no server.

**Act 2: the agent ships it.** Copilot CLI runs through [Aperture](https://tailscale.com/docs/aperture), so model access is a tailnet grant instead of an API key. The repository's `.github/copilot-instructions.md` is the platform contract: one namespace, a pre-made ServiceAccount and ConfigMap, no cluster-scoped objects. The agent writes `k8s/` and opens a pull request. It can inspect the namespace through the same Tailscale PAM service the pipeline uses, with the developer's own identity.

**Act 3: production and access.** The merge triggers a deploy. The runner joins the tailnet as an ephemeral `tag:ci-deployer` via GitHub OIDC and runs `kubectl apply` against `http://kb-gke-dev`, a Tailscale PAM Kubernetes service. PAM confines it to `dev-kartik`, and Kubernetes RBAC confines it again. Every replica runs the same binary with `TS_SERVICE=svc:workshop-app`, so the one name `https://workshop-app.<tailnet>.ts.net` stays up while any replica is. A second pull request, in the policy repository, grants the team access. Reverting it revokes access.

## Architecture

```text
developer laptop                      GitHub
  Copilot CLI ──Aperture (tailnet)──►  pull request ── CI ── merge
  kubectl ──┐                                                  │
            │                                       GitHub OIDC│
            │                                                  ▼
            │                                   ephemeral tag:ci-deployer
            │                                                  │
            └──────── tailnet ── svc:kb-gke-dev (PAM, Kubernetes) ◄──┘
                                       │ cap/pam: namespace dev-kartik only
                                       ▼
private GKE Autopilot cluster (no public IP endpoint, private nodes)
  namespace tailzero:   PAM connector, impersonates the caller
  namespace dev-kartik: StatefulSet workshop-app × 2
                          each pod: tsnet, ListenService(svc:workshop-app)
                          login: GKE Workload Identity → Tailscale WIF
                          state: one Kubernetes Secret per pod
                                       │
                                       ▼
                     https://workshop-app.<tailnet>.ts.net
```

## Security boundaries

- The cluster's IP control-plane endpoint is disabled. Administrators use the IAM-gated DNS endpoint; developers and CI reach the API only through the PAM service.
- The developer and CI hold Kubernetes `edit` in `dev-kartik` only, bound to the identities the connector impersonates: the developer's login and `tag:ci-deployer@service.border0.com`.
- The `tailscale.com/cap/pam` grant restricts Kubernetes requests to `namespaces: ["dev-kartik"]` before RBAC is evaluated.
- App pods log in with GKE Workload Identity exchanged through Tailscale workload identity federation. No auth key exists.
- GitHub Actions logs in with GitHub OIDC, scoped by `workflow_ref` to `deploy.yml` on `main`. No secret is stored in GitHub.
- The app's identity card comes from headers that Tailscale Serve adds inside the tsnet process; nothing else can reach that listener.
- Tailscale Funnel is not used. No Kubernetes `Service`, `Ingress`, or load balancer exposes the app.

## Repositories

1. This application repository: app, platform contract, workflows, and `infra/`.
2. A private policy repository, for example [`kbpersonal/agentic-aided-deployment-policy`](https://github.com/kbpersonal/agentic-aided-deployment-policy). `policy/policy.hujson` here is the template. Keep the policy repository private because it contains login names.

## Prerequisites

- A tailnet with HTTPS certificates and Tailscale PAM enabled (**Settings → PAM**), where you are an Admin or Owner.
- An Aperture instance on the tailnet, tagged `tag:aperture`, for Copilot CLI.
- Two Tailscale users for the before/after access demonstration.
- A Google Cloud project with GKE enabled.
- `go`, `terraform`, `kubectl`, `gcloud`, `gh`, `copilot` (GitHub Copilot CLI), and [`aperture`](https://github.com/tailscale/aperture-cli) installed locally.

## Step 1: Act 1 on your laptop

```bash
go test ./...
go run .                              # http://127.0.0.1:3000
TS_HOSTNAME=workshop-app-laptop go run .
```

The second run prints a login URL the first time. Open it, then open the `https://workshop-app-laptop.<tailnet>.ts.net` address the program prints. The identity card shows who you are; the page is reachable only by you, through the `autogroup:self` grant.

## Step 2: Baseline tailnet policy

Copy `policy/policy.hujson` into the private policy repository. Replace `AUTHOR_LOGIN` and `TEAMMATE_LOGIN` with exact login names from **Users**. If the tailnet already has a policy, merge these sections into it. A blanket `* → *` grant would hide the default-deny demonstration, so remove it.

Apply this first version once by hand, in the admin console or with the API. The next step creates the tags' trust credentials, and those need the tags to exist. After that, the policy repository's workflow owns the file.

## Step 3: Infrastructure

In the admin console, open **Network → Connectors → Add connector → Kubernetes** and copy only the invite code. Terraform installs the chart, so skip the Helm command the wizard shows.

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # fill in, including the invite code
export TAILSCALE_API_KEY=...                   # admin API access token for the tailnet
terraform init
terraform apply -target=google_container_cluster.this
terraform apply
```

This creates:

- **Network:** a VPC with Cloud NAT and a private GKE Autopilot cluster.
- **App identity:** the app's Google service account and its Workload Identity binding.
- **Tailscale:** five trust credentials (app, deploy, agent, policy test, policy apply) and the `svc:workshop-app` Service.
- **Cluster objects:** namespace `dev-kartik` and its RBAC, the `workshop-app` ServiceAccount, the `tailscale` ConfigMap, and the PAM connector.

When the connector shows online, open **Services → Add PAM service → Kubernetes (Standard)**:

- Name: `kb-gke-dev`
- Connector: `kb-agentic-workshop`
- Kubeconfig: **System's kubeconfig with current context** (the connector's in-cluster ServiceAccount)
- **Enable impersonation**: on

## Step 4: Repository variables

```bash
gh variable set TS_DEPLOY_CLIENT_ID  --body "$(terraform -chdir=infra output -raw deploy_client_id)"
gh variable set TS_DEPLOY_AUDIENCE   --body "$(terraform -chdir=infra output -raw deploy_audience)"
gh variable set TS_AGENT_CLIENT_ID   --body "$(terraform -chdir=infra output -raw agent_client_id)"
gh variable set TS_AGENT_AUDIENCE    --body "$(terraform -chdir=infra output -raw agent_audience)"
gh variable set APERTURE_URL         --body "http://<aperture-hostname>"
gh variable set COPILOT_MODEL        --body "<provider>/<model>"

P=--repo=OWNER/agentic-aided-deployment-policy
gh variable set TS_TAILNET                $P --body "<tailnet-id>"
gh variable set TS_POLICY_TEST_CLIENT_ID  $P --body "$(terraform -chdir=infra output -raw policy_test_client_id)"
gh variable set TS_POLICY_TEST_AUDIENCE   $P --body "$(terraform -chdir=infra output -raw policy_test_audience)"
gh variable set TS_POLICY_APPLY_CLIENT_ID $P --body "$(terraform -chdir=infra output -raw policy_apply_client_id)"
gh variable set TS_POLICY_APPLY_AUDIENCE  $P --body "$(terraform -chdir=infra output -raw policy_apply_audience)"
```

These are identifiers, not secrets. A token is issued only to a workflow whose OIDC claims match.

## Step 5: Act 2, Copilot CLI through Aperture

```bash
aperture   # pick GitHub Copilot and a model; it launches `copilot` with BYOK pointed at Aperture
```

`aperture` sets `COPILOT_PROVIDER_BASE_URL`, `COPILOT_PROVIDER_TYPE`, `COPILOT_MODEL`, and `COPILOT_OFFLINE=true`, so Copilot CLI needs no GitHub Copilot sign-in and no model API key. To launch it by hand:

```bash
COPILOT_OFFLINE=true \
COPILOT_PROVIDER_TYPE=anthropic \
COPILOT_PROVIDER_BASE_URL=http://<aperture-hostname> \
COPILOT_PROVIDER_API_KEY=not-needed \
COPILOT_MODEL=<provider>/<model> \
copilot
```

Prompt:

> Ship this app to production in my namespace, highly available. Follow the platform contract, then open a pull request.

Expect a `k8s/` directory containing a StatefulSet like `docs/reference/workshop-app.yaml`. The agent can check its work with `kubectl --server=http://kb-gke-dev -n dev-kartik get all`. Ask it to try `-n kube-system`; PAM refuses.

Commenting `/copilot <request>` on an issue runs the same agent in GitHub Actions through `.github/workflows/copilot.yml`, joined to the tailnet as `tag:ci-agent`.

## Step 6: Act 3, deploy

Merge the pull request. CI runs the tests, builds the image, and validates that every object in `k8s/` targets `dev-kartik`. `deploy.yml` then:

1. Builds and pushes `ghcr.io/<owner>/<repo>:<sha>`.
2. Joins the tailnet as an ephemeral `tag:ci-deployer` with GitHub OIDC.
3. Points kubectl at `http://kb-gke-dev` with empty credentials.
4. Substitutes the image into every workload in `k8s/`, applies the manifests, and waits for the rollout.

The GHCR package must be public, or the cluster needs pull credentials. After the first push, set the package's visibility in **Package settings**.

Open `https://workshop-app.<tailnet>.ts.net`. The "Served by" field names the replica that answered. Delete one pod with `kubectl --server=http://kb-gke-dev -n dev-kartik delete pod workshop-app-0` and reload; the other replica keeps the Service up.

## Step 7: Default deny, then team access

Before the access change:

- The author opens the Service URL and gets the app.
- The teammate's connection fails. Tailscale drops the traffic before the app sees it, so there is no HTTP 403.
- `kubectl --server=http://kb-gke-dev get pods -n kube-system` fails for everyone.

Open the team-access pull request in the policy repository (see its README). The pull request runs `action: test`; merging applies the exact file. Reload as the teammate. Revert the pull request to revoke access; the app and cluster are untouched.

## Repository protection

Protect `main` in both repositories: require pull requests, an approval, CODEOWNER review for workflows and policy, passing checks, and resolved conversations. Disable force pushes. Do not let the agent approve or merge its own change. Pin third-party actions to full commit SHAs before using this outside a workshop.

Pull requests opened by `copilot.yml` use `GITHUB_TOKEN`, so GitHub does not start CI on them automatically. Push an empty commit or re-run CI from the pull request.

## Cleanup

```bash
terraform -chdir=infra destroy
```

Then delete the PAM service `kb-gke-dev` and the connector in the admin console, and remove any leftover `workshop-app-*` machines.

## Troubleshooting

### Pods are not Ready

`kubectl --server=http://kb-gke-dev -n dev-kartik logs workshop-app-0`.

- `federated identity ... require`: the `tailscale` ConfigMap is missing `TS_CLIENT_ID`/`TS_AUDIENCE`, or the pod is not using the `workshop-app` ServiceAccount.
- `failed to exchange JWT`: the app trust credential's subject must be the Google service account's numeric unique ID. The Kubernetes ServiceAccount needs the `iam.gke.io/gcp-service-account` annotation, and the Google service account needs `roles/iam.workloadIdentityUser` for `PROJECT.svc.id.goog[dev-kartik/workshop-app]`.
- `service hosts must be tagged nodes`: `TS_TAG` is missing.
- The Service has hosts but never answers: `autoApprovers.services` must map `svc:workshop-app` to `tag:workshop-app`.

### kubectl through PAM is refused

- `Forbidden` naming `tag:ci-deployer@service.border0.com` or your login: PAM let the request through, and RBAC refused it. Check the `pam-edit` RoleBinding.
- Connection refused or timeout: the grant to `svc:kb-gke-dev` is missing, or the runner is not on the tailnet.

### The deploy cannot pull the image

Make the GHCR package public, or add an image pull secret to the namespace.

## Workshop runbook

See `docs/RUNBOOK.md` for the on-stage sequence and `docs/SETUP.md` for the rehearsal checklist.
