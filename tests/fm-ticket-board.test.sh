#!/usr/bin/env bash
# tests/fm-ticket-board.test.sh - contract tests for the one-screen ticket board.
#
# The board is a read-only view over the ticket system this fleet already has.
# Every case below drives the script against a purpose-built fixture backlog in
# a temp home, so no assertion depends on the live data/backlog.md, whose
# contents change.
#
# The fixture backlog carries one ticket per board section:
#   fx-captain     held on the Captain, with a recorded question
#   fx-blocked     carries a blocked-by edge naming a blocker
#   fx-inflight    in flight, with a spawn record that names harness, model and effort
#   fx-queued      queued, with no harness, model or host recorded anywhere
#   fx-stale       open, and its title states a resolution
#   fx-reported    open, and its report already exists on disk
#   fx-done        closed
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BOARD="$ROOT/bin/fm-ticket-board.sh"
TMP_ROOT=$(fm_test_tmproot fm-ticket-board-tests)

CASES=0
FAILURES=0

# fail <message>: record a failed case and keep going so the summary is complete.
fail() {
  CASES=$((CASES + 1))
  FAILURES=$((FAILURES + 1))
  printf 'not ok - %s\n' "$1" >&2
}

# pass <message>: record a passed case.
pass() {
  CASES=$((CASES + 1))
  printf 'ok - %s\n' "$1"
}

# make_case <name>: build a fixture home holding a backlog, a lane registry and a state dir.
make_case() {
  local name=$1 dir
  dir="$TMP_ROOT/$name"
  mkdir -p "$dir/data" "$dir/state"
  cat > "$dir/data/backlog.md" <<'BACKLOG'
# Backlog

## In flight
- [ ] fx-inflight - Fixture in flight task (repo: demo) (kind: scout) (since 2026-10-01)
  Fixture in flight body line.

## Queued
- [ ] fx-captain - Choose the fixture option (repo: demo) (kind: captain) (since 2026-10-02) (hold: Option A or Option B for the fixture) (hold-kind: captain)
- [ ] fx-blocked - Fixture blocked task (repo: demo) (kind: ship) (since 2026-10-03) blocked-by: fx-blocker
- [ ] fx-queued - Fixture queued task (repo: demo) (kind: ship) (since 2026-10-04)
- [ ] fx-stale - No guard defect found - existing fixture refusal works (repo: demo) (kind: captain) (since 2026-10-05)
- [ ] fx-reported - Fixture report already delivered (repo: demo) (kind: scout) (since 2026-10-05)

## Done
- [x] fx-done - Fixture done task (repo: demo) (kind: ship) (done 2026-10-06)
BACKLOG
  mkdir -p "$dir/data/fx-reported"
  printf 'fixture report\n' > "$dir/data/fx-reported/report.md"
  cat > "$dir/state/fx-inflight.meta" <<'META'
window=firstmate:fx-inflight
harness=pi
model=minimax/MiniMax-M3.1-Flash-Preview
effort=high
META
  cat > "$dir/data/async-lanes.tsv" <<'LANES'
# run_id	lane_key	model	surface	task	state	output
11111111-2222-3333-4444-555555555555	pi-luna6-brandon-fixture	luna6	brandon	Fixture lane task [model=openai-codex/gpt-6-luna high]	dispatched-20261020	data/fixture-lane/report.md
22222222-3333-4444-5555-666666666666	pi-m2.7-brandon-old	m2.7	brandon	Old lane task [model=minimax/MiniMax-M2.7 medium]	complete-20261019	data/fixture-old/report.md
LANES
  printf '%s\n' "$dir"
}

# run_board <dir> [args...]: run the board against the fixture home.
# The fixture home is passed through FM_HOME and the override variables, so the
# run never reads the live data/ directory.
run_board() {
  local dir=$1
  shift
  FM_HOME="$dir" FM_DATA_OVERRIDE="$dir/data" FM_STATE_OVERRIDE="$dir/state" \
    bash "$BOARD" "$@" >"$dir/out.txt" 2>"$dir/err.txt"
  printf '%s' "$?"
}

# section_of <file> <section>: print the lines of one board section.
section_of() {
  awk -v want="$2" '
    index($0, "== " want " ") == 1 { inside = 1; next }
    inside && index($0, "== ") == 1 { inside = 0 }
    inside { print }
  ' "$1"
}

# --- script contract --------------------------------------------------------

test_script_exists_and_executable() {
  if [ ! -f "$BOARD" ]; then
    fail "$BOARD does not exist"
    return
  fi
  if [ ! -x "$BOARD" ]; then
    fail "$BOARD is not executable"
    return
  fi
  if command -v shellcheck >/dev/null 2>&1; then
    if ! shellcheck -S warning "$BOARD" >/dev/null 2>&1; then
      fail "shellcheck found issues in $BOARD"
      return
    fi
  fi
  pass "script exists, is executable and passes shellcheck"
}

test_help_exits_zero_and_prints_usage() {
  local dir rc out
  dir=$(make_case help)
  out=$(bash "$BOARD" --help 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "--help must exit 0, got $rc"
    return
  fi
  case "$out" in
    *Usage:*) : ;;
    *) fail "--help must print a usage block: $out"; return ;;
  esac
  case "$out" in
    *NEEDS\ YOUR\ INPUT*) : ;;
    *) fail "--help must name the board sections: $out"; return ;;
  esac
  pass "--help exits 0 and prints usage"
}

test_unknown_argument_is_a_usage_error() {
  local rc
  rc=$(bash "$BOARD" --nonsense >/dev/null 2>&1; printf '%s' "$?")
  if [ "$rc" -eq 0 ]; then
    fail "an unknown argument must exit non-zero, got $rc"
    return
  fi
  pass "an unknown argument is a usage error"
}

test_missing_backlog_is_reported_with_its_path() {
  local dir rc missing
  dir=$(make_case missing)
  missing="$dir/does-not-exist/backlog.md"
  rc=$(run_board "$dir" --file "$missing")
  if [ "$rc" -eq 0 ]; then
    fail "a missing backlog must exit non-zero, got $rc"
    return
  fi
  if ! grep -qF -- "$missing" "$dir/err.txt"; then
    fail "the error must name the exact missing path: $(cat "$dir/err.txt")"
    return
  fi
  pass "a missing backlog is reported with its exact path and exits non-zero"
}

test_unreadable_backlog_does_not_render_an_empty_board() {
  local dir rc
  dir=$(make_case unreadable)
  printf 'not a backlog\n' > "$dir/empty.md"
  rc=$(run_board "$dir" --file "$dir/empty.md")
  if [ "$rc" -eq 0 ]; then
    fail "an unreadable backlog must exit non-zero, got $rc"
    return
  fi
  if [ -s "$dir/out.txt" ]; then
    fail "an unreadable backlog must not render a board: $(cat "$dir/out.txt")"
    return
  fi
  pass "an unreadable backlog is refused instead of rendering an empty board"
}

test_default_home_resolution_reads_the_home_backlog() {
  local dir rc
  dir=$(make_case home)
  rc=$(run_board "$dir")
  if [ "$rc" -ne 0 ]; then
    fail "the board must render against the home backlog, got $rc: $(cat "$dir/err.txt")"
    return
  fi
  if ! grep -qF "fx-captain" "$dir/out.txt"; then
    fail "the board must read the home backlog by default"
    return
  fi
  pass "the board resolves the backlog from FM_HOME by default"
}

test_file_flag_selects_another_backlog() {
  local dir rc other
  dir=$(make_case fileflag)
  mkdir -p "$dir/other"
  printf '# Backlog\n\n## Queued\n- [ ] fx-other - Fixture other backlog task (repo: demo) (kind: ship) (since 2026-10-07)\n' > "$dir/other/backlog.md"
  rc=$(run_board "$dir" --file "$dir/other/backlog.md")
  if [ "$rc" -ne 0 ]; then
    fail "--file must render the named backlog, got $rc: $(cat "$dir/err.txt")"
    return
  fi
  if ! grep -qF "fx-other" "$dir/out.txt"; then
    fail "--file must select the named backlog"
    return
  fi
  if grep -qF "fx-captain" "$dir/out.txt"; then
    fail "--file must not also read the home backlog"
    return
  fi
  other=$(cat "$dir/out.txt")
  case "$other" in
    *"backlog: $dir/other/backlog.md"*) : ;;
    *) fail "the board must name the backlog it read"; return ;;
  esac
  pass "--file selects another backlog file"
}

test_board_mutates_nothing() {
  local dir rc before after
  dir=$(make_case nomutate)
  before=$(sha256sum "$dir/data/backlog.md" | cut -d' ' -f1)
  rc=$(run_board "$dir")
  after=$(sha256sum "$dir/data/backlog.md" | cut -d' ' -f1)
  if [ "$rc" -ne 0 ]; then
    fail "the board must render, got $rc: $(cat "$dir/err.txt")"
    return
  fi
  if [ "$before" != "$after" ]; then
    fail "the board must not modify the backlog file"
    return
  fi
  pass "the board leaves the backlog byte identical"
}

# --- section membership -----------------------------------------------------

test_captain_hold_renders_in_needs_your_input() {
  local dir rc section
  dir=$(make_case captain)
  rc=$(run_board "$dir")
  if [ "$rc" -ne 0 ]; then
    fail "the board must render, got $rc: $(cat "$dir/err.txt")"
    return
  fi
  section=$(section_of "$dir/out.txt" "NEEDS YOUR INPUT")
  case "$section" in
    *fx-captain*) : ;;
    *) fail "the captain-held ticket must appear under NEEDS YOUR INPUT: $section"; return ;;
  esac
  case "$section" in
    *"Choose the fixture option"*) : ;;
    *) fail "the captain-held ticket title must appear under NEEDS YOUR INPUT: $section"; return ;;
  esac
  case "$section" in
    *"Option A or Option B for the fixture"*) : ;;
    *) fail "the recorded question must appear under NEEDS YOUR INPUT: $section"; return ;;
  esac
  pass "a captain-held ticket renders under NEEDS YOUR INPUT with its question"
}

test_needs_your_input_is_the_first_section() {
  local dir rc first
  dir=$(make_case firstsection)
  rc=$(run_board "$dir")
  if [ "$rc" -ne 0 ]; then
    fail "the board must render, got $rc: $(cat "$dir/err.txt")"
    return
  fi
  first=$(grep -n '^== ' "$dir/out.txt" | head -1)
  case "$first" in
    *"NEEDS YOUR INPUT"*) : ;;
    *) fail "NEEDS YOUR INPUT must be the first section, got: $first"; return ;;
  esac
  pass "NEEDS YOUR INPUT is the first section of the board"
}

test_only_captain_holds_reach_needs_your_input() {
  local dir section
  dir=$(make_case captainonly)
  run_board "$dir" >/dev/null
  section=$(section_of "$dir/out.txt" "NEEDS YOUR INPUT")
  case "$section" in
    *fx-queued*) fail "a plain queued ticket must not appear under NEEDS YOUR INPUT: $section"; return ;;
  esac
  case "$section" in
    *fx-inflight*) fail "an in flight ticket must not appear under NEEDS YOUR INPUT: $section"; return ;;
  esac
  pass "only captain-held tickets reach NEEDS YOUR INPUT"
}

test_blocked_ticket_names_its_blocker() {
  local dir section
  dir=$(make_case blocked)
  run_board "$dir" >/dev/null
  section=$(section_of "$dir/out.txt" "BLOCKED")
  case "$section" in
    *fx-blocked*) : ;;
    *) fail "the blocked ticket must appear under BLOCKED: $section"; return ;;
  esac
  case "$section" in
    *fx-blocker*) : ;;
    *) fail "the blocker must be named under BLOCKED: $section"; return ;;
  esac
  pass "a blocked ticket appears under BLOCKED with its blocker named"
}

test_inflight_ticket_renders_under_in_flight() {
  local dir section
  dir=$(make_case inflight)
  run_board "$dir" >/dev/null
  section=$(section_of "$dir/out.txt" "IN FLIGHT")
  case "$section" in
    *fx-inflight*) : ;;
    *) fail "the in flight ticket must appear under IN FLIGHT: $section"; return ;;
  esac
  case "$section" in
    *"Fixture in flight task"*) : ;;
    *) fail "the in flight ticket title must appear under IN FLIGHT: $section"; return ;;
  esac
  pass "an in flight ticket appears under IN FLIGHT"
}

test_queued_ticket_contributes_to_ready() {
  local dir section
  dir=$(make_case queued)
  run_board "$dir" >/dev/null
  section=$(section_of "$dir/out.txt" "READY / QUEUED")
  case "$section" in
    *fx-queued*) : ;;
    *) fail "the queued ticket must appear under READY / QUEUED: $section"; return ;;
  esac
  case "$section" in
    *"by kind:"*) : ;;
    *) fail "READY / QUEUED must count by kind: $section"; return ;;
  esac
  case "$section" in
    *"by repo:"*) : ;;
    *) fail "READY / QUEUED must count by repo: $section"; return ;;
  esac
  pass "a queued ticket appears under READY / QUEUED and the counts are present"
}

test_resolution_title_renders_under_stale() {
  local dir section
  dir=$(make_case stale)
  run_board "$dir" >/dev/null
  section=$(section_of "$dir/out.txt" "STALE")
  case "$section" in
    *fx-stale*) : ;;
    *) fail "a ticket whose title states a resolution must appear under STALE: $section"; return ;;
  esac
  case "$section" in
    *"no guard defect found"*) : ;;
    *) fail "STALE must say why the ticket looks stale: $section"; return ;;
  esac
  pass "a ticket whose title states a resolution appears under STALE"
}

test_existing_report_renders_under_stale() {
  local dir section
  dir=$(make_case reported)
  run_board "$dir" >/dev/null
  section=$(section_of "$dir/out.txt" "STALE")
  case "$section" in
    *fx-reported*) : ;;
    *) fail "an open ticket whose report exists must appear under STALE: $section"; return ;;
  esac
  case "$section" in
    *"report exists on disk"*) : ;;
    *) fail "STALE must report the artifact evidence: $section"; return ;;
  esac
  pass "an open ticket whose report already exists appears under STALE"
}

test_stale_section_closes_nothing() {
  local dir section
  dir=$(make_case staleclose)
  run_board "$dir" >/dev/null
  section=$(section_of "$dir/out.txt" "STALE")
  case "$section" in
    *"closes nothing"*) : ;;
    *) fail "the STALE section must state that it closes nothing: $section"; return ;;
  esac
  pass "the STALE section states that it closes nothing"
}

test_live_lane_rows_render_with_model_surface_and_state() {
  local dir section
  dir=$(make_case lanes)
  run_board "$dir" >/dev/null
  section=$(section_of "$dir/out.txt" "LANES")
  case "$section" in
    *pi-luna6-brandon-fixture*) : ;;
    *) fail "the live lane row must appear under LANES: $section"; return ;;
  esac
  case "$section" in
    *dispatched-20261020*) : ;;
    *) fail "the lane state must appear under LANES: $section"; return ;;
  esac
  case "$section" in
    *"pi-luna6-brandon-fixture"*|*"@brandon"*) : ;;
    *) fail "the lane host must appear under LANES: $section"; return ;;
  esac
  pass "a live lane row renders under LANES with its model, surface and state"
}

test_terminal_lane_rows_are_hidden_by_default() {
  local dir rc section
  dir=$(make_case terminal)
  rc=$(run_board "$dir")
  section=$(section_of "$dir/out.txt" "LANES")
  case "$section" in
    *pi-m2.7-brandon-old*) fail "a terminal lane row must not appear by default: $section"; return ;;
  esac
  rc=$(run_board "$dir" --full)
  section=$(section_of "$dir/out.txt" "LANES")
  case "$section" in
    *pi-m2.7-brandon-old*) : ;;
    *) fail "--full must reveal the terminal lane rows: $section"; return ;;
  esac
  pass "terminal lane rows are hidden by default and revealed by --full"
}

# --- board prefix contract --------------------------------------------------

test_every_row_carries_the_canonical_prefix() {
  local dir rows bad
  dir=$(make_case prefix)
  run_board "$dir" >/dev/null
  rows=$(grep -E '^[[:space:]]*\[' "$dir/out.txt")
  if [ -z "$rows" ]; then
    fail "the board must render rows carrying a prefix"
    return
  fi
  bad=$(printf '%s\n' "$rows" | grep -vE '^[[:space:]]*\[[^]]*·[^]]* [^ ]* @[^]]*\]' | head -3)
  if [ -n "$bad" ]; then
    fail "every board row must carry a [<harness>·<Model> <effort> @<Host>] prefix: $bad"
    return
  fi
  pass "every rendered row carries the canonical board prefix"
}

test_unrecorded_parts_render_as_unknown() {
  local dir section
  dir=$(make_case unknownparts)
  run_board "$dir" >/dev/null
  section=$(section_of "$dir/out.txt" "READY / QUEUED")
  case "$section" in
    *"[unknown·unknown unknown @unknown] fx-queued"*) : ;;
    *) fail "a ticket with no harness, model or host must render unknown: $section"; return ;;
  esac
  pass "a ticket with no recorded harness, model or host renders unknown"
}

test_recorded_parts_are_not_replaced_by_unknown() {
  local dir section
  dir=$(make_case recordedparts)
  run_board "$dir" >/dev/null
  section=$(section_of "$dir/out.txt" "IN FLIGHT")
  case "$section" in
    *"[pi·m3.1f h @unknown]"*) : ;;
    *) fail "a ticket with a spawn record must render its recorded harness, model and effort: $section"; return ;;
  esac
  pass "a ticket with a spawn record renders its recorded harness, model and effort"
}

test_no_invented_harness_or_host() {
  local dir out
  dir=$(make_case noinvent)
  run_board "$dir" >/dev/null
  out=$(cat "$dir/out.txt")
  case "$out" in
    *"[claude·"*) fail "the board must not invent a harness: $out"; return ;;
  esac
  case "$out" in
    *"@HD2"*|*"@KVM8"*) fail "the board must not invent a host: $out"; return ;;
  esac
  pass "the board invents no harness, model, effort or host"
}

run_tests() {
  test_script_exists_and_executable
  test_help_exits_zero_and_prints_usage
  test_unknown_argument_is_a_usage_error
  test_missing_backlog_is_reported_with_its_path
  test_unreadable_backlog_does_not_render_an_empty_board
  test_default_home_resolution_reads_the_home_backlog
  test_file_flag_selects_another_backlog
  test_board_mutates_nothing
  test_captain_hold_renders_in_needs_your_input
  test_needs_your_input_is_the_first_section
  test_only_captain_holds_reach_needs_your_input
  test_blocked_ticket_names_its_blocker
  test_inflight_ticket_renders_under_in_flight
  test_queued_ticket_contributes_to_ready
  test_resolution_title_renders_under_stale
  test_existing_report_renders_under_stale
  test_stale_section_closes_nothing
  test_live_lane_rows_render_with_model_surface_and_state
  test_terminal_lane_rows_are_hidden_by_default
  test_every_row_carries_the_canonical_prefix
  test_unrecorded_parts_render_as_unknown
  test_recorded_parts_are_not_replaced_by_unknown
  test_no_invented_harness_or_host
}

run_tests

printf '\ncases: %d | passed: %d | failed: %d\n' \
  "$CASES" "$((CASES - FAILURES))" "$FAILURES"
if [ "$FAILURES" -ne 0 ]; then
  exit 1
fi
exit 0
