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
ss -ltn 2>/dev/null | awk 'NR>1{print $4}' | grep -oE ':(3001|11434|8080|8000|4000|5001|3113|80|443|8087|18099)$' | sort -u | sed 's/^/  /'
echo

echo "--- credential locations (mode only, never values) ---"
for f in \
  "$HOME/hd2stack-anythingllm/.api-key" \
  "$HOME/hd2stack-anythingllm/.auth-token" \
  "$HOME/.config/unsplash/credentials" \
  "$HOME/agent-work/core-distro-saas-clean/staged-export-test/config/database.php" \
  "$HOME/agent-work/core-distro-saas-clean/staged-export-test/config/app.php" \
  "$HOME/agent-work/core-distro-saas-clean/staged-export-test/config/rapidapi.php"
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

echo "--- core saas canonical source (read-only to firstmate) ---"
cat <<'EOF'
  repo            /home/hd2admin/agent-work/core-distro-saas-clean  (origin DeightonLLM/core-distro-saas-clean)
  editable source repo/staged-export-test/   <- the file the tests exercise
  runtime config  repo/staged-export-test/config/{database.php,app.php,rapidapi.php}
                  GITIGNORED and ABSENT on this host: they come from the deployment
                  secret store. rapidapi.php carries RAPIDAPI_KEY + RAPIDAPI_HOST and
                  is the ONLY source of the lead-provider credential. maps_proxy.php
                  consumes it. A fresh clone or export zip CANNOT boot without them.
  export zips     lead-engine-saas-export-20261019_canonical-geo.zip  (current: 0 .sql files)
                  lead-engine-saas-export-20260625_canonical-geo.zip  (has all 6 installer .sql files)
                  install.php loads 6 geo SQL files that the current zip no longer ships.
EOF
echo

echo "--- core saas disposable fixture recipe (self-contained, safe to recreate) ---"
cat <<'EOF'
  scripts   /home/hd2admin/kun-agent-workspace/data/2026-10-19/core-saas-handoff/fixture-{up,seed,load-geo}.sh
  db        container coredist-handoff-db   image mariadb:11.4
  web       container coredist-handoff-web  image mm-php81-pdo-mysql:local
  network   coredist-handoff-net
  url       http://127.0.0.1:18099   (bind 127.0.0.1 only)
  app copy  /tmp/coredist-handoff-fixture/app   (scratch copy; the repo is never mounted)
  NOTE      mm-php81-pdo-mysql:local is the only local image with pdo_mysql.
            wordpress:php8.3-apache has Apache but NO pdo_mysql -> use the PHP built-in server.
  teardown  docker rm -f coredist-handoff-web coredist-handoff-db; docker network rm coredist-handoff-net
  NEVER touch the live staging pair: core-distro-stage-wordpress-1 / core-distro-stage-database-1
EOF
echo

echo "--- browser tooling ---"
cat <<'EOF'
  chrome-devtools-axi   global npm (chrome-devtools-axi@0.1.35); sanctioned browser tool
    page.click("selector") -> el.click(), a DOM click that BYPASSES overlay hit-testing
    page.click("@uid")     -> real mouse event, RESPECTS hit-testing (use for overlay tests)
    sessions: CHROME_DEVTOOLS_AXI_SESSION=<name> for isolation
  google-chrome          /usr/bin/google-chrome (155.0.8059.39)
  playwright             browser binaries cached in ~/.cache/ms-playwright, npm module NOT installed
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