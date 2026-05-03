# k8sconfig

GitOps source of truth for the local minikube cluster, driven by ArgoCD.

## Layout

- `bootstrap/` — one-time install: repo credentials Secret + root Application
- `apps/` — child Applications (one file per managed app)
- `grafana/`, `haproxy-ingress/` — Helm values overrides per app
- `manifests/` — placeholder for future Kustomize-based apps

ArgoCD watches `apps/` (app-of-apps). Adding a new `apps/<name>.yaml` and
pushing makes ArgoCD create that Application automatically.

## First-time bootstrap

```sh
# 1. Push this repo
git init -b main && git add . && git commit -m "Initial GitOps scaffold"
git remote add origin https://github.com/wfinken/k8sconfig.git
git push -u origin main

# 2. Create a fine-grained GitHub PAT (Contents: Read-only, Metadata: Read-only)
#    Copy bootstrap/repo-secret.example.yaml to bootstrap/repo-secret.yaml
#    and paste the PAT into the `password` field. The .yaml file is gitignored.

# 3. Register the repo with ArgoCD
kubectl apply -f bootstrap/repo-secret.yaml

# 4. Apply the root Application — this kicks off the whole tree
kubectl apply -f bootstrap/root-app.yaml
```

## Open the ArgoCD UI

```sh
kubectl -n argocd port-forward svc/argocd-server 8080:443
# https://localhost:8080  (accept self-signed cert)

# Initial admin password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Username: `admin`. Change the password in **User Info → Update Password**
after first login.

In the UI:
- **Settings → Repositories** — verify `github.com/wfinken/k8sconfig` is
  reachable.
- **Applications** — `root` should appear and fan out to `grafana` and
  `haproxy-ingress`. All three should reach **Synced / Healthy**.

## Adopted releases

The `grafana` and `haproxy-ingress` Applications match the existing Helm
release names (`grafana-1777830317`, `kubernetes-ingress-1777830932`) so
ArgoCD takes them over in place — no pod recreation expected.

| App     | Chart                          | Version | Namespace |
|---------|--------------------------------|---------|-----------|
| grafana | grafana/grafana                | 10.5.15 | default   |
| haproxy | haproxytech/kubernetes-ingress | 1.49.0  | default   |
