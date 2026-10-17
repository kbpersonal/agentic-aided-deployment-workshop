# Live Runbook

1. Run the app on localhost and show the passing tests.
2. Run it with `TS_HOSTNAME=workshop-app-laptop`. Open the tailnet URL; the identity card shows you. The page is reachable only by you.
3. Show the platform contract in `.github/copilot-instructions.md`: one namespace, no cluster-scoped objects, no credentials.
4. Launch Copilot CLI through `aperture`. Point out that there is no model API key and no Copilot sign-in, only a tailnet grant to Aperture.
5. Ask Copilot to ship the app to production in your namespace, highly available, and open PR 1.
6. While the PR is open, have Copilot run `kubectl --server=http://kb-gke-dev -n dev-kartik get all`, then `-n kube-system`. PAM refuses the second.
7. Review PR 1: a StatefulSet, two replicas, and the pre-made ServiceAccount and ConfigMap. It has no Service, Ingress, Secret or credential.
8. Merge. Watch `deploy.yml` join the tailnet as an ephemeral `tag:ci-deployer` over GitHub OIDC and apply through PAM.
9. Open `https://workshop-app.<tailnet>.ts.net` as the author. "Served by" names the replica your client picked; clients stay on one healthy host.
10. Delete `workshop-app-0` through PAM and reload. The Service stays up.
11. Try the URL as the teammate. The connection is dropped before it reaches the app.
12. Open PR 2 in the policy repository to add the teammate to `group:workshop-team` and to the Service grant. Show the `action: test` run.
13. Merge PR 2. Reload as the teammate; the app appears with their identity.
14. Revert PR 2 and show that access is gone while the app keeps running.
