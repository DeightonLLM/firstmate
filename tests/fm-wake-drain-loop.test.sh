#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export FM_HOME="$TMP/home"
export FM_ROOT_OVERRIDE="$FM_HOME"
export FM_STATE_OVERRIDE="$FM_HOME/state"
mkdir -p "$FM_STATE_OVERRIDE"
DRAIN="$ROOT/bin/fm-wake-drain.sh"

fail() { printf 'FAIL=%s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS=%s\n' "$1"; }

out=$(bash "$DRAIN" 2>&1) || fail 'empty-drain-exit'
[ -z "$out" ] || fail "empty-drain-output:$out"
pass empty-drain-is-silent-and-successful

# Use the production append helper so records match the queue's wire format.
# shellcheck source=../bin/fm-wake-lib.sh
. "$ROOT/bin/fm-wake-lib.sh"
fm_wake_append check controller 'message-one'
fm_wake_append check other 'message-two'
first=$(bash "$DRAIN" 2>&1) || fail 'queued-drain-exit'
[[ "$first" == *'controller'* && "$first" == *'other'* ]] || fail "drain-did-not-print-both-records:$first"
second=$(bash "$DRAIN" 2>&1) || fail 'second-drain-exit'
[ -z "$second" ] || fail "queue-not-empty-after-drain:$second"
pass queued-records-printed-and-removed

fm_wake_append check controller 'loop-one'
fm_wake_append check other 'loop-two'
loop_out=$(timeout 5 bash -c '
  set -euo pipefail
  drain=$1
  while :; do
    out=$(bash "$drain" 2>&1)
    [ -z "$out" ] && break
    printf "%s\n" "$out"
  done
' _ "$DRAIN") || fail 'repeated-drain-loop-did-not-converge-within-5s'
[[ "$loop_out" == *'controller'* && "$loop_out" == *'other'* ]] || fail "loop-did-not-act-on-all-output:$loop_out"
pass repeated-drain-loop-converges-within-5s

if ! grep -Eiq 'drain(ing)? until it prints nothing|keep draining until it prints nothing|drain repeatedly until.*nothing' "$ROOT/docs/supervision-protocols/pi.md"; then
  fail 'Pi protocol missing drain-until-empty requirement'
fi
pass Pi-protocol-requires-drain-until-empty
