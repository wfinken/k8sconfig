#!/bin/zsh
# Creates a k3d cluster and bootstraps ArgoCD.
# Works with Docker Desktop and OrbStack (set: docker context use orbstack).
set -e
# Ensure Homebrew and /usr/local/bin tools (kubectl, k3d) are on PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verify Docker context is available
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running."
  echo "  Docker Desktop: start from Applications"
  echo "  OrbStack:       open OrbStack.app (or: brew install --cask orbstack)"
  echo "  Switch context: docker context use orbstack"
  exit 1
fi

echo "=== Creating k3d cluster ==="
k3d cluster create --config "$SCRIPT_DIR/k3d-config.yaml"

echo "=== Waiting for nodes ==="
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "=== Installing ArgoCD v3.4.2 ==="
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.2/manifests/install.yaml

echo "=== Waiting for ArgoCD server ==="
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "=== Bootstrapping ArgoCD ==="
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_SECRET="$SCRIPT_DIR/repo-secret.yaml"
if [ ! -f "$REPO_SECRET" ] && [ -f "$REPO_ROOT/secrets/repo-secret-cluster.yaml" ]; then
  echo "  Using secrets/repo-secret-cluster.yaml as bootstrap/repo-secret.yaml"
  REPO_SECRET="$REPO_ROOT/secrets/repo-secret-cluster.yaml"
fi
kubectl apply -f "$REPO_SECRET"
kubectl apply -f "$SCRIPT_DIR/root-app.yaml"

echo "=== Applying cloudflare secret ==="
CF_SECRET="$SCRIPT_DIR/cloudflare-secret.yaml"
if [ ! -f "$CF_SECRET" ] && [ -f "$REPO_ROOT/secrets/cloudflare-secret-cluster.yaml" ]; then
  echo "  Using secrets/cloudflare-secret-cluster.yaml as bootstrap/cloudflare-secret.yaml"
  CF_SECRET="$REPO_ROOT/secrets/cloudflare-secret-cluster.yaml"
fi
if [ -f "$CF_SECRET" ]; then
  kubectl apply -f "$CF_SECRET"
else
  echo "WARNING: No cloudflare secret found. Copy bootstrap/cloudflare-secret.example.yaml,"
  echo "fill in your token, then run: kubectl apply -f bootstrap/cloudflare-secret.yaml"
fi

echo "=== Applying app-data PVs and PVCs ==="
# These are managed outside ArgoCD to prevent accidental pruning of live data.
kubectl apply -f "$REPO_ROOT/manifests/app-data/pv.yaml"
kubectl apply -f "$REPO_ROOT/manifests/app-data/pvc.yaml"

echo "=== Restoring manually-managed secrets ==="
if [ -d "$(dirname "$SCRIPT_DIR")/secrets" ]; then
  bash "$SCRIPT_DIR/restore-secrets.sh"
else
  echo "SKIP: secrets/ directory not found — run backup-secrets.sh on the old cluster first,"
  echo "or apply grafana-admin and lidarr-api-key secrets manually after ArgoCD syncs."
fi

echo ""
echo "=== Bootstrap complete ==="
echo "ArgoCD will sync all apps automatically (~5-10 min)"
echo "Monitor: kubectl get applications -n argocd -w"
