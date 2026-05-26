#!/bin/zsh
# Exports live cluster secrets that are NOT stored in Git to secrets/ (gitignored).
# Run this BEFORE tearing down the cluster.
set -e
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="$REPO_ROOT/secrets"
mkdir -p "$SECRETS_DIR"

dump_secret() {
  local ns="$1" name="$2" outfile="$3"
  echo "  Exporting $ns/$name → secrets/$outfile"
  kubectl get secret "$name" -n "$ns" -o json | python3 -c "
import sys, json
s = json.load(sys.stdin)
name = s['metadata']['name']
ns   = s['metadata']['namespace']
stype = s.get('type', 'Opaque')
data  = s.get('data', {})
lines = [
    'apiVersion: v1',
    'kind: Secret',
    'metadata:',
    '  name: ' + name,
    '  namespace: ' + ns,
    'type: ' + stype,
    'data:',
]
for k, v in data.items():
    lines.append('  ' + k + ': ' + v)
print('\n'.join(lines))
" > "$SECRETS_DIR/$outfile"
}

echo "=== Backing up cluster secrets to $SECRETS_DIR ==="

dump_secret default       grafana-admin                grafana-admin.yaml
dump_secret media         lidarr-api-key               lidarr-api-key.yaml
dump_secret media         slskd-credentials            slskd-credentials.yaml
dump_secret argocd        repo-k8sconfig               repo-secret-cluster.yaml
dump_secret cert-manager  cloudflare-api-token-secret  cloudflare-secret-cluster.yaml

echo ""
echo "=== Checking bootstrap secrets ==="
for f in repo-secret.yaml cloudflare-secret.yaml; do
  if [ -f "$REPO_ROOT/bootstrap/$f" ]; then
    echo "  OK: bootstrap/$f exists"
  else
    echo "  MISSING: bootstrap/$f — copy the .example and fill in credentials"
  fi
done

echo ""
echo "=== Backup complete ==="
echo "Secrets saved to $SECRETS_DIR (gitignored)."
echo "Next: bootstrap/restore-secrets.sh after the new cluster is running."
