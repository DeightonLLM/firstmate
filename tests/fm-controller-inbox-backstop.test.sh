#!/usr/bin/env bash
# tests/fm-controller-inbox-backstop.test.sh - the enforcement point for
# "an acknowledgement is keyed by the MESSAGE NAME, and a republication is
#  visible but never blocks".
#
# THE DEFECT THIS SUITE EXISTS FOR: the backstop deduplicated by sha256 only.
# The Controller republishes one logical board file with new bytes every minute,
# so that single logical message was reported as a brand new unhandled message
# forever, the watcher woke on every cycle, and supervision could never hold.
#
# The suite drives the real script against real files in a temp home and asserts
# real exit codes. Nothing here depends on the live inbox, the live ledger or
# the live state directory.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BACKSTOP="$ROOT/bin/fm-controller-inbox-backstop.sh"
TMP_ROOT=$(fm_test_tmproot fm-controller-inbox-backstop-tests)

HOME_DIR="$TMP_ROOT/home"
STATE_DIR="$HOME_DIR/state"
INBOX_DIR="$HOME_DIR/inbox"
HASH_LEDGER="$STATE_DIR/.controller-inbox-handled"
NAME_LEDGER="$STATE_DIR/.controller-inbox-handled-names"
ACK_RECORD="$STATE_DIR/.controller-inbox-acknowledged"
REPUBLISHED_LOG="$STATE_DIR/.controller-inbox-republished.log"

export FM_HOME="$HOME_DIR"
export FM_INBOX_BACKSTOP_DIRS="$INBOX_DIR"
export FM_INBOX_DIRS="$INBOX_DIR"

mkdir -p "$STATE_DIR" "$INBOX_DIR"

SCAN_OUT="$TMP_ROOT/scan.out"
SCAN_ERR="$TMP_ROOT/scan.err"
REPORT_OUT="$TMP_ROOT/report.out"
ACK_OUT="$TMP_ROOT/ack.out"
ACK_ERR="$TMP_ROOT/ack.err"

# set_old: backdate a file well past the stale threshold, portably.
set_old() {  # <file>
  local f=$1 epoch
  epoch=$(( $(date +%s) - 3600 ))
  if touch -d "@$epoch" "$f" 2>/dev/null; then return 0; fi
  if python3 -c 'import os,sys; t=float(sys.argv[2]); os.utime(sys.argv[1],(t,t))' \
    "$f" "$epoch" 2>/dev/null; then return 0; fi
  touch -t "$(date -r "$epoch" +%Y%m%d%H%M.%S 2>/dev/null)" "$f" 2>/dev/null
}

# write_message: publish a message into the watched route.
write_message() {  # <name> <content>
  printf '%s\n' "$2" > "$INBOX_DIR/$1"
  set_old "$INBOX_DIR/$1"
}

file_sha() {  # <file>
  sha256sum "$1" | cut -d' ' -f1
}

# run_scan: the watcher check mode. Stdout carries the actionable finding ONLY.
run_scan() {
  bash "$BACKSTOP" > "$SCAN_OUT" 2> "$SCAN_ERR"
  printf '%s' "$?"
}

# run_report: the classification dump.
run_report() {
  bash "$BACKSTOP" --report > "$REPORT_OUT" 2> "$SCAN_ERR"
  printf '%s' "$?"
}

# run_ack: acknowledge a message by name.
run_ack() {  # <name> <sha256>
  bash "$BACKSTOP" --ack "$1" "$2" > "$ACK_OUT" 2> "$ACK_ERR"
  printf '%s' "$?"
}

# (a) A message that was never acknowledged is UNHANDLED, and once it has been
# sitting longer than the stale threshold it is the actionable finding.
test_a_new_message_is_reported_unhandled() {
  local rc
  write_message "LANE-CLAIMS.md" "the claims board, first publication"
  rc=$(run_scan)
  expect_code 0 "$rc" "the scan must exit successfully"
  assert_grep "unhandled inbound message older than" "$SCAN_OUT" \
    "a message that was never acknowledged must be reported as unhandled"
  assert_grep "LANE-CLAIMS.md" "$SCAN_OUT" \
    "the unhandled report must name the message"
  pass "a new message is reported unhandled"
}

# (b) The same message, acknowledged BY NAME, is handled.
test_an_acknowledged_message_is_handled() {
  local rc hash
  hash=$(file_sha "$INBOX_DIR/LANE-CLAIMS.md")
  rc=$(run_ack "LANE-CLAIMS.md" "$hash")
  expect_code 0 "$rc" "the acknowledgement must succeed"
  assert_grep "acknowledged: LANE-CLAIMS.md" "$ACK_OUT" \
    "the acknowledgement must be reported"

  rc=$(run_scan)
  expect_code 0 "$rc" "the scan must exit successfully"
  assert_no_grep "unhandled" "$SCAN_OUT" \
    "an acknowledged message must not be reported as unhandled"

  rc=$(run_report)
  expect_code 0 "$rc" "the report must exit successfully"
  assert_grep "handled: LANE-CLAIMS.md" "$REPORT_OUT" \
    "the report must classify the acknowledged message as handled"
  pass "after acknowledging it by name the same message is handled"
}

# The acknowledgement is keyed by the name, the hash is kept as the evidence of
# the bytes, and the UTC time the acknowledgement was made is recorded.
test_the_acknowledgement_carries_name_hash_and_time() {
  local name_line hash_line record name hash stamp
  assert_present "$NAME_LEDGER" "the name ledger must exist"
  name_line=$(grep -F "LANE-CLAIMS.md" "$NAME_LEDGER" | head -1)
  assert_equals "LANE-CLAIMS.md" "$name_line" \
    "the name ledger must record the message name on its own line"

  assert_present "$HASH_LEDGER" "the hash ledger must exist"
  hash_line=$(grep -E '^[a-f0-9]{64}$' "$HASH_LEDGER" | head -1)
  assert_equals "$(file_sha "$INBOX_DIR/LANE-CLAIMS.md")" "$hash_line" \
    "the hash ledger must record the acknowledged bytes"

  assert_present "$ACK_RECORD" "the acknowledgement record must exist"
  record=$(grep -F "LANE-CLAIMS.md" "$ACK_RECORD" | head -1)
  [ -n "$record" ] || fail "the acknowledgement record must carry the message name"
  name=$(printf '%s' "$record" | cut -f1)
  hash=$(printf '%s' "$record" | cut -f2)
  stamp=$(printf '%s' "$record" | cut -f3)
  assert_equals "LANE-CLAIMS.md" "$name" "the record must be keyed by the message name"
  case "$hash" in
    *[!a-f0-9]*|'') fail "the record must carry the acknowledged hash" ;;
  esac
  [ "${#hash}" -eq 64 ] || fail "the record must carry the full acknowledged hash"
  case "$stamp" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) : ;;
    *) fail "the record must carry the UTC time the acknowledgement was made" ;;
  esac
  pass "the acknowledgement carries the name, the hash and the UTC time"
}

# (c) The same name republished with DIFFERENT bytes stays handled, and the
# republication is reported with both the old and the new hash. This is the
# case a hash-keyed acknowledgement could never express.
test_a_republished_message_is_handled_and_reported() {
  local rc old_hash new_hash
  old_hash=$(printf '%s' "$(grep -F "LANE-CLAIMS.md" "$ACK_RECORD" | head -1)" | cut -f2)
  write_message "LANE-CLAIMS.md" "the claims board, republished with new bytes"
  new_hash=$(file_sha "$INBOX_DIR/LANE-CLAIMS.md")
  assert_not_equals "$old_hash" "$new_hash" "the republished bytes must differ"

  rc=$(run_scan)
  expect_code 0 "$rc" "the scan must exit successfully"
  assert_no_grep "unhandled" "$SCAN_OUT" \
    "a republished message that was acknowledged by name must not block the watcher"
  [ -s "$SCAN_OUT" ] && fail "a republication must not put anything on stdout"

  rc=$(run_report)
  expect_code 0 "$rc" "the report must exit successfully"
  assert_grep "republished: LANE-CLAIMS.md" "$REPORT_OUT" \
    "the republication must be reported"
  assert_grep "old_sha256=$old_hash" "$REPORT_OUT" \
    "the republication must carry the old hash"
  assert_grep "new_sha256=$new_hash" "$REPORT_OUT" \
    "the republication must carry the new hash"

  assert_present "$REPUBLISHED_LOG" "the republication must leave durable evidence"
  assert_grep "name=LANE-CLAIMS.md" "$REPUBLISHED_LOG" "the republication evidence must name the message"
  assert_grep "sha256=$new_hash" "$REPUBLISHED_LOG" "the republication evidence must carry the new hash"
  assert_grep "old_sha256=$old_hash" "$REPUBLISHED_LOG" "the republication evidence must carry the old hash"
  assert_grep "visible, not blocking" "$REPUBLISHED_LOG" \
    "the republication evidence must say it does not block"
  pass "the same name republished with different bytes is handled and reported as republished"
}

# (d) A DIFFERENT message that was never acknowledged is still unhandled. The
# name-keyed acknowledgement must not make the next message pass.
test_a_different_new_message_is_still_unhandled() {
  local rc
  write_message "OTHER-MESSAGE.md" "a genuinely new message"
  rc=$(run_scan)
  expect_code 0 "$rc" "the scan must exit successfully"
  assert_grep "unhandled inbound message older than" "$SCAN_OUT" \
    "a different new message must still be reported as unhandled"
  assert_grep "OTHER-MESSAGE.md" "$SCAN_OUT" \
    "the unhandled report must name the different message"
  assert_no_grep "LANE-CLAIMS.md" "$SCAN_OUT" \
    "the acknowledged message must stay out of the unhandled report"
  pass "a different new message is still reported unhandled"
}

# The stale threshold is not weakened: a message that has not been sitting long
# enough is not an actionable finding, and one that has is.
test_the_stale_threshold_is_not_weakened() {
  local rc
  rm -f "$INBOX_DIR/OTHER-MESSAGE.md"
  printf '%s\n' "a fresh message" > "$INBOX_DIR/FRESH.md"
  rc=$(run_scan)
  expect_code 0 "$rc" "the scan must exit successfully"
  assert_no_grep "FRESH.md" "$SCAN_OUT" \
    "a message younger than the stale threshold must not block the watcher"

  set_old "$INBOX_DIR/FRESH.md"
  rc=$(run_scan)
  expect_code 0 "$rc" "the scan must exit successfully"
  assert_grep "FRESH.md" "$SCAN_OUT" \
    "a message older than the stale threshold must block the watcher"
  rm -f "$INBOX_DIR/FRESH.md"
  pass "the stale threshold still decides what blocks"
}

# An acknowledgement of bytes that changed after they were read is refused with
# a real exit code, so the acknowledgement can never record a hash it did not
# verify.
test_an_acknowledgement_of_changed_bytes_is_refused() {
  local rc stale_hash
  stale_hash=$(file_sha "$INBOX_DIR/LANE-CLAIMS.md")
  write_message "LANE-CLAIMS.md" "the claims board, moved on again"
  rc=$(run_ack "LANE-CLAIMS.md" "$stale_hash")
  expect_code 1 "$rc" "an acknowledgement of bytes that changed must be refused"
  assert_grep "changed after it was read" "$ACK_ERR" "the refusal must say why"
  pass "an acknowledgement of changed bytes is refused"
}

# A republication that is already on record must not be written again on every
# later scan, so the republication log stays a record of events and not a
# per-cycle transcript.
test_the_republication_log_does_not_grow_on_every_scan() {
  local before after rc
  # The first scan records any republication that is not on record yet.
  rc=$(run_scan)
  expect_code 0 "$rc" "the scan must exit successfully"
  before=$(wc -l < "$REPUBLISHED_LOG" 2>/dev/null || echo 0)
  rc=$(run_scan)
  expect_code 0 "$rc" "the scan must exit successfully"
  after=$(wc -l < "$REPUBLISHED_LOG" 2>/dev/null || echo 0)
  assert_equals "$before" "$after" \
    "a republication that is already on record must not be written again"
  pass "the republication log does not grow on every scan"
}

test_a_new_message_is_reported_unhandled
test_an_acknowledged_message_is_handled
test_the_acknowledgement_carries_name_hash_and_time
test_a_republished_message_is_handled_and_reported
test_a_different_new_message_is_still_unhandled
test_the_stale_threshold_is_not_weakened
test_an_acknowledgement_of_changed_bytes_is_refused
test_the_republication_log_does_not_grow_on_every_scan
