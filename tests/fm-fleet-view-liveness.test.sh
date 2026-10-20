#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
mkdir -p "$TMP/home/state" "$TMP/home/data" "$TMP/home/config" "$TMP/bin"
cat > "$TMP/home/state/ghost.meta" <<'EOF'
kind=ship
backend=tmux
window=missing:1
project=fixture
EOF
cat > "$TMP/home/state/dead-agent.meta" <<'EOF'
kind=ship
backend=tmux
window=dead:1
project=fixture
EOF
cat > "$TMP/home/state/unreadable.meta" <<'EOF'
kind=ship
backend=tmux
window=unknown:1
project=fixture
EOF
cat > "$TMP/home/state/live.meta" <<'EOF'
kind=ship
backend=tmux
window=alive:1
project=fixture
EOF
cat > "$TMP/bin/tmux" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  display-message)
    case "$*" in
      *pane_current_command*)
        case "$*" in *alive:1*) printf 'pi\n' ;; *) printf 'bash\n' ;; esac
        exit 0
        ;;
      *dead:1*) printf '%%1\n'; exit 0 ;;
      *) printf "can't find pane\n" >&2; exit 1 ;;
    esac
    ;;
  list-windows)
    case "$*" in
      *unknown*) printf 'server unavailable\n' >&2; exit 1 ;;
      *dead*|*alive*) printf '1\n' ;;
    esac
    exit 0
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TMP/bin/tmux"

OUTPUT=$(PATH="$TMP/bin:$PATH" FM_HOME="$TMP/home" FM_ROOT_OVERRIDE="$ROOT" \
  FM_STATE_OVERRIDE="$TMP/home/state" FM_DATA_OVERRIDE="$TMP/home/data" \
  FM_CONFIG_OVERRIDE="$TMP/home/config" FM_PROJECTS_OVERRIDE="$TMP/home/projects" \
  "$ROOT/bin/fm-fleet-view.sh")

if printf '%s\n' "$OUTPUT" | awk '/## Under Way/{underway=1; next} /^## /{underway=0} underway && /\| ghost \|/ {found=1} END {exit !found}'; then
  printf 'FAIL: stale task ghost appeared in Under Way\n%s\n' "$OUTPUT"
  exit 1
fi
if ! printf '%s\n' "$OUTPUT" | grep -Fq '## Stale - metadata without a live endpoint'; then
  printf 'FAIL: stale section missing\n%s\n' "$OUTPUT"
  exit 1
fi
if ! printf '%s\n' "$OUTPUT" | awk '/## Stale - metadata without a live endpoint/{stale=1} /^## / && !/## Stale - metadata without a live endpoint/{if (stale) exit !found} stale && /\| ghost \|/ {found=1} END {exit !found}'; then
  printf 'FAIL: ghost missing from stale section\n%s\n' "$OUTPUT"
  exit 1
fi
if ! printf '%s\n' "$OUTPUT" | awk '/## Stale - metadata without a live endpoint/{stale=1} /^## / && !/## Stale - metadata without a live endpoint/{if (stale) exit !dead_found} stale && /\| dead-agent \|/ && /\| absent \|/ {dead_found=1} END {exit !dead_found}'; then
  printf 'FAIL: dead agent was rendered as present or missing from stale section\n%s\n' "$OUTPUT"
  exit 1
fi
if ! printf '%s\n' "$OUTPUT" | awk '/## Under Way/{underway=1; next} /^## /{underway=0} underway && /\| live \|/ && /\| present \|/ {found=1} END {exit !found}'; then
  printf 'FAIL: live task missing from Under Way\n%s\n' "$OUTPUT"
  exit 1
fi
if ! printf '%s\n' "$OUTPUT" | awk '/## Liveness Unknown/{unknown=1; next} /^## /{unknown=0} unknown && /\| unreadable \|/ && /\| unknown \|/ {found=1} END {exit !found}'; then
  printf 'FAIL: unreadable probe missing from unknown section\n%s\n' "$OUTPUT"
  exit 1
fi
JSON=$(PATH="$TMP/bin:$PATH" FM_HOME="$TMP/home" FM_ROOT_OVERRIDE="$ROOT" \
  FM_STATE_OVERRIDE="$TMP/home/state" FM_DATA_OVERRIDE="$TMP/home/data" \
  FM_CONFIG_OVERRIDE="$TMP/home/config" FM_PROJECTS_OVERRIDE="$TMP/home/projects" \
  "$ROOT/bin/fm-fleet-snapshot.sh" --json)
printf '%s\n' "$JSON" | jq -e '
  .schema == "fm-fleet-snapshot.v1"
  and ([.tasks[] | select(.id == "ghost")][0].liveness.status == "stale")
  and ([.tasks[] | select(.id == "ghost")][0].endpoint.exists == false)
  and ([.tasks[] | select(.id == "dead-agent")][0].liveness.status == "stale")
  and ([.tasks[] | select(.id == "dead-agent")][0].endpoint.exists == true)
  and ([.tasks[] | select(.id == "unreadable")][0].liveness.status == "unknown")
  and ([.tasks[] | select(.id == "unreadable")][0].endpoint.exists == null)
  and ([.tasks[] | select(.id == "live")][0].liveness.status == "live")
' >/dev/null
printf 'PASS: stale metadata excluded from Under Way and shown in Stale; dead agent not rendered present\n'
