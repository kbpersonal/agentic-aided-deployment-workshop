# Platform contract for this repository

The platform team has given this application one Kubernetes namespace, `dev`, in a private GKE cluster. Nothing outside that namespace is reachable.

## Cluster access

`./kubeconfig` in this repository points at the cluster through Tailscale PAM (`http://gke-dev`). It contains no credentials: your Tailscale identity is the credential, and it only works in `dev`. Use it for every `kubectl` command:

```bash
KUBECONFIG=./kubeconfig kubectl get pods
```

## Sharing the app from the laptop

To share the locally running app with the team, run exactly:

```bash
tailscale serve --bg 3000
```

Flags go before the port, and `--bg` keeps it running after the command returns, so do not add `&`. It prints `https://<laptop>.<tailnet>.ts.net`; give that URL to the developer. Serve publishes the app as the developer's own device, so it needs no tag, auth key, or `--service`. Who can open the URL is decided by the tailnet policy, not by Serve. Do not run `tailscale serve reset`, `tailscale funnel`, or `tailscale up`.

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

Create a branch, commit the manifests, and `git push -u origin <branch>`. The push prints a link to open the pull request; give that link to the developer, who opens and merges it. Do not merge anything yourself.

CI runs `npm test`, builds the image, and checks `k8s/`. After merge, `.github/workflows/deploy.yml` joins the tailnet as `tag:ci-deployer` and applies `k8s/` through the same `./kubeconfig`. Do not edit the workflows.
