#!/usr/bin/env bash
# verify-fleet.sh - READ-ONLY census of a surface's lane fleet.
#
# It mutates nothing: no spawn, no kill, no lock, no file write. It answers one
# question - "how many lanes are genuinely running, on what, doing what" - from
# evidence rather than memory.
#
# Usage:
#   bash docs/fan-out-kit/verify-fleet.sh [--home <firstmate-home>] [--half <name>:<state-dir>:<data-dir>] ...
#
# Defaults: the firstmate home is $FM_HOME (or the current repo), and the half is
# the home's own state/ and data/.
#
# The numbers this prints are the numbers the Captain's board must use.

set -u

HOME_DIR="${FM_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HALVES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --home) HOME_DIR="$2"; shift 2 ;;
    --half) HALVES+=("$2"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ ${#HALVES[@]} -eq 0 ] && HALVES+=("main:${HOME_DIR}/state:${HOME_DIR}/data")

section() { printf '\n== %s ==\n' "$1"; }

section "when"
date -u '+%Y-%m-%dT%H:%M:%SZ'

section "daemons (read from /proc, not from the script defaults)"
for p in $(pgrep -f "fm-always-four.sh daemon" 2>/dev/null); do
  harness=$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -E '^FM_ALWAYS_FOUR_HARNESS=' | cut -d= -f2)
  target=$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -E '^FM_ALWAYS_FOUR_TARGET=' | cut -d= -f2)
  model=$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -E '^FM_ALWAYS_FOUR_WORKER_MODEL=' | cut -d= -f2)
  cap=$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -E '^FM_DISPATCH_GUARD_MAX_PROVIDER_LANES=' | cut -d= -f2)
  age=$(ps -o etime= -p "$p" 2>/dev/null | tr -d ' ')
  printf 'pid=%s age=%-10s harness=%-12s target=%-3s provider_cap=%-3s model=%s\n' \
    "$p" "${age:-?}" "${harness:-<unset>}" "${target:-<unset>}" "${cap:-<unset>}" "${model:-<unset>}"
done

for half in "${HALVES[@]}"; do
  IFS=':' read -r name state data <<< "$half"
  section "half: $name  (state=$state)"

  printf 'lanes with a task: '
  ls "$state"/lane-*.meta >/dev/null 2>&1 && ls "$state"/lane-*.meta 2>/dev/null | wc -l || echo 0
  printf 'distinct planning ids in flight: '
  cat "$state"/*.planning-id 2>/dev/null | sort -u | wc -l
  printf 'queued rows: '
  grep -c '^- \[ \] ' "$data"/backlog.md 2>/dev/null || echo 0
  printf 'attempt counters at the cap (3): '
  at_cap=0
  for f in "$state"/lane-*.attempts; do
    [ -f "$f" ] || continue
    [ "$(cat "$f" 2>/dev/null | tr -d '[:space:]')" = "3" ] && at_cap=$((at_cap + 1))
  done
  echo "$at_cap"

  echo 'lane -> task:'
  for meta in "$state"/lane-*.meta; do
    [ -f "$meta" ] || continue
    lane=$(basename "$meta" .meta)
    key=$(grep '^endpoint_task_id=' "$meta" 2>/dev/null | cut -d= -f2)
    plan=$(cat "$state/$key.planning-id" 2>/dev/null)
    printf '  %-10s %-58s %s\n' "$lane" "${plan:-<no planning id>}" "$key"
  done
done

section "live workers (presence is not progress - check CPU time)"
for h in minimax-code codex pi claude; do
  n=$(pgrep -x "$h" 2>/dev/null | wc -l)
  [ "$n" -gt 0 ] && printf '%-14s %s process(es)\n' "$h" "$n"
done
ps -eo pid,etime,time,pcpu,comm 2>/dev/null | grep -E 'minimax-code|codex$' | head -20

section "quota (a fresh reading - never carry a number over)"
if command -v quota-axi >/dev/null 2>&1; then
  quota-axi 2>&1 | head -20
else
  echo 'quota-axi is not on PATH - measure it on the surface that owns the account'
fi

section 'verdict'
cat <<'EOF'
This census is evidence, not a verdict. Before reporting a lane as working, check that its
worker is WORKING (CPU time or thread timestamps advancing) and that its artifact exists with
a VERDICT: last line. A live process with flat CPU is a lane stuck at a dialog - see
docs/fan-out-kit/traps.md section 1.
EOF
