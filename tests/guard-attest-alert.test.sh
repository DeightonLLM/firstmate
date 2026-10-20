#!/usr/bin/env bash
# tests/guard-attest-alert.test.sh - TDD suite for Ticket 0034 (Stale Guard Alerting)
#
# The suite exercises the REAL alerting path: it runs the guard, reads the event
# log it wrote, and asserts on the operator-facing event it produced. It never
# asserts on source strings.
#
# The guard under test is the repository's canonical source by default, so the
# test fails when the landed source is broken. Point FM_GUARD_ATTEST_BIN at an
# installed copy to test that copy instead.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -n "${FM_GUARD_ATTEST_BIN:-}" ]; then
  GUARD_ATTEST="$FM_GUARD_ATTEST_BIN"
elif [ -f "$REPO_ROOT/bin/fm-guard-attest.sh" ]; then
  GUARD_ATTEST="$REPO_ROOT/bin/fm-guard-attest.sh"
else
  GUARD_ATTEST="/root/bin/guard-attest"
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

export FM_HOME="$REPO_ROOT"
export FM_ATTEST_DIR="$TMP_DIR/attestations"
export FM_ATTEST_STATE_DIR="$TMP_DIR/state"
export FM_ATTEST_STATUS_FILE="$TMP_DIR/status"
export FM_STATE_OVERRIDE="$TMP_DIR/state"
export FM_WAKE_QUEUE="$TMP_DIR/wake-queue"
export FM_ATTEST_STALE_SECS=10
export FM_ATTEST_GUARDS="test-guard test-missing"

mkdir -p "$FM_ATTEST_DIR" "$FM_ATTEST_STATE_DIR"

pass=0
fail=0

assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    printf 'PASS  %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s (expected "%s", got "%s")\n' "$desc" "$expected" "$actual"
    fail=$((fail + 1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -q "$needle"; then
    printf 'PASS  %s\n' "$desc"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s (expected to contain "%s")\n' "$desc" "$needle"
    fail=$((fail + 1))
  fi
}

assert_not_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -q "$needle"; then
    printf 'FAIL  %s (expected NOT to contain "%s")\n' "$desc" "$needle"
    fail=$((fail + 1))
  else
    printf 'PASS  %s\n' "$desc"
    pass=$((pass + 1))
  fi
}

# 1. Setup: Record CLEAR for test-guard
"$GUARD_ATTEST" run test-guard CLEAR "healthy run" >/dev/null 2>&1

# 2. Check healthy state: Should exit 1 because test-missing is MISSING,
# but test-guard should not generate an alert.
output=$("$GUARD_ATTEST" status 2>&1 || true)
assert_contains "Missing guard triggers alert output" "$output" "GUARD_ALERT: test-missing"

# 3. Repeated poll with test-missing: Should NOT generate duplicate alert (deduped state)
output2=$("$GUARD_ATTEST" status 2>&1 || true)
assert_eq "No alert storm on repeated missing poll" "$(printf '%s' "$output2" | grep -c "GUARD_ALERT: test-missing" || true)" "0"

# 4. Now make test-guard STALE by backdating its timestamp
sed -i 's/^[0-9]*/1000000000/' "$FM_ATTEST_DIR/test-guard.tsv"
output_stale=$("$GUARD_ATTEST" status 2>&1 || true)
assert_contains "Stale guard triggers alert" "$output_stale" "GUARD_ALERT: test-guard"
assert_contains "Alert specifies STALE state" "$output_stale" "STALE"

# 4b. The verdict must reach the operator through the fleet's durable wake
# queue - the same path every other actionable event uses. This is the
# delivery, asserted on the emitted queue record, not on source text.
wake_records=$(cat "$FM_WAKE_QUEUE" 2>/dev/null || printf '')
assert_contains "Stale verdict produced a wake-queue record for the operator" "$wake_records" "guard:test-guard"
assert_contains "Wake record carries the stale verdict" "$wake_records" "GUARD_ALERT: test-guard"

# 5. Repeated poll with test-guard stale: No alert storm
output_stale2=$("$GUARD_ATTEST" status 2>&1 || true)
assert_eq "No alert storm on repeated stale poll" "$(printf '%s' "$output_stale2" | grep -c "GUARD_ALERT: test-guard" || true)" "0"

# 6. Recovery: test-guard runs CLEAR again
"$GUARD_ATTEST" run test-guard CLEAR "recovered and healthy" >/dev/null 2>&1
output_recovery=$("$GUARD_ATTEST" status 2>&1 || true)
assert_contains "Recovery notice emitted when guard recovers" "$output_recovery" "GUARD_RECOVERED: test-guard"

# 7. Repeated poll after recovery: Silent (no recovery storm)
output_recovery2=$("$GUARD_ATTEST" status 2>&1 || true)
assert_eq "No recovery notice storm" "$(printf '%s' "$output_recovery2" | grep -c "GUARD_RECOVERED" || true)" "0"

# ---------------------------------------------------------------------------
# LIVENESS (2026-10-20): a guard that keeps running must not be reported STALE.
# The event log de-duplicates an identical consecutive verdict, but the verdict
# row's timestamp must still be refreshed on every run.
# This section runs against its own status file: the operator-facing file is
# rebuilt from the registered guard set, so a different set must not rewrite the
# file another section is asserting on.
# ---------------------------------------------------------------------------
LIVENESS_STATUS="$TMP_DIR/liveness.status"
"$GUARD_ATTEST" run test-liveness CLEAR "steady state" >/dev/null 2>&1
ts_before=$(tail -1 "$FM_ATTEST_DIR/test-liveness.tsv" | cut -f1)
sleep 1
"$GUARD_ATTEST" run test-liveness CLEAR "steady state" >/dev/null 2>&1
ts_after=$(tail -1 "$FM_ATTEST_DIR/test-liveness.tsv" | cut -f1)
assert_eq "Repeated identical verdict keeps one event row" "$(wc -l < "$FM_ATTEST_DIR/test-liveness.tsv" | tr -d ' ')" "1"
if [ "${ts_after:-0}" -gt "${ts_before:-0}" ]; then
  printf 'PASS  %s\n' "Repeated identical verdict refreshes liveness"
  pass=$((pass + 1))
else
  printf 'FAIL  %s (ts_before=%s ts_after=%s)\n' "Repeated identical verdict refreshes liveness" "$ts_before" "$ts_after"
  fail=$((fail + 1))
fi
liveness_out=$(FM_ATTEST_GUARDS="test-liveness" FM_ATTEST_STATUS_FILE="$LIVENESS_STATUS" "$GUARD_ATTEST" status 2>&1 || true)
assert_not_contains "A guard that keeps running is not reported STALE" "$liveness_out" "STALE"

# ---------------------------------------------------------------------------
# DELIVERY (2026-10-20): the verdict must reach the operator through the
# watcher's signal path, not sit in a status table. The operator-facing file
# must carry a captain-relevant LAST line, which is exactly what the watcher's
# classifier (status_is_captain_relevant) tests before it wakes the operator.
# ---------------------------------------------------------------------------
CLASSIFY_LIB="$REPO_ROOT/bin/fm-classify-lib.sh"
if [ -f "$CLASSIFY_LIB" ]; then
  # shellcheck source=bin/fm-classify-lib.sh
  . "$CLASSIFY_LIB"
  status_line=$(tail -1 "$FM_ATTEST_STATUS_FILE" 2>/dev/null || printf '')
  if status_is_captain_relevant "$status_line"; then
    printf 'PASS  %s\n' "Operator-facing status file is captain-relevant (watcher would wake)"
    pass=$((pass + 1))
  else
    printf 'FAIL  %s (last line: %s)\n' "Operator-facing status file is captain-relevant (watcher would wake)" "$status_line"
    fail=$((fail + 1))
  fi
else
  printf 'FAIL  %s (classifier not found: %s)\n' "Operator-facing status file is captain-relevant (watcher would wake)" "$CLASSIFY_LIB"
  fail=$((fail + 1))
fi
assert_contains "Operator-facing status file names the bad guard" "$(cat "$FM_ATTEST_STATUS_FILE" 2>/dev/null || printf '')" "GUARD_ALERT: test-missing"

# The file must not be rewritten when nothing changed: the watcher compares a
# persisted size:mtime signature, so a rewritten-but-identical file would wake
# the operator on every poll.
sig_before=$(stat -c "%s:%Y" "$FM_ATTEST_STATUS_FILE" 2>/dev/null || printf 'absent')
wake_before=$(wc -l < "$FM_WAKE_QUEUE" 2>/dev/null | tr -d ' ')
sleep 1
"$GUARD_ATTEST" status >/dev/null 2>&1 || true
"$GUARD_ATTEST" status >/dev/null 2>&1 || true
sig_after=$(stat -c "%s:%Y" "$FM_ATTEST_STATUS_FILE" 2>/dev/null || printf 'absent')
wake_after=$(wc -l < "$FM_WAKE_QUEUE" 2>/dev/null | tr -d ' ')
assert_eq "Healthy poll does not churn the operator-facing status file" "$sig_after" "$sig_before"
assert_eq "Healthy poll does not spam the wake queue" "$wake_after" "$wake_before"

# Recovery notice reaches the operator as its own captain-relevant event.
"$GUARD_ATTEST" run test-missing CLEAR "it came back" >/dev/null 2>&1
"$GUARD_ATTEST" status >/dev/null 2>&1 || true
assert_contains "Recovery notice is written for the operator" "$(cat "$FM_ATTEST_STATUS_FILE" 2>/dev/null || printf '')" "GUARD_RECOVERED: test-missing"
assert_contains "Recovery notice produced a wake-queue record" "$(cat "$FM_WAKE_QUEUE" 2>/dev/null || printf '')" "GUARD_RECOVERED: test-missing"

# Healthy surface: nothing captain-relevant is left standing.
rm -f "$FM_ATTEST_DIR/test-guard.tsv" "$FM_ATTEST_DIR/test-liveness.tsv" "$FM_ATTEST_DIR/test-missing.tsv"
rm -rf "$FM_ATTEST_STATE_DIR"
mkdir -p "$FM_ATTEST_STATE_DIR"
"$GUARD_ATTEST" run test-guard CLEAR "healthy" >/dev/null 2>&1
FM_ATTEST_GUARDS="test-guard" "$GUARD_ATTEST" status >/dev/null 2>&1 || true
healthy_line=$(tail -1 "$FM_ATTEST_STATUS_FILE" 2>/dev/null || printf '')
if [ -f "$CLASSIFY_LIB" ] && status_is_captain_relevant "$healthy_line"; then
  printf 'FAIL  %s (last line: %s)\n' "Healthy surface raises no operator wake" "$healthy_line"
  fail=$((fail + 1))
else
  printf 'PASS  %s\n' "Healthy surface raises no operator wake"
  pass=$((pass + 1))
fi

printf '\nTotal: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
