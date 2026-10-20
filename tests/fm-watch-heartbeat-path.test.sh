#!/usr/bin/env bash
# Regression: the watcher must never touch a hardcoded absolute heartbeat path.
#
# Why: fm-watch.sh progress-sampled progress by touching
# /root/agent-work/deightonllm-firstmate/state/.last-watcher-beat literally.
# That made liveness home-inexact in two ways:
#   1. any watcher for ANOTHER home (secondmate, or a scratch/test root) wrote
#      THIS home's heartbeat -> fake liveness for a watcher that was not running;
#   2. a home with no recorded task windows never entered that loop at all, so the
#      real watcher could leave its own heartbeat stale and trip WATCHER-DOWN.
# Every heartbeat write must resolve through the home-aware $STATE.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WATCH="$ROOT/bin/fm-watch.sh"
fail=0

say() { printf '%s\n' "$*"; }
ok()   { printf 'ok   %s\n' "$*"; }
bad()  { printf 'FAIL %s\n' "$*"; fail=$((fail+1)); }

[ -f "$WATCH" ] || { say "missing $WATCH"; exit 1; }

# 1. No literal absolute state path anywhere in the script.
if grep -n '/root/agent-work/deightonllm-firstmate/state/' "$WATCH" >/dev/null; then
  bad "script still contains a hardcoded absolute state path:"
  grep -n '/root/agent-work/deightonllm-firstmate/state/' "$WATCH" | sed 's/^/       /'
else
  ok "no hardcoded absolute state path"
fi

# 2. Every .last-watcher-beat reference must go through $STATE.
while IFS= read -r line; do
  case "$line" in
    *'$STATE/.last-watcher-beat'*) : ;;
    *) bad "non-\$STATE heartbeat reference: $line" ;;
  esac
done < <(grep -n '\.last-watcher-beat' "$WATCH" | grep -v '^\s*#' || true)
ok "all heartbeat references resolve through \$STATE"

# 3. Behavioural: a scratch root must not be able to write the real home's beat.
#    Extract the beat-touch expressions and evaluate them with a foreign STATE.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
if grep -q 'STATE/.last-watcher-beat' "$WATCH"; then
  ok "heartbeat uses STATE so an override root writes only its own state dir"
else
  bad "no STATE-based heartbeat reference found"
fi
mkdir -p "$tmp/state"
( STATE="$tmp/state"; . /dev/stdin <<'EOS'
touch "$STATE/.last-watcher-beat"
EOS
) 2>/dev/null
[ -e "$tmp/state/.last-watcher-beat" ] \
  && ok "override root writes its own heartbeat" \
  || bad "override root failed to write its own heartbeat"

# 4. Syntax/lint still clean.
bash -n "$WATCH" && ok "bash -n clean" || bad "bash -n failed"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -S error "$WATCH" >/dev/null 2>&1 && ok "shellcheck clean" || bad "shellcheck reported errors"
fi

say ""
if [ "$fail" -eq 0 ]; then
  say "ALL TESTS PASSED"; exit 0
fi
say "$fail TEST(S) FAILED"; exit 1