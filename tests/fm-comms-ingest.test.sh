#!/usr/bin/env bash
# Behavioral regressions for the secondmate file-drop receive/receipt/ack ingest.
#
# A remote secondmate (Hetz / brandon-compute) cannot write the parent's
# state/<id>.status directly: its DNS/route back to the parent home is not
# reliable. It drops report files into a local workspace directory that a
# transport sync mirrors onto the parent host. Nothing consumed that mirror, so
# a reply landed on disk and produced no wake, no receipt, and no
# acknowledgment - which is exactly the "replies disappear" failure.
#
# These tests exercise the public command interface only. They never touch a
# live remote, the real secondmate registry, or the active fleet.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INGEST="$ROOT/bin/fm-comms-ingest.sh"
TMP_ROOT=$(fm_test_tmproot fm-comms-ingest)

# Build a throwaway parent home plus a mirrored report directory.
make_env() {  # <name> -> echoes "<home> <reports>"
  local home="$TMP_ROOT/$1/home" reports="$TMP_ROOT/$1/reports"
  mkdir -p "$home/state" "$reports"
  printf '%s %s\n' "$home" "$reports"
}

write_report() {  # <path> <body>
  printf '%s\n' "$2" > "$1"
}

# A newly arrived reply becomes one status line AND one signal wake, and leaves
# a durable receipt naming the exact file and content digest.
test_receive_publishes_wake_and_receipt() {
  local home reports status queue out
  read -r home reports <<<"$(make_env receive)"
  status="$home/state/hetz-inbox.status"
  write_report "$reports/reply-1.md" "From Hetz: core-distro parity audit is complete."
  queue="$home/state/.wake-queue"

  out=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan hetz-inbox "$reports" 2>&1) || {
    fail "scan exited non-zero: $out"
    return
  }

  assert_present "$status" "an arrived reply leaves no parent status channel"
  assert_grep "core-distro parity audit" "$status" \
    "the reply body is not preserved on the parent status channel"
  assert_present "$queue" "an arrived reply produces no wake queue"
  assert_grep "signal" "$queue" "the arrival is not published as a signal wake"
  assert_grep "hetz-inbox.status" "$queue" \
    "the wake key does not resolve to the parent status file"
  assert_contains "$out" "ingested: 1" \
    "the scan does not report how many replies it received"
  pass "an arrived reply becomes a status line, a signal wake, and a receipt"
}

# Re-scanning the same unchanged file is a no-op: no second status line, no
# second wake. This is the dedup guarantee that keeps a periodic sync from
# re-announcing the same reply forever.
test_rescan_is_deduplicated() {
  local home reports status queue out first_lines second_lines
  read -r home reports <<<"$(make_env dedup)"
  status="$home/state/hetz-inbox.status"
  queue="$home/state/.wake-queue"
  write_report "$reports/reply-1.md" "From Hetz: parity audit complete."

  FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan hetz-inbox "$reports" >/dev/null 2>&1 || {
    fail "first scan failed"
    return
  }
  first_lines=$(wc -l <"$status")
  local first_wakes
  first_wakes=$(grep -c 'signal' "$queue" 2>/dev/null || echo 0)

  out=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan hetz-inbox "$reports" 2>&1) || {
    fail "second scan exited non-zero: $out"
    return
  }

  second_lines=$(wc -l <"$status")
  assert_contains "$second_lines" "$first_lines" \
    "an unchanged reply was appended to the status channel a second time"
  assert_contains "$(grep -c 'signal' "$queue" 2>/dev/null || echo 0)" "$first_wakes" \
    "an unchanged reply published a duplicate wake"
  assert_contains "$out" "ingested: 0" \
    "the second scan claims to have ingested an already-received reply"
  pass "an unchanged reply is received exactly once"
}

# A changed file is genuinely new content and is received again; this proves
# dedup is keyed on content, not merely on filename.
test_changed_content_is_a_new_receipt() {
  local home reports status out
  read -r home reports <<<"$(make_env changed)"
  status="$home/state/hetz-inbox.status"
  write_report "$reports/reply-1.md" "From Hetz: parity audit complete."

  FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan hetz-inbox "$reports" >/dev/null 2>&1 || {
    fail "first scan failed"
    return
  }
  write_report "$reports/reply-1.md" "From Hetz: parity audit REVERSED, blocked."
  out=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan hetz-inbox "$reports" 2>&1) || {
    fail "rescan after content change exited non-zero: $out"
    return
  }
  assert_grep "REVERSED" "$status" \
    "a materially changed reply is never received again"
  assert_contains "$out" "ingested: 1" \
    "a changed reply is not counted as a new receipt"
  pass "a materially changed reply is received as new content"
}

# Correlation: a reply carrying the request's corr= token is recorded with that
# token on the status channel, so a parent can match it to its open
# expectation instead of guessing.
test_corr_token_is_recorded() {
  local home reports status
  read -r home reports <<<"$(make_env corr)"
  status="$home/state/hetz-inbox.status"
  write_report "$reports/reply-1.md" \
    "From Hetz: parity audit complete. corr=abc123def4567890"

  FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan hetz-inbox "$reports" >/dev/null 2>&1 || {
    fail "scan failed"
    return
  }
  assert_grep "corr=abc123def4567890" "$status" \
    "the reply's correlation token is dropped, breaking request matching"
  pass "a reply's correlation token is preserved for request matching"
}

# Acknowledgment is a separate fact from receipt, and is idempotent: the first
# handled call records it, repeats report already-handled and change nothing.
test_handled_is_durable_and_idempotent() {
  local home reports out second
  read -r home reports <<<"$(make_env handled)"
  write_report "$reports/reply-1.md" "From Hetz: parity audit complete."

  FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan hetz-inbox "$reports" >/dev/null 2>&1 || {
    fail "scan failed"
    return
  }

  out=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" handled hetz-inbox reply-1.md 2>&1) || {
    fail "handled exited non-zero: $out"
    return
  }
  assert_contains "$out" "handled: reply-1.md" \
    "the first acknowledgment is not recorded"

  second=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" handled hetz-inbox reply-1.md 2>&1) || {
    fail "repeat handled exited non-zero: $second"
    return
  }
  assert_contains "$second" "already-handled: reply-1.md" \
    "a repeated acknowledgment is not deduplicated"
  pass "acknowledgment is durable, separate from receipt, and idempotent"
}

# Acknowledging something never received must fail closed rather than invent a
# receipt. This is the negative guard against manufacturing acknowledgment.
test_handled_refuses_unreceived_reply() {
  local home reports out code
  read -r home reports <<<"$(make_env unreceived)"
  write_report "$reports/reply-1.md" "From Hetz: parity audit complete."
  FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan hetz-inbox "$reports" >/dev/null 2>&1 || {
    fail "scan failed"
    return
  }
  out=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" handled hetz-inbox never-seen.md 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "acknowledging a never-received reply was accepted (manufactured ack)"
    return
  fi
  assert_contains "$out" "not-received" \
    "the refusal does not state that the reply was never received"
  pass "acknowledging a never-received reply fails closed"
}

# Negative: a task id that could escape the status channel must be refused
# before it can write outside state/.
test_traversal_task_id_is_refused() {
  local home reports out code
  read -r home reports <<<"$(make_env traversal)"
  write_report "$reports/reply-1.md" "From Hetz: parity audit complete."
  out=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan "../../escape" "$reports" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "a traversing task id was accepted"
    return
  fi
  assert_absent "$TMP_ROOT/traversal/escape.status" \
    "a traversing task id wrote a status file outside state/"
  pass "a traversing task id is refused and writes nothing"
}

# Negative: subdirectories and non-regular entries in the mirror are ignored,
# so a partially-synced tree cannot inject a fabricated receipt.
test_non_regular_entries_are_ignored() {
  local home reports out
  read -r home reports <<<"$(make_env nonregular)"
  mkdir -p "$reports/partial-dir"
  out=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan hetz-inbox "$reports" 2>&1) || {
    fail "scan over a tree containing a subdirectory exited non-zero: $out"
    return
  }
  assert_contains "$out" "ingested: 0" \
    "a subdirectory was received as if it were a reply"
  pass "subdirectories and non-regular entries are ignored"
}

# A missing report directory is a loud signal, never a silent pass: an
# unreachable or unmounted mirror must not read as "no replies, all healthy".
test_missing_report_dir_fails_closed() {
  local home out code
  read -r home _ <<<"$(make_env missing)"
  out=$(FM_HOME="$home" FM_ROOT_OVERRIDE="$ROOT" \
    "$INGEST" scan hetz-inbox "$TMP_ROOT/missing/nope" 2>&1)
  code=$?
  if [ "$code" -eq 0 ]; then
    fail "a missing report directory reported success"
    return
  fi
  assert_contains "$out" "error:" \
    "a missing report directory does not explain itself"
  pass "a missing report directory fails closed instead of reading as healthy"
}

test_receive_publishes_wake_and_receipt
test_rescan_is_deduplicated
test_changed_content_is_a_new_receipt
test_corr_token_is_recorded
test_handled_is_durable_and_idempotent
test_handled_refuses_unreceived_reply
test_traversal_task_id_is_refused
test_non_regular_entries_are_ignored
test_missing_report_dir_fails_closed