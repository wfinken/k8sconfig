# k8sconfig

GitOps source of truth for the local k3s cluster, driven by ArgoCD.

## Layout

- `bootstrap/` — one-time install: repo credentials Secret + root Application
- `apps/` — child Applications (one file per managed app)
- `grafana/`, `prometheus/` — Helm values overrides per app
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
- **Applications** — `root` should appear and fan out to `grafana`, `prometheus`, etc.
  All should reach **Synced / Healthy**.

## Migrating to OrbStack (from Docker Desktop)

OrbStack is a drop-in Docker Desktop replacement. k3d works unchanged on it.

### Why k3d-on-OrbStack (not OrbStack's built-in Kubernetes)

- Port 53 (Technitium DNS) would conflict with OrbStack's internal DNS resolver
- The cluster uses 1 server + 1 agent node; OrbStack k8s is single-node only
- All `hostPath` PVs point to `/Volumes/Storage` — OrbStack auto-mounts macOS
  volumes, so paths are identical

### Migration steps

```sh
# 1. Export secrets from the RUNNING cluster (Docker Desktop)
bash bootstrap/backup-secrets.sh

# 2. Install OrbStack
brew install --cask orbstack
# Open OrbStack.app — it prompts to replace Docker Desktop

# 3. Switch Docker context (if Docker Desktop is still installed)
docker context use orbstack

# 4. Delete the old k3d cluster
k3d cluster delete homecluster

# 5. (Optional) Quit / uninstall Docker Desktop

# 6. Bring up the new cluster — also restores secrets automatically
bash bootstrap/setup.sh
```

### Port forwarding

The k3d loadbalancer binds these ports on localhost (same as Docker Desktop):

| Port | Protocol | App |
|------|----------|-----|
| 80 | TCP | HTTP (Traefik) |
| 443 | TCP | HTTPS (Traefik) |
| 53 | TCP+UDP | DNS (Technitium) |
| 2234 | TCP | Soulseek (slskd) |

### Volume access

All PVs use `hostPath` on `/Volumes/Storage`, which k3d bind-mounts into every
node. OrbStack inherits macOS volume mounts automatically — no extra file-sharing
config needed.

### TLS SAN

`k3d-config.yaml` sets `--tls-san=192.168.2.20`. If your local IP changes,
update that field and recreate the cluster.

---

## Adopted releases

The `grafana` and `prometheus` Applications match the existing Helm
release names so ArgoCD takes them over in place.

| App        | Chart                                | Version | Namespace  |
|------------|--------------------------------------|---------|------------|
| grafana    | grafana/grafana                      | 10.5.15 | default    |
| prometheus | prometheus-community/prometheus      | 84.5.0  | monitoring |
