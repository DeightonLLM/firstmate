#!/usr/bin/env bash
# Proves the wake-drain contract that actually holds.
#
# CORRECTION, 2026-10-15. An earlier version of this file asserted a
# drain-until-empty loop. Controller checked the owning code and that was wrong:
# fm-wake-drain.sh moves the queue snapshot atomically under its lock, so ONE
# call empties it. The real defect was not a missing loop, it was firstmate
# reading the `wake annotation:` lines instead of the raw tab-separated rows.
#
# The real failure mode, 2026-10-15: a cycle emitted a check wake for a
# Controller message AND a second check wake from another check script.
# Firstmate read the annotation, acted on the wake it named, and discarded the
# other. A Controller message went unread until the Captain prompted it.
#
# So these tests assert: one drain empties the queue, the raw rows are the
# authoritative list, and annotations are explicitly marked as supplemental and
# are omitted when they would repeat an event already represented.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export FM_HOME="$TMP/home"
export FM_ROOT_OVERRIDE="$FM_HOME"
export FM_STATE_OVERRIDE="$FM_HOME/state"
mkdir -p "$FM_STATE_OVERRIDE"
DRAIN="$ROOT/bin/fm-wake-drain.sh"

PASS=0
FAIL=0
ok()  { printf 'PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf 'FAIL  %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

# Append in the queue's own wire format: epoch<TAB>seq<TAB>kind<TAB>key<TAB>payload
seed() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$FM_STATE_OVERRIDE/.wake-queue"
}

out=$(bash "$DRAIN" 2>&1) || bad 'empty-drain-exit'
[ -z "$out" ] && ok 'empty-drain-is-silent-and-successful' || bad "empty-drain-output:$out"

# One call must empty the queue. This is the property that made a loop wrong.
seed 100 1 check default:w1:p2 'check: state/controller-inbox.check.sh: msg A'
seed 100 2 check default:w2:p2 'check: state/gate.check.sh: gate B'
out=$(bash "$DRAIN" 2>&1) || bad 'drain-exit'
rows=$(printf '%s\n' "$out" | grep -c 'check	default:')
if [ "$rows" = 2 ]; then ok 'one-drain-returns-every-queued-wake'
else bad "one-drain-returned-$rows-rows-expected-2"; fi

# Both distinct wakes must be present by name. Reading only the first is the
# exact defect that dropped a Controller message.
for want in 'msg A' 'gate B'; do
  printf '%s\n' "$out" | grep -qF "$want" \
    && ok "both-wakes-present:$want" \
    || bad "wake-missing-from-drain-output:$want"
done

after=$(bash "$DRAIN" 2>&1)
[ -z "$after" ] && ok 'one-drain-empties-the-queue-no-loop-needed' || bad "queue-not-empty:$after"

# The raw rows are authoritative; annotations are supplemental and are marked.
if grep -Fq 'raw tab-separated rows are the authoritative wake list' "$ROOT/docs/supervision-protocols/pi.md"; then
  ok 'protocol-states-raw-rows-are-authoritative'
else
  bad 'protocol-does-not-state-that-raw-rows-are-authoritative'
fi

if grep -Fq 'wake annotation:' "$ROOT/docs/supervision-protocols/pi.md" \
   && grep -Fq 'supplemental' "$ROOT/docs/supervision-protocols/pi.md"; then
  ok 'protocol-marks-annotations-as-supplemental'
else
  bad 'protocol-does-not-mark-annotations-as-supplemental'
fi

# A loop wrapper would contradict the owning contract.
if grep -Fq 'keep draining until it prints nothing' "$ROOT/docs/supervision-protocols/pi.md"; then
  bad 'protocol-still-requires-the-incorrect-drain-loop'
else
  ok 'protocol-does-not-require-a-drain-loop'
fi

printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ] || exit 1
