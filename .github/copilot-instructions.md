# Platform contract for this repository

The platform team has given this application one Kubernetes namespace, `dev`, in an AKS cluster. Nothing outside that namespace is reachable.

## Cluster access

The kubeconfig context `aks-dev` points at the cluster through Tailscale PAM (`http://aks-dev`). It contains no credentials: your Tailscale identity is the credential, and it only works in `dev`. Pass it on every `kubectl` command, so another selected context is never used:

```bash
kubectl --context aks-dev get pods
```

## Sharing the app from the laptop

To share the locally running app with the team, run exactly:

```bash
tailscale serve --bg 3000
```

Flags go before the port, and `--bg` keeps it running after the command returns, so do not add `&`. It prints `https://<laptop>.<tailnet>.ts.net`; give that URL to the developer. Serve publishes the app as the developer's own device, so it needs no tag, auth key, or `--service`. Who can open the URL is decided by the tailnet policy, not by Serve. Do not run `tailscale serve reset`, `tailscale funnel`, or `tailscale up`.

## Access changes

Who can reach what is decided by `policy/policy.hujson`, the tailnet policy file. Change it only through a pull request, and only the `grants` you are asked to change. Never edit `tagOwners`, `autoApprovers`, or `tests`, and never apply the policy yourself: `.github/workflows/policy.yml` tests the pull request and applies it on merge.

- To let the team open apps shared from the laptop with `tailscale serve`, add this grant:

  ```jsonc
  {
    "src": ["autogroup:member"],
    "dst": ["autogroup:admin"],
    "ip":  ["tcp:443"],
  },
  ```

- To let the team open the app deployed in the cluster, change the `src` of the grant whose `dst` is `["svc:workshop-app", "tag:k8s-dev"]` from `["autogroup:admin"]` to `["autogroup:member"]`.

Open the pull request as described under Shipping.

## How the app runs in production

The app is a Node.js HTTP server. `npm start` listens on `HOST:PORT` (the container sets `0.0.0.0:3000`). `GET /health` returns `200` when it is ready. It reads the `Tailscale-User-*` headers that the Tailscale Ingress adds, so it must only be reached through that Ingress.

The cluster runs the Tailscale Kubernetes operator with an ingress ProxyGroup named `dev-ingress`. Exposing the app on the tailnet means creating an `Ingress` for it on that ProxyGroup. The operator turns it into the Tailscale Service `svc:<name>`, served at `https://<name>.<tailnet>.ts.net` by every ProxyGroup replica.

## Deployment rules

- Put Kubernetes manifests in `k8s/`. Every object goes in namespace `dev`.
- Run the app as a `Deployment` with at least two replicas and exactly one container listening on port `3000`. Use `GET /health` for readiness and liveness probes.
- Put a `ClusterIP` `Service` in front of it.
- Expose it with an `Ingress` named after the app, with:
  - `ingressClassName: tailscale`
  - annotations `tailscale.com/proxy-group: dev-ingress` and `tailscale.com/tags: tag:k8s-dev`
  - `spec.tls[0].hosts: [workshop-app]`, which sets the Tailscale Service name
  - one rule sending `/` (`pathType: Prefix`) to the `Service` on port 80
- Do not create Namespaces, ServiceAccounts, Roles, RoleBindings, ClusterRoles, or `Service` objects of type `LoadBalancer` or `NodePort`.
- The deploy workflow replaces every container image with the image it built from the merged commit. Use `ghcr.io/OWNER/REPO:latest` as a placeholder.
- The container runs as a non-root user (uid 1000), with a read-only root filesystem, no privilege escalation, and all capabilities dropped.
- Set CPU and memory requests.

## Shipping

Create a branch, commit the change, `git push -u origin <branch>`, and open a pull request with `gh pr create --fill`. Give the pull request URL to the developer, who reviews and merges it. Do not approve or merge anything yourself.

CI runs `npm test`, builds the image, and checks `k8s/`. After merge, `.github/workflows/deploy.yml` joins the tailnet as `tag:ci-deployer` and applies `k8s/` through `./kubeconfig`, which points at the same `aks-dev` PAM service. Do not edit the workflows.
