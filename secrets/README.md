# secrets/

This directory holds cluster secrets that are **not managed by Git**.

All `*.yaml` and `*.json` files here are gitignored.  
Only this `README.md` is committed.

## Contents (after running backup-secrets.sh)

| File | Secret | Namespace |
|------|--------|-----------|
| `grafana-admin.yaml` | Grafana admin username + password | `default` |
| `lidarr-api-key.yaml` | Lidarr API key used by the lidarr-scan CronJob | `media` |
| `repo-secret-cluster.yaml` | ArgoCD GitHub PAT (fallback if bootstrap/repo-secret.yaml is missing) | `argocd` |
| `cloudflare-secret-cluster.yaml` | Cloudflare API token for cert-manager DNS-01 (fallback) | `cert-manager` |

## Workflow

```sh
# Before teardown — on the OLD cluster:
bootstrap/backup-secrets.sh

# After new cluster is up:
bootstrap/setup.sh   # calls restore-secrets.sh automatically
```

The `bootstrap/cloudflare-secret.yaml` and `bootstrap/repo-secret.yaml` files
(also gitignored) remain the canonical source for those two secrets.
