#!/usr/bin/env bash
# tests/fm-controller-pending.test.sh - the enforcement point for
# "a transmission is recorded by the MESSAGE NAME, and a reissue is visible but
# never blocks".
#
# THE DEFECT THIS SUITE EXISTS FOR: the check compared the current hash of
# every outbox note against a ledger of bare hashes. A note that was
# transmitted and then reissued has bytes that are not the bytes that went
# out, so it was reported as never sent on every cycle, the watcher woke on
# every cycle, and supervision could never hold.
#
# The suite drives the real scripts against real files in a temp home and
# asserts real exit codes. Nothing here depends on the live outbox, the live
# ledger or the live state directory, and nothing is written outside the temp
# root.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PENDING="$ROOT/bin/fm-controller-pending.sh"
OUTBOUND="$ROOT/bin/fm-outbound.sh"

TMP_ROOT=$(fm_test_tmproot fm-controller-pending-tests)

SCAN_OUT="$TMP_ROOT/scan.out"
SCAN_ERR="$TMP_ROOT/scan.err"
REPORT_OUT="$TMP_ROOT/report.out"
SEND_OUT="$TMP_ROOT/send.out"
SEND_ERR="$TMP_ROOT/send.err"

SCEN_HOME=
SCEN_OUTBOX=
SCEN_EXCHANGE=

# scenario: a fresh home, outbox and delivery route, so every case starts from
# a ledger that says nothing at all.
scenario() {  # <label>
  SCEN_HOME="$TMP_ROOT/$1/home"
  SCEN_OUTBOX="$SCEN_HOME/BRANDON-COMPUTE-COMMS/from-brandon-compute"
  SCEN_EXCHANGE="$TMP_ROOT/$1/exchange"
  mkdir -p "$SCEN_HOME/state" "$SCEN_OUTBOX" "$SCEN_EXCHANGE"
}

# run_scan: the watcher check mode. Stdout carries the actionable finding ONLY.
run_scan() {
  FM_HOME="$SCEN_HOME" \
  FM_OUTBOUND_EXCHANGE="$SCEN_EXCHANGE" \
  FM_OUTBOUND_DELIVERY_ROUTES="$SCEN_EXCHANGE" \
    bash "$PENDING" > "$SCAN_OUT" 2> "$SCAN_ERR"
  printf '%s' "$?"
}

# run_report: the classification dump. Not the watcher check mode.
run_report() {
  FM_HOME="$SCEN_HOME" \
  FM_OUTBOUND_EXCHANGE="$SCEN_EXCHANGE" \
  FM_OUTBOUND_DELIVERY_ROUTES="$SCEN_EXCHANGE" \
    bash "$PENDING" --report > "$REPORT_OUT" 2> "$SCAN_ERR"
  printf '%s' "$?"
}

# transmit: the sanctioned send path, into the scenario's delivery route.
transmit() {  # <source-file> <name>
  FM_HOME="$SCEN_HOME" \
  FM_OUTBOUND_EXCHANGE="$SCEN_EXCHANGE" \
    bash "$OUTBOUND" "$1" "$2" > "$SEND_OUT" 2> "$SEND_ERR"
  printf '%s' "$?"
}

file_sha() {  # <file>
  sha256sum "$1" | cut -d' ' -f1
}

# set_old: backdate a file, portably.
set_old() {  # <file> <seconds-ago>
  local f=$1 epoch
  epoch=$(( $(date +%s) - $2 ))
  if touch -d "@$epoch" "$f" 2>/dev/null; then return 0; fi
  if python3 -c 'import os,sys; t=float(sys.argv[2]); os.utime(sys.argv[1],(t,t))' \
    "$f" "$epoch" 2>/dev/null; then return 0; fi
  touch -t "$(date -r "$epoch" +%Y%m%d%H%M.%S 2>/dev/null)" "$f" 2>/dev/null
}

reissue_log() {
  printf '%s\n' "$SCEN_HOME/state/.controller-inbox-outbound-reissued.log"
}

# (a) A note that was never transmitted is UNSENT, and it still reports.
test_a_note_that_was_never_transmitted_is_reported_unsent() {
  local rc
  scenario unsent
  printf '%s\n' 'a note that was never sent to Controller' > "$SCEN_OUTBOX/NEVER-SENT.md"

  rc=$(run_scan)
  expect_code 1 "$rc" "the scan must report the unsent note"
  assert_grep "unsent-to-controller: NEVER-SENT.md" "$SCAN_OUT" \
    "a note that was never transmitted must be reported as unsent"
  assert_grep "sha256=" "$SCAN_OUT" \
    "the unsent report must carry the hash of the bytes that were never sent"
  assert_grep "age_days=" "$SCAN_OUT" \
    "the unsent report must carry the age of the note"
  pass "a note that was never transmitted is reported as unsent"
}

# (b) After the transmission the same note is not reported. Nothing is pending,
# so the check exits 0.
test_a_transmitted_note_is_not_reported() {
  local rc
  scenario sent
  printf '%s\n' 'a note that is transmitted to Controller' > "$TMP_ROOT/to-send.md"

  rc=$(transmit "$TMP_ROOT/to-send.md" "SENT-NOTE.md")
  expect_code 0 "$rc" "the transmission must succeed"
  assert_present "$SCEN_OUTBOX/SENT-NOTE.md" \
    "the transmitted note must be in the outbox"
  assert_present "$SCEN_EXCHANGE/SENT-NOTE.md" \
    "the transmitted note must be at the delivery route"

  rc=$(run_scan)
  expect_code 0 "$rc" "a transmitted note leaves nothing pending"
  [ -s "$SCAN_OUT" ] && fail "a transmitted note must not be reported at all"
  pass "after the transmission the same note is not reported"
}

# The transmission is recorded by MESSAGE NAME, and the hash is kept as the
# evidence of the bytes that were transmitted.
test_the_transmission_is_recorded_by_name() {
  local hash line name_line
  hash=$(file_sha "$SCEN_OUTBOX/SENT-NOTE.md")

  assert_present "$SCEN_HOME/state/.controller-inbox-outbound-names" \
    "the name ledger must exist"
  name_line=$(grep -Fx -- "SENT-NOTE.md" "$SCEN_HOME/state/.controller-inbox-outbound-names" | head -1)
  assert_equals "SENT-NOTE.md" "$name_line" \
    "the name ledger must record the message name on its own line"

  assert_present "$SCEN_HOME/state/.controller-inbox-outbound-transmitted" \
    "the transmission record must exist"
  line=$(grep -F -- "SENT-NOTE.md" "$SCEN_HOME/state/.controller-inbox-outbound-transmitted" | head -1)
  [ -n "$line" ] || fail "the transmission record must carry the message name"
  assert_contains "$line" "$hash" \
    "the transmission record must carry the hash of the bytes that were transmitted"

  assert_present "$SCEN_HOME/state/.controller-inbox-outbound" \
    "the hash ledger must exist"
  assert_grep "$hash" "$SCEN_HOME/state/.controller-inbox-outbound" \
    "the hash ledger must keep the bare sha256 of the transmitted bytes"
  pass "the transmission is recorded by name and the hash is the evidence"
}

# (c) A note reissued with different bytes is REISSUED: both hashes are
# reported, it is not reported as unsent, and it does not repeat on a second
# scan.
test_a_reissued_note_is_reported_and_does_not_block() {
  local rc old_hash new_hash first_out first_rc second_out second_rc log_lines
  scenario reissued
  printf '%s\n' 'a note that is transmitted to Controller' > "$TMP_ROOT/to-reissue.md"

  rc=$(transmit "$TMP_ROOT/to-reissue.md" "REISSUED-NOTE.md")
  expect_code 0 "$rc" "the transmission must succeed"
  old_hash=$(file_sha "$SCEN_OUTBOX/REISSUED-NOTE.md")

  # The note is reissued: the same name, different bytes.
  printf '%s\n' 'the same note, reissued with different bytes' > "$SCEN_OUTBOX/REISSUED-NOTE.md"
  new_hash=$(file_sha "$SCEN_OUTBOX/REISSUED-NOTE.md")
  assert_not_equals "$old_hash" "$new_hash" "the reissued bytes must differ"

  rc=$(run_scan)
  expect_code 0 "$rc" "a reissued note must not block the watcher"
  assert_no_grep "unsent-to-controller" "$SCAN_OUT" \
    "a reissued note must not be reported as unsent"
  assert_no_grep "REISSUED-NOTE.md" "$SCAN_OUT" \
    "a reissue must not put anything on stdout: the watcher treats stdout as actionable"

  rc=$(run_report)
  expect_code 0 "$rc" "the report must exit successfully"
  assert_grep "reissued: REISSUED-NOTE.md" "$REPORT_OUT" \
    "the reissue must be reported"
  assert_grep "old_sha256=$old_hash" "$REPORT_OUT" \
    "the reissue must carry the old hash"
  assert_grep "new_sha256=$new_hash" "$REPORT_OUT" \
    "the reissue must carry the new hash"
  assert_no_grep "unsent-to-controller: REISSUED-NOTE.md" "$REPORT_OUT" \
    "a reissued note must not be reported as unsent"

  # The change stays visible in a durable record, once.
  assert_present "$(reissue_log)" "the reissue must leave durable evidence"
  assert_grep "name=REISSUED-NOTE.md" "$(reissue_log)" \
    "the reissue evidence must name the message"
  assert_grep "sha256=$new_hash" "$(reissue_log)" \
    "the reissue evidence must carry the new hash"
  assert_grep "old_sha256=$old_hash" "$(reissue_log)" \
    "the reissue evidence must carry the old hash"
  assert_grep "visible, not blocking" "$(reissue_log)" \
    "the reissue evidence must say that it does not block"

  # It does not repeat on a second scan.
  first_rc=$(run_scan)
  first_out=$(cat "$SCAN_OUT")
  log_lines=$(wc -l < "$(reissue_log)")
  second_rc=$(run_scan)
  second_out=$(cat "$SCAN_OUT")
  expect_code "$first_rc" "$second_rc" "a second scan must reach the same exit code"
  assert_equals "$first_out" "$second_out" \
    "a second scan must produce the same output"
  assert_equals "$log_lines" "$(wc -l < "$(reissue_log)")" \
    "a reissue that is already on record must not be written again"
  pass "a reissued note is reported with both hashes, is not unsent, and does not repeat"
}

# (d) A DIFFERENT note that was never transmitted is still unsent. A reissued
# note must not make the next note pass.
test_a_different_never_transmitted_note_is_still_unsent() {
  local rc
  scenario mixed
  printf '%s\n' 'a note that is transmitted to Controller' > "$TMP_ROOT/to-send-mixed.md"
  rc=$(transmit "$TMP_ROOT/to-send-mixed.md" "SENT-NOTE.md")
  expect_code 0 "$rc" "the transmission must succeed"
  printf '%s\n' 'the same note, reissued with different bytes' > "$SCEN_OUTBOX/SENT-NOTE.md"

  printf '%s\n' 'a different note that was never sent to Controller' > "$SCEN_OUTBOX/OTHER-UNSENT.md"

  rc=$(run_scan)
  expect_code 1 "$rc" "the different unsent note must still be reported"
  assert_grep "unsent-to-controller: OTHER-UNSENT.md" "$SCAN_OUT" \
    "a different note that was never transmitted must still be reported as unsent"
  assert_no_grep "unsent-to-controller: SENT-NOTE.md" "$SCAN_OUT" \
    "the reissued note must stay out of the unsent report"
  pass "a different note that was never transmitted is still reported as unsent"
}

# A note whose name looks like a reissue but was never transmitted stays
# VISIBLE. The rule keys on the transmission record, not on the name.
test_a_never_transmitted_note_that_looks_reissued_stays_visible() {
  local rc
  scenario looks-reissued
  printf '%s\n' 'an artifact that was never sent to Controller' \
    > "$SCEN_OUTBOX/20260930-reissued-never-transmitted.md"

  rc=$(run_scan)
  expect_code 1 "$rc" "a note that was never transmitted must still report"
  assert_grep "unsent-to-controller: 20260930-reissued-never-transmitted.md" "$SCAN_OUT" \
    "a never-transmitted note must never be suppressed because of its name"
  pass "a never-transmitted note that looks reissued stays visible"
}

# The oldest unsent note is reported first, with its real age, so the note that
# has been waiting longest is the one that is read first.
test_the_oldest_unsent_note_is_reported_first_with_its_age() {
  local rc first_line older_age younger_age
  scenario oldest
  printf '%s\n' 'a younger note that was never sent' > "$SCEN_OUTBOX/OLDER-NAME.md"
  printf '%s\n' 'an older note that was never sent' > "$SCEN_OUTBOX/Z-NAME.md"
  set_old "$SCEN_OUTBOX/Z-NAME.md" 86400

  rc=$(run_scan)
  expect_code 1 "$rc" "both unsent notes must be reported"
  first_line=$(head -1 "$SCAN_OUT")
  assert_contains "$first_line" "Z-NAME.md" \
    "the first reported note must be the oldest one, not the alphabetically first one"

  older_age=$(printf '%s\n' "$first_line" | sed -n 's/.*age_days=//p')
  younger_age=$(grep 'OLDER-NAME.md' "$SCAN_OUT" | sed -n 's/.*age_days=//p')
  [ -n "$older_age" ] || fail "the oldest unsent note must carry its age"
  [ "$older_age" -ge "$younger_age" ] \
    || fail "the oldest unsent note must carry the older age ($older_age < $younger_age)"
  pass "the oldest unsent note is reported first with its real age"
}

# A transmission that the hash ledger can prove but that predates the
# name-keyed record is reconciled by name, so the note does not read as
# unsent and a later reissue of it is recognisable as a reissue.
test_a_transmission_proved_by_the_hash_ledger_is_reconciled_by_name() {
  local rc
  scenario reconcile
  printf '%s\n' 'a note transmitted before the name ledger existed' > "$SCEN_OUTBOX/LEGACY-NOTE.md"
  # The legacy evidence: the bytes are on record in the hash ledger, under no
  # name at all.
  file_sha "$SCEN_OUTBOX/LEGACY-NOTE.md" > "$SCEN_HOME/state/.controller-inbox-outbound"

  rc=$(run_scan)
  expect_code 0 "$rc" "a note whose bytes are on record is not pending"
  assert_present "$SCEN_HOME/state/.controller-inbox-outbound-names" \
    "the reconciliation must write the name ledger"
  assert_grep "LEGACY-NOTE.md" "$SCEN_HOME/state/.controller-inbox-outbound-names" \
    "the reconciliation must record the name of a provably transmitted note"
  assert_grep "LEGACY-NOTE.md" "$SCEN_HOME/state/.controller-inbox-outbound-transmitted" \
    "the reconciliation must record the transmission of a provably transmitted note"
  pass "a transmission proved by the hash ledger is reconciled by name"
}

test_a_note_that_was_never_transmitted_is_reported_unsent
test_a_transmitted_note_is_not_reported
test_the_transmission_is_recorded_by_name
test_a_reissued_note_is_reported_and_does_not_block
test_a_different_never_transmitted_note_is_still_unsent
test_a_never_transmitted_note_that_looks_reissued_stays_visible
test_the_oldest_unsent_note_is_reported_first_with_its_age
test_a_transmission_proved_by_the_hash_ledger_is_reconciled_by_name
