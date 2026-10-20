#!/usr/bin/env bash
# tests/fm-herdr-agent-report.test.sh - the MCode side of Herdr's self-report
# path. Herdr has no built-in MCode adapter, so this reporter is what makes an
# MCode pane visible to `herdr agent list` and lights its running and stopped
# indicator.
# The suite drives the reporter through its executable interface against a
# recording herdr stub, so it asserts the published call contract and never
# the reporter's source bytes.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPORTER="$ROOT/bin/fm-herdr-agent-report.sh"
TMP_ROOT=$(fm_test_tmproot fm-herdr-agent-report-tests)

# A recording stand-in for the herdr CLI. It appends one framed block per
# invocation to the log file named by HERDR_CALL_LOG.
recording_herdr() {
  local dir=$1
  cat > "$dir/herdr" <<'REC'
#!/usr/bin/env bash
{
  printf 'CALL\n'
  for arg in "$@"; do printf '%s\n' "$arg"; done
  printf 'END\n'
} >> "$HERDR_CALL_LOG"
exit 0
REC
  chmod +x "$dir/herdr"
}

# A herdr stand-in that always fails, standing in for a broken or hung server.
failing_herdr() {
  local dir=$1
  cat > "$dir/herdr-broken" <<'REC'
#!/usr/bin/env bash
exit 1
REC
  chmod +x "$dir/herdr-broken"
}

make_case() {
  local name=$1 dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir/home"
  recording_herdr "$dir"
  failing_herdr "$dir"
  printf '%s\n' "$dir"
}

# run_reporter <dir> <log> <verb> [payload]: drive the reporter with the
# Herdr environment set. It returns the reporter's exit code.
run_reporter() {
  local dir=$1 log=$2 verb=$3 payload=${4:-}
  if [ -n "$payload" ]; then
    printf '%s' "$payload" | HERDR_ENV=1 HERDR_PANE_ID=w64:p1C \
      HERDR_BIN_PATH="$dir/herdr" HERDR_CALL_LOG="$log" FM_HOME="$dir/home" \
      bash "$REPORTER" "$verb" >/dev/null 2>&1
  else
    HERDR_ENV=1 HERDR_PANE_ID=w64:p1C HERDR_BIN_PATH="$dir/herdr" \
      HERDR_CALL_LOG="$log" FM_HOME="$dir/home" \
      bash "$REPORTER" "$verb" >/dev/null 2>&1
  fi
}

test_working_state_is_reported() {
  local dir log rc=0
  dir=$(make_case working)
  log="$dir/calls.log"
  : > "$log"
  run_reporter "$dir" "$log" working || rc=$?
  expect_code 0 "$rc" "the reporter must exit 0 after a working report"
  assert_grep "report-agent" "$log" "the working report must call pane report-agent"
  assert_grep "w64:p1C" "$log" "the report must name the reporting pane"
  assert_grep "--source" "$log" "the report must declare its source"
  assert_grep "mcode" "$log" "the report must identify the mcode agent"
  assert_grep "--state" "$log" "the report must declare a state"
  assert_grep "working" "$log" "the report must carry the working state"
  pass "the working state is reported to Herdr"
}

test_idle_and_blocked_states_are_reported() {
  local dir log rc=0
  dir=$(make_case states)
  log="$dir/calls.log"
  : > "$log"
  run_reporter "$dir" "$log" idle || rc=$?
  expect_code 0 "$rc" "the reporter must exit 0 after an idle report"
  assert_grep "idle" "$log" "the idle report must carry the idle state"
  : > "$log"
  rc=0
  run_reporter "$dir" "$log" blocked || rc=$?
  expect_code 0 "$rc" "the reporter must exit 0 after a blocked report"
  assert_grep "blocked" "$log" "the blocked report must carry the blocked state"
  pass "the idle and blocked states are reported to Herdr"
}

test_session_start_reports_identity_and_resume() {
  local dir log rc=0
  dir=$(make_case session-start)
  log="$dir/calls.log"
  : > "$log"
  run_reporter "$dir" "$log" session-start '{"session_id":"sess-4242"}' || rc=$?
  expect_code 0 "$rc" "the reporter must exit 0 after a session start"
  assert_grep "report-agent-session" "$log" "a session start must report the session identity"
  assert_grep "sess-4242" "$log" "the session start must carry the session id"
  assert_grep "mcode" "$log" "the session start must identify the mcode agent"
  assert_grep "--session" "$log" "the session start must offer a resume command"
  pass "a session start reports the session identity and a resume command"
}

test_release_releases_the_agent() {
  local dir log rc=0
  dir=$(make_case release)
  log="$dir/calls.log"
  : > "$log"
  run_reporter "$dir" "$log" release || rc=$?
  expect_code 0 "$rc" "the reporter must exit 0 after a release"
  assert_grep "release-agent" "$log" "a session end must release the pane's agent authority"
  pass "a session end releases the pane's agent authority"
}

test_sequence_numbers_strictly_increase() {
  local dir log rc=0 first second
  dir=$(make_case seq)
  log="$dir/calls.log"
  : > "$log"
  run_reporter "$dir" "$log" working || rc=$?
  expect_code 0 "$rc" "the first report must succeed"
  first=$(grep -A1 -x -- "--seq" "$log" | grep -E '^[0-9]+$' | head -n 1)
  rc=0
  run_reporter "$dir" "$log" working || rc=$?
  expect_code 0 "$rc" "the second report must succeed"
  second=$(grep -A1 -x -- "--seq" "$log" | grep -E '^[0-9]+$' | tail -n 1)
  [ -n "$first" ] && [ -n "$second" ] || fail "both reports must carry a sequence number"
  [ "$second" -gt "$first" ] || fail "the sequence number must increase between reports ($first then $second)"
  pass "the sequence number strictly increases between reports"
}

test_outside_herdr_reports_nothing() {
  local dir log rc=0
  dir=$(make_case outside)
  log="$dir/calls.log"
  : > "$log"
  env -u HERDR_ENV HERDR_PANE_ID=w64:p1C HERDR_BIN_PATH="$dir/herdr" HERDR_CALL_LOG="$log" \
    FM_HOME="$dir/home" bash "$REPORTER" working >/dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" "the reporter must exit 0 outside a Herdr pane"
  [ -s "$log" ] && fail "no Herdr call may happen outside a Herdr pane"
  pass "nothing is reported outside a Herdr pane"
}

test_invalid_verb_reports_nothing() {
  local dir log rc=0
  dir=$(make_case invalid)
  log="$dir/calls.log"
  : > "$log"
  run_reporter "$dir" "$log" nonsense || rc=$?
  expect_code 0 "$rc" "an unknown verb must exit 0"
  [ -s "$log" ] && fail "an unknown verb must not call Herdr"
  pass "an unknown verb reports nothing"
}

test_broken_herdr_never_fails_the_turn() {
  local dir log rc=0
  dir=$(make_case broken)
  log="$dir/calls.log"
  : > "$log"
  HERDR_ENV=1 HERDR_PANE_ID=w64:p1C HERDR_BIN_PATH="$dir/herdr-broken" \
    HERDR_CALL_LOG="$log" FM_HOME="$dir/home" \
    bash "$REPORTER" working >/dev/null 2>&1 || rc=$?
  expect_code 0 "$rc" "a broken Herdr must never fail the agent turn"
  pass "a broken Herdr never fails the agent turn"
}

run_tests() {
  test_working_state_is_reported
  test_idle_and_blocked_states_are_reported
  test_session_start_reports_identity_and_resume
  test_release_releases_the_agent
  test_sequence_numbers_strictly_increase
  test_outside_herdr_reports_nothing
  test_invalid_verb_reports_nothing
  test_broken_herdr_never_fails_the_turn
}

run_tests
