# Platform contract for this repository

The platform team has given this application one Kubernetes namespace, `dev-kartik`, in a private GKE cluster. Nothing outside that namespace is reachable.

## What already exists in `dev-kartik`

- ServiceAccount `workshop-app`. It is bound to a Google service account through GKE Workload Identity and may read and write Secrets and Events in the namespace, which is what tsnet needs to keep its state.
- ConfigMap `tailscale` with `TS_CLIENT_ID`, `TS_AUDIENCE`, `TS_TAG`, and `TS_SERVICE`. With those set, the app joins the tailnet through workload identity federation; no auth key exists anywhere.

## How the app runs in production

The binary in this repository is a tsnet program. When `TS_HOSTNAME` is set it joins the tailnet as its own device. When `TS_SERVICE` is also set, it advertises that Tailscale Service instead, so several replicas can serve one name.

Additional environment it reads:

| Variable | Purpose |
| --- | --- |
| `TS_HOSTNAME` | Tailnet device name. Must be unique per replica, so use the pod name. |
| `TS_STATE` | `kube:<secret-name>` keeps the node identity and TLS certificate in a Secret. Use one Secret per replica, named after the pod. |
| `TS_STATE_DIR` | Writable directory for tsnet runtime files. |
| `POD_NAME` | Required by the Secret state store. |
| `HEALTH_ADDR` | Optional pod-network address, for example `:8080`, that serves only `GET /health` once the tailnet listener is up. Use it for readiness probes. |

## Deployment rules

- Put Kubernetes manifests in `k8s/`. Every object goes in namespace `dev-kartik`.
- Do not create Namespaces, ServiceAccounts, Roles, RoleBindings, ClusterRoles, Ingresses, or `Service` objects of type `LoadBalancer` or `NodePort`. Reachability comes from the Tailscale Service, not from Kubernetes networking.
- Use a StatefulSet or a Deployment with at least two replicas. Each workload has exactly one container.
- The deploy workflow replaces every container image with the image it built from the merged commit. Use `ghcr.io/kbpersonal/agentic-aided-deployment-workshop:latest` as a placeholder.
- The container runs as a non-root user with a read-only root filesystem, no privilege escalation, and all capabilities dropped. Mount an `emptyDir` for `TS_STATE_DIR`.
- Set CPU and memory requests. The cluster is GKE Autopilot.

## Shipping

Open a pull request. CI runs `go test ./...` and builds the image. After merge, `.github/workflows/deploy.yml` joins the tailnet as `tag:ci-deployer` and applies `k8s/` through the Tailscale PAM Kubernetes service `kb-gke-dev`. Do not edit the workflows.

To inspect the namespace from a developer machine on the tailnet, use the PAM service directly: `kubectl --server=http://kb-gke-dev -n dev-kartik get pods`. No kubeconfig credentials are needed; Tailscale identity is the credential.
