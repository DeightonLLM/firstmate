#!/usr/bin/env bash
# Repair secondmate endpoint records that claim tmux while the live surface is Herdr.
#
# Symptom this fixes: every fm-send to a secondmate fails with
#   "tmux send failed" / "text not sent to default:w2X:p2"
# while `herdr workspace list` shows the pane alive and idle. The meta records a
# tmux-style window id, so fm-send routes to tmux, which no longer owns the pane.
#
# Idempotent. Rewrites only records that are missing backend= or disagree with the
# live Herdr workspace. Never touches a record that is already consistent.
set -u

FM_HOME="${FM_HOME:?FM_HOME must be set}"
STATE="$FM_HOME/state"
fixed=0; skipped=0; missing=0

# map secondmate id -> herdr workspace id, discovered live, never hardcoded
declare -A WS
while IFS='|' read -r id wid; do
  [ -n "${id:-}" ] && WS["$id"]="$wid"
done < <(herdr workspace list 2>/dev/null | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for w in d.get("result",{}).get("workspaces",[]):
    label=(w.get("label") or "")
    for pfx in ("2ndmate-","fm-"):
        if label.startswith(pfx):
            print(label[len(pfx):].split("·")[0].strip()+" | "+w.get("workspace_id",""))
            break
')

for meta in "$STATE"/*.meta; do
  [ -e "$meta" ] || continue
  id=$(basename "$meta" .meta)
  [ -n "${WS[$id]:-}" ] || { skipped=$((skipped+1)); continue; }

  wid="${WS[$id]}"
  if grep -q '^backend=herdr$' "$meta" && grep -q "^herdr_workspace_id=$wid$" "$meta"; then
    skipped=$((skipped+1)); continue
  fi

  pane=$(herdr tab list 2>/dev/null | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
for t in d.get('result',{}).get('tabs',[]):
    if t.get('workspace_id')=='''$wid''':
        print(t.get('tab_id','t1')); break
" | head -1)
  pane="${pane:-$wid:t2}"

  cp -n "$meta" "$meta.bak-$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

  # drop any stale backend/herdr keys, then write the correct endpoint
  grep -vE '^(backend|herdr_session|herdr_workspace_id|herdr_tab_id|herdr_pane_id|window)=' "$meta" > "$meta.tmp"
  {
    echo "backend=herdr"
    echo "window=default:$pane"
    echo "herdr_session=default"
    echo "herdr_workspace_id=$wid"
    echo "herdr_tab_id=${pane%%:*}:t2"
    echo "herdr_pane_id=$pane"
  } >> "$meta.tmp"
  mv "$meta.tmp" "$meta"
  echo "  fixed: $id -> backend=herdr workspace=$wid pane=$pane"
  fixed=$((fixed+1))
done

echo "secondmate endpoint repair: fixed=$fixed skipped=$skipped missing=$missing"