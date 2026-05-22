#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Creating k3d cluster ==="
k3d cluster create --config "$SCRIPT_DIR/k3d-config.yaml"

echo "=== Waiting for nodes ==="
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "=== Installing ArgoCD v3.4.2 ==="
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.4.2/manifests/install.yaml

echo "=== Waiting for ArgoCD server ==="
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s

echo "=== Bootstrapping ArgoCD ==="
kubectl apply -f "$SCRIPT_DIR/repo-secret.yaml"
kubectl apply -f "$SCRIPT_DIR/root-app.yaml"

echo "=== Applying cloudflare secret ==="
if [ -f "$SCRIPT_DIR/cloudflare-secret.yaml" ]; then
  kubectl apply -f "$SCRIPT_DIR/cloudflare-secret.yaml"
else
  echo "WARNING: cloudflare-secret.yaml not found."
  echo "Copy bootstrap/cloudflare-secret.example.yaml to bootstrap/cloudflare-secret.yaml,"
  echo "fill in your token, then run:"
  echo "  kubectl apply -f \$SCRIPT_DIR/cloudflare-secret.yaml"
fi

echo ""
echo "=== Bootstrap complete ==="
echo "ArgoCD will sync all apps automatically (~5-10 min)"
echo "Monitor: kubectl get applications -n argocd -w"
