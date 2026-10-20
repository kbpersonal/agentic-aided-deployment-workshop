# Live Runbook

1. Run the app on localhost with `npm start` and show the passing tests.
2. Run `tailscale serve --bg 3000` and open the tailnet URL. The identity card shows you.
3. As the teammate, open the same URL. The connection fails.
4. Open the policy pull request that shares your devices with `group:workshop-team` (or ask the agent to). Merge it; the teammate gets in with their own identity.
5. Show the platform contract in `.github/copilot-instructions.md` and the credential-free `./kubeconfig`.
6. Run `aperture copilot` and pick a model. Point out that there is no model API key and no Copilot sign-in, only a tailnet grant to Aperture. `aperture copilot --debug` shows the variables it set.
7. Ask Copilot to ship the app to your dev namespace, highly available and reachable on the tailnet, and open a pull request.
8. While it works, have it run `KUBECONFIG=./kubeconfig kubectl get all`, then `-n kube-system`. PAM refuses the second.
9. Review the pull request: a Deployment, a Service, and a Tailscale Ingress on the `dev-ingress` ProxyGroup. No credentials, no load balancer.
10. Merge. Watch `deploy.yml` join the tailnet as an ephemeral `tag:ci-deployer` over GitHub OIDC and apply through PAM.
11. Show the Aperture dashboard: the agent's requests, attributed to your identity.
12. Open `https://workshop-app.<tailnet>.ts.net` as the author.
13. As the teammate, try it. The connection fails.
14. Open the policy pull request adding `group:workshop-team` to the `svc:workshop-app` grant. Merge it, and the teammate gets in.
15. Revert it and show that access is gone while the app keeps running.
