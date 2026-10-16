#!/usr/bin/env bash
# Surface inventory: every known service, path, port and credential location on this host.
# Exists so no one has to ask the Captain for something already on disk.
# Prints facts only. Never prints a secret value — location and mode only.
set -u

echo "=== SURFACE INVENTORY ==="
echo "host: $(hostname)  user: $(id -un)  generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

echo "--- containers ---"
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}' 2>/dev/null | sed 's/^/  /'
echo

echo "--- listening ports of interest ---"
ss -ltn 2>/dev/null | awk 'NR>1{print $4}' | grep -oE ':(3001|11434|8080|8000|4000|5001|3113|80|443)$' | sort -u | sed 's/^/  /'
echo

echo "--- credential locations (mode only, never values) ---"
for f in \
  "$HOME/hd2stack-anythingllm/.api-key" \
  "$HOME/hd2stack-anythingllm/.auth-token" \
  "$HOME/.config/unsplash/credentials"
do
  if [ -e "$f" ]; then
    printf '  %-46s mode %s\n' "$f" "$(stat -c '%a' "$f" 2>/dev/null)"
  else
    printf '  %-46s ABSENT\n' "$f"
  fi
done
echo

echo "--- app sources on the staging host ---"
cat <<'EOF'
  core-distro app    root@100.69.211.43 : "/root/core distro brNDON EDIT/Core Distro Web"
  deploy script      root@100.69.211.43 : /root/bin/deploy-core-distro-staging
  staging root      root@100.69.211.43 : /opt/core-distro-staging
  ssh known_hosts   local             : /home/hd2admin/.ssh/known_hosts.elevates
EOF
echo

echo "--- anythingllm workspaces ---"
K=$(cat "$HOME/hd2stack-anythingllm/.api-key" 2>/dev/null)
if [ -n "$K" ]; then
  curl -sS --max-time 12 -H "Authorization: Bearer $K" \
    http://127.0.0.1:3001/api/v1/workspaces 2>/dev/null \
  | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin); ws=d.get('workspaces',d)
    for w in (ws if isinstance(ws,list) else []):
        print('  %-28s docs=%s' % (str(w.get('name'))[:28], len(w.get('documents',[]))))
except Exception as e:
    print('  parse failed:', e)
"
else
  echo "  no api key readable"
fi
echo

echo "--- host aliases (identity precedence) ---"
cat <<'EOF'
  srv1137994 = elevatesVPS = elevatesci-vps = animovps   (Core staging + Elevate + Aminolifesciences)
  KVM1 = HD2 main WordPress site (NOT Core staging)
EOF