#!/bin/zsh
# Re-applies secrets exported by backup-secrets.sh to the new cluster.
# Run this after setup.sh has brought up ArgoCD and the namespaces exist.
set -e
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="$REPO_ROOT/secrets"

apply_if_exists() {
  local file="$1"
  if [ -f "$SECRETS_DIR/$file" ]; then
    echo "  Applying secrets/$file"
    kubectl apply -f "$SECRETS_DIR/$file"
  else
    echo "  SKIP (not found): secrets/$file"
  fi
}

echo "=== Waiting for required namespaces ==="
for ns in default media argocd cert-manager; do
  kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/"$ns" --timeout=120s 2>/dev/null || \
    kubectl create namespace "$ns" 2>/dev/null || true
done

echo ""
echo "=== Restoring secrets ==="
apply_if_exists grafana-admin.yaml
apply_if_exists lidarr-api-key.yaml

# These overlap with bootstrap secrets; only apply if bootstrap files are missing.
if [ ! -f "$REPO_ROOT/bootstrap/repo-secret.yaml" ]; then
  apply_if_exists repo-secret-cluster.yaml
fi
if [ ! -f "$REPO_ROOT/bootstrap/cloudflare-secret.yaml" ]; then
  apply_if_exists cloudflare-secret-cluster.yaml
fi

echo ""
echo "=== Restore complete ==="
