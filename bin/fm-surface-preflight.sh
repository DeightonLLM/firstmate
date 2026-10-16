#!/usr/bin/env bash
# Scoped surface search. Run this BEFORE escalating any "I need X / where is Y" to the Captain.
# Usage: bin/fm-surface-preflight.sh [keywords...]
# Prints candidate local answers. Prints nothing sensitive.
set -u

KW=("$@")
if [ ${#KW[@]} -eq 0 ]; then
  echo "usage: fm-surface-preflight.sh <keyword> [keyword...]"
  exit 2
fi

PAT=$(printf '%s|' "${KW[@]}"); PAT="${PAT%|}"
echo "=== surface preflight: ${KW[*]} ==="

# 1. containers
echo "--- containers ---"
docker ps --format '{{.Names}}|{{.Image}}|{{.Ports}}' 2>/dev/null \
  | grep -iE "$PAT" || echo "  no container match"

# 2. listening ports
echo "--- ports ---"
ss -ltn 2>/dev/null | awk 'NR>1{print $4}' | sort -u | head -20 | sed 's/^/  /'

# 3. credential files that EXIST (name only, never contents)
echo "--- credential files present (names and modes only) ---"
find "$HOME" -maxdepth 4 \( -name '.api-key' -o -name '.auth-token' -o -name '.env' \
     -o -name 'credentials' -o -name '*.token' -o -name 'id_*' \) -type f 2>/dev/null \
  | head -15 | while read -r f; do printf '  %-58s mode %s\n' "$f" "$(stat -c '%a' "$f" 2>/dev/null)"; done

# 4. local keyword hits in operator-owned config areas
echo "--- local config hits ---"
grep -rilsE "$PAT" "$HOME/hd2stack-anythingllm" "$HOME/bin" 2>/dev/null | head -8 | sed 's/^/  /'

# 5. project-local docs mentioning it
echo "--- firstmate docs mentioning it ---"
grep -rilsE "$PAT" /home/hd2admin/kun-agent-workspace/docs 2>/dev/null | head -5 | sed 's/^/  /'

# 6. reachable staging host, non-mutating
echo "--- staging host (read-only) ---"
if [ -r "$HOME/.ssh/known_hosts.elevates" ]; then
  ssh -o BatchMode=yes -o ConnectTimeout=8 \
      -o UserKnownHostsFile="$HOME/.ssh/known_hosts.elevates" \
      root@100.69.211.43 \
      "find /root /opt -maxdepth 3 -iname '*${KW[0]}*' 2>/dev/null | head -8; \
       docker ps --format '{{.Names}}|{{.Image}}' 2>/dev/null | grep -iE '$PAT' | head -5" 2>/dev/null | sed 's/^/  /' \
    || echo "  ssh unavailable"
else
  echo "  no known_hosts file"
fi

echo
echo "If the answer is above, do not ask the Captain. If not: L2 targeted dig, then L3 Crisp-R, then L4."