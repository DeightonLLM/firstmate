#!/usr/bin/env bash
# Behavior tests for lane-todo-board.sh - the single-screen board that keeps every
# active lane's To-Do list visible at the same time.
#
# Coverage: render (header format, verbatim todo rendering, done/pending marks,
# status tails, model/surface/pane resolution, lane discovery, ordering), every
# empty state, and --init-lane scaffold creation plus its fail-closed guards.
#
# Self-contained on purpose: every case builds a throwaway FM_HOME, so these tests
# never read or write the real firstmate home and never touch the network.
#
# TAP: one line per case, `#` detail lines under a failure.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD="$SELF_DIR/lane-todo-board.sh"
DASH="$SELF_DIR/lane-todo-dash.sh"

TMP_ROOT=""
CASES_RUN=0
CASE_NAME=""
CASE_FAILS=0
CASE_DETAIL=""
CASE_ASSERTIONS=0
FAILED=0
OUT=""
RC=0
SERVER_PID=""

# shellcheck disable=SC2329 # Invoked by the EXIT trap below, not by name.
cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf -- "$TMP_ROOT"
  fi
}
trap cleanup EXIT

start_case() {
  CASE_NAME="$1"
  CASE_FAILS=0
  CASE_DETAIL=""
  CASES_RUN=$((CASES_RUN + 1))
}

pass() {
  CASE_ASSERTIONS=$((CASE_ASSERTIONS + 1))
}

fail() {
  CASE_ASSERTIONS=$((CASE_ASSERTIONS + 1))
  CASE_FAILS=$((CASE_FAILS + 1))
  CASE_DETAIL="${CASE_DETAIL}  # ${1:-assertion failed}"$'\n'
}

end_case() {
  if [ "$CASE_FAILS" -eq 0 ]; then
    printf 'ok %d - %s\n' "$CASES_RUN" "$CASE_NAME"
  else
    FAILED=$((FAILED + 1))
    printf 'not ok %d - %s\n' "$CASES_RUN" "$CASE_NAME"
    printf '%s' "$CASE_DETAIL"
  fi
}

# Fixed-string assertions: todo content is markdown, so every needle that can
# contain [, ], *, or ? must never be read as a glob pattern.
assert_has() {  # <substring> <why>
  if printf '%s\n' "$OUT" | grep -qF -- "$1"; then
    pass
  else
    fail "${2:-expected substring missing: $1}"
  fi
}

assert_lacks() {  # <substring> <why>
  if printf '%s\n' "$OUT" | grep -qF -- "$1"; then
    fail "${2:-unexpected substring present: $1}"
  else
    pass
  fi
}

assert_line() {  # <exact line> <why>
  if printf '%s\n' "$OUT" | grep -qxF -- "$1"; then
    pass
  else
    fail "${2:-expected line missing: $1}"
  fi
}

assert_status() {  # <expected> <why>
  if [ "$1" = "$RC" ]; then
    pass
  else
    fail "${2:-expected exit $1, got $RC}"
  fi
}

assert_eq() {  # <actual> <expected> <why>
  if [ "$1" = "$2" ]; then
    pass
  else
    fail "${3:-expected [$2], got [$1]}"
  fi
}

assert_file() {  # <path> <why>
  if [ -f "$1" ]; then
    pass
  else
    fail "${2:-expected file to exist: $1}"
  fi
}

assert_no_file() {  # <path> <why>
  if [ -f "$1" ]; then
    fail "${2:-expected file to be absent: $1}"
  else
    pass
  fi
}

assert_grep_file() {  # <path> <regex> <why>
  if [ -f "$1" ] && grep -Eq -- "$2" "$1"; then
    pass
  else
    fail "${3:-expected pattern missing from $1: $2}"
  fi
}

assert_file_has() {  # <path> <literal> <why>
  if [ -f "$1" ] && grep -qF -- "$2" "$1"; then
    pass
  else
    fail "${3:-expected literal missing from $1: $2}"
  fi
}

# A stub lavish-axi records every invocation as one tab-separated CALL line, so a
# test can assert on the exact argv the dashboard hands to Lavish. The real
# adapter and the real runner still execute, so the registration under test is
# the genuine one the sanctioned owner writes.
write_lavish_stub() {  # <home>
  local home="$1"
  mkdir -p "$home/fakebin"
  cat > "$home/fakebin/lavish-axi" <<'STUB'
#!/usr/bin/env bash
{ printf 'CALL'; printf '\t%s' "$@"; printf '\n'; } >> "${LAVISH_STUB_LOG:?}"
exit 0
STUB
  chmod +x "$home/fakebin/lavish-axi"
}

run_dash_cmd() {  # <home> [args...] -> sets OUT and RC
  local home="$1"
  shift
  OUT=$(cd "$home" && FM_HOME="$home" HERDR_PANE_LIST_FILE="$home/herdr-panes.txt" \
        LAVISH_STUB_LOG="$home/lavish-calls.log" PATH="$home/fakebin:$PATH" \
        bash "$DASH" "$@" 2>&1)
  RC=$?
}


# Extract the board region between two sentinel todo lines and require it to be
# byte-identical to the todo file: that is what "rendered verbatim" means.
assert_verbatim() {  # <todo file> <first sentinel> <last sentinel> <why>
  local extracted
  extracted=$(awk -v first="$2" -v last="$3" '
    $0 == first { inside = 1 }
    inside { print }
    $0 == last && inside { exit }
  ' <<< "$OUT")
  if [ "$extracted" = "$(cat "$1")" ]; then
    pass
  else
    fail "${4:-todo file was not rendered verbatim}"
  fi
}

new_home() {  # <name> -> prints a fresh throwaway home
  local home
  home="$TMP_ROOT/home-$1"
  mkdir -p "$home"
  printf '%s' "$home"
}

run_board() {  # <home> [args...] -> sets OUT and RC
  local home="$1"
  shift
  OUT=$(FM_HOME="$home" bash "$BOARD" "$@" 2>&1)
  RC=$?
}

run_dash() {  # <home> <output> -> sets OUT and RC
  local home="$1" output="$2"
  OUT=$(FM_HOME="$home" HERDR_PANE_LIST_FILE="$home/herdr-panes.txt" bash "$DASH" "$output" 2>&1)
  RC=$?
}

free_port() {
  python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

write_lane() {  # <home> <lane> <key=value>...
  local home="$1" lane="$2" line
  shift 2
  mkdir -p "$home/state/lanes"
  : > "$home/state/lanes/$lane.lane"
  for line in "$@"; do
    printf '%s\n' "$line" >> "$home/state/lanes/$lane.lane"
  done
}

write_todo() {  # <home> <lane> <line>...
  local home="$1" lane="$2" line
  shift 2
  mkdir -p "$home/state/lanes"
  : > "$home/state/lanes/$lane.todo.md"
  for line in "$@"; do
    printf '%s\n' "$line" >> "$home/state/lanes/$lane.todo.md"
  done
}

write_status() {  # <home> <task> <line>...
  local home="$1" task="$2" line
  shift 2
  mkdir -p "$home/state"
  : > "$home/state/$task.status"
  for line in "$@"; do
    printf '%s\n' "$line" >> "$home/state/$task.status"
  done
}

write_meta() {  # <home> <task> <key=value>...
  local home="$1" task="$2" line
  shift 2
  mkdir -p "$home/state"
  : > "$home/state/$task.meta"
  for line in "$@"; do
    printf '%s\n' "$line" >> "$home/state/$task.meta"
  done
}

if [ ! -f "$BOARD" ]; then
  start_case "the board script exists"
  fail "missing $BOARD"
  end_case
  printf '1..%d\n' "$CASES_RUN"
  printf '# lane-todo-board: %d cases failed\n' "$FAILED"
  exit 1
fi

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/lane-todo-board.test.XXXXXX") || {
  printf 'Bail out! cannot create temp root\n'
  exit 1
}

# --- help and usage ---------------------------------------------------------

start_case "--help documents --init-lane and exits 0"
home=$(new_home help)
run_board "$home" --help
assert_status 0 "--help should succeed"
assert_has "--init-lane" "--help should document the scaffold flag"
end_case

start_case "an unknown flag is a usage error"
home=$(new_home badflag)
run_board "$home" --nope
assert_status 1 "unknown flag should exit 1"
assert_lacks "=== lane todo board ===" "usage error must not render a board"
end_case

start_case "--tail rejects a non-positive count"
home=$(new_home badtail)
run_board "$home" --tail 0
assert_status 1 "--tail 0 should exit 1"
assert_lacks "=== lane todo board ===" "a bad --tail must not render a board"
end_case

# --- empty states -----------------------------------------------------------

start_case "a home with no state directory renders the empty board"
home=$(new_home nostate)
run_board "$home"
assert_status 0 "missing state must degrade, not fail"
assert_has "=== lane todo board ===" "board header missing"
assert_has "(no active lanes)" "empty state must be explicit"
end_case

start_case "an existing but empty lanes directory renders the empty board"
home=$(new_home emptylanes)
mkdir -p "$home/state/lanes"
run_board "$home"
assert_status 0 "empty lanes dir must not fail"
assert_has "(no active lanes)" "empty lanes dir must be explicit"
end_case

start_case "only archived lanes means no active lanes"
home=$(new_home archivedonly)
write_lane "$home" "old-one" "pane=w1:p1"
write_todo "$home" "old-one" "- [x] done work"
mkdir -p "$home/state/lanes/archived"
mv "$home/state/lanes/old-one.lane" "$home/state/lanes/archived/old-one.lane"
mv "$home/state/lanes/old-one.todo.md" "$home/state/lanes/archived/old-one.todo.md"
run_board "$home"
assert_status 0 "archived-only must not fail"
assert_has "(no active lanes)" "archived lanes are not active"
assert_lacks "old-one" "archived lane leaked onto the board"
end_case

# --- render -----------------------------------------------------------------

start_case "a registered lane renders the [model @ surface-pane] header"
home=$(new_home render)
write_lane "$home" "lane-alpha" \
  "pane=w1:p9Z" "artifact=data/lane-alpha-20261005/report.md" "note=demo lane" \
  "model=mcode" "surface=brandon"
write_todo "$home" "lane-alpha" \
  "- [x] preflight" "- [ ] scoped discovery" "- [ ] validation"
run_board "$home"
assert_status 0 "render must succeed"
assert_line "[mcode @ brandon·w1:p9Z] lane-alpha" "full header with model, surface, pane"
assert_line "- [x] preflight" "done item must keep its mark"
assert_line "- [ ] scoped discovery" "pending item must keep its mark"
end_case

start_case "a lane todo file is rendered verbatim, marks and nesting untouched"
home=$(new_home verbatim)
write_lane "$home" "lane-verbatim" "pane=w1:p1" "model=agy" "surface=controller"
# shellcheck disable=SC2016 # Backticks, asterisks and a bracketed token are literal
# test content that must reach the todo file unexpanded.
write_todo "$home" "lane-verbatim" \
  'START-SENTINEL' \
  '# todo: lane-verbatim' \
  '- [x] bounded work/evidence - wrote 12 tests | 27/27 pass' \
  '  - [ ] nested follow-up, indented' \
  '  *emphasis* and `code` and a [bracketed] token' \
  '- [ ] postflight/closeout' \
  'END-SENTINEL'
run_board "$home"
assert_verbatim "$home/state/lanes/lane-verbatim.todo.md" "START-SENTINEL" "END-SENTINEL" \
  "todo body must appear byte-identical between the sentinels"
end_case

start_case "a lane with no todo file says so instead of going blank"
home=$(new_home notodo)
write_lane "$home" "lane-bare" "pane=w1:p2"
run_board "$home"
assert_status 0 "a missing todo file must not fail the board"
assert_line "(no todo file)" "missing todo file must be explicit"
end_case

start_case "a lane with no status shows an explicit no-status footer"
home=$(new_home nostatus)
write_lane "$home" "lane-quiet" "pane=w1:p3"
write_todo "$home" "lane-quiet" "- [ ] preflight"
run_board "$home"
assert_status 0 "no status must not fail the board"
assert_line "  status: (none)" "absent status must be explicit"
end_case

start_case "the last status line is the lane status, and --tail widens it"
home=$(new_home statustail)
write_lane "$home" "lane-tail" "pane=w1:p4" "task=lane-tail-task"
write_status "$home" "lane-tail-task" \
  "working: first update" "working: middle update" "done: last update | 27/27 tests pass"
write_todo "$home" "lane-tail" "- [ ] validation"
run_board "$home"
assert_line "  status: done: last update | 27/27 tests pass" "default tail is the last line"
assert_lacks "first update" "default tail must stay single-screen"
run_board "$home" --tail 3
assert_line "  status: working: first update" "--tail 3 must include the first line"
assert_line "  status: working: middle update" "--tail 3 must include the middle line"
assert_line "  status: done: last update | 27/27 tests pass" "--tail 3 keeps the last line"
run_board "$home" --tail 2
assert_lacks "first update" "--tail 2 must drop the first line"
end_case

start_case "a lane without a task= key resolves its status from the artifact path"
home=$(new_home artifacttask)
write_lane "$home" "lane-art" "pane=w1:p5" "artifact=data/lane-art-20261005/report.md"
write_status "$home" "lane-art-20261005" "done: artifact task finished | report written"
write_todo "$home" "lane-art" "- [ ] preflight"
run_board "$home"
assert_has "status: done: artifact task finished" "artifact dirname selects the status record"
end_case

start_case "a decorated task id is found when no candidate record matches"
home=$(new_home prefixfallback)
write_lane "$home" "harness-autoupdate" "pane=w1:pE"
write_status "$home" "harness-autoupdate-20261005" "done: decorated task finished"
write_status "$home" "unrelated-task" "done: must not be shown"
write_todo "$home" "harness-autoupdate" "- [ ] preflight"
run_board "$home"
assert_has "status: done: decorated task finished" "prefix fallback must find the task"
assert_lacks "must not be shown" "an unrelated task must not leak onto a lane"
end_case

start_case "an explicit task= key wins over the artifact path"
home=$(new_home explicittask)
write_lane "$home" "lane-exp" "pane=w1:p6" "artifact=data/wrong-task/report.md" "task=right-task"
write_status "$home" "right-task" "done: explicit task finished"
write_status "$home" "wrong-task" "done: wrong task finished"
write_todo "$home" "lane-exp" "- [ ] preflight"
run_board "$home"
assert_has "status: done: explicit task finished" "task= must win"
assert_lacks "wrong task finished" "artifact must not override task="
end_case

start_case "model and surface fall back to the linked task meta"
home=$(new_home metafallback)
write_lane "$home" "lane-meta" "pane=w1:p7" "task=meta-task"
write_meta "$home" "meta-task" \
  "endpoint_task_id=meta-task" "harness=pi" "model=minimax-m2.7" \
  "herdr_session=default" "herdr_pane_id=w1:p8Y"
write_todo "$home" "lane-meta" "- [ ] preflight"
run_board "$home"
assert_line "[minimax-m2.7 @ default·w1:p7] lane-meta" "meta supplies model and surface"
run_board "$home" --no-meta
assert_line "[unknown @ unknown·w1:p7] lane-meta" "--no-meta disables the meta fallback"
end_case

start_case "a bare workspace:pane id does not invent a surface"
home=$(new_home baresession)
write_lane "$home" "lane-bare-pane" "pane=w1:p9" "task=bare-task"
write_todo "$home" "lane-bare-pane" "- [ ] preflight"
run_board "$home"
assert_line "[unknown @ unknown·w1:p9] lane-bare-pane" "two-component pane must not fake a surface"
end_case

start_case "a full session:workspace:pane id yields its session as the surface"
home=$(new_home fullsession)
write_lane "$home" "lane-full-pane" "pane=default:w1:p8Y"
write_todo "$home" "lane-full-pane" "- [ ] preflight"
run_board "$home"
assert_line "[unknown @ default·default:w1:p8Y] lane-full-pane" "full pane id yields the session"
end_case

start_case "a lane declared model/surface wins over the meta fallback"
home=$(new_home metameta)
write_lane "$home" "lane-both" "pane=w1:p8" "model=codex-luna6" "surface=hd2stack" "task=both-task"
write_meta "$home" "both-task" "model=should-not-win" "herdr_session=nowhere"
write_todo "$home" "lane-both" "- [ ] preflight"
run_board "$home"
assert_line "[codex-luna6 @ hd2stack·w1:p8] lane-both" "lane file beats meta"
end_case

start_case "a lane registered only by its todo file still appears"
home=$(new_home todoonly)
write_todo "$home" "lane-orphan" "- [ ] preflight" "- [ ] postflight/closeout"
run_board "$home"
assert_status 0 "a todo-only lane must not fail the board"
assert_line "[unknown @ unknown] lane-orphan" "todo-only lane needs a header"
assert_line "- [ ] preflight" "todo-only lane keeps its items"
end_case

start_case "every active lane appears once, in name order"
home=$(new_home multi)
write_lane "$home" "lane-zulu" "pane=w1:pA" "model=agy" "surface=controller"
write_todo "$home" "lane-zulu" "- [ ] preflight"
write_lane "$home" "lane-alpha" "pane=w1:pB" "model=mcode" "surface=brandon"
write_todo "$home" "lane-alpha" "- [ ] preflight"
write_lane "$home" "lane-mike" "pane=w1:pC" "model=hetz" "surface=brandon"
write_todo "$home" "lane-mike" "- [ ] preflight"
run_board "$home"
assert_status 0 "multi-lane render must succeed"
assert_has "lane-alpha" "lane-alpha missing"
assert_has "lane-mike" "lane-mike missing"
assert_has "lane-zulu" "lane-zulu missing"
order=$(printf '%s\n' "$OUT" | grep -oE '\] lane-(alpha|mike|zulu)$' | tr -d '] ' | tr '\n' ' ')
assert_eq "$order" "lane-alpha lane-mike lane-zulu " "lanes must render in name order"
end_case

start_case "a lane with no pane key still carries its model and surface"
home=$(new_home nopane)
write_lane "$home" "lane-nopane" "model=mcode" "surface=brandon"
write_todo "$home" "lane-nopane" "- [ ] preflight"
run_board "$home"
assert_line "[mcode @ brandon] lane-nopane" "missing pane must degrade to [model @ surface]"
end_case

start_case "comments and blank lines in a lane file are ignored"
home=$(new_home comments)
write_lane "$home" "lane-comments" "# a comment" "" "pane=w1:pD" "model=agy" "surface=controller"
write_todo "$home" "lane-comments" "- [ ] preflight"
run_board "$home"
assert_line "[agy @ controller·w1:pD] lane-comments" "comment lines must not corrupt parsing"
end_case

start_case "a real home renders without touching the fleet"
home=$(new_home realhome)
write_lane "$home" "always-four-scheduler" "pane=default:w1:p8Y" "task=always-four-scheduler" \
  "model=minimax-m2.7" "surface=default"
write_todo "$home" "always-four-scheduler" \
  '# todo: always-four-scheduler' '- [x] preflight' '- [x] scoped discovery' \
  '- [ ] bounded work/evidence' '- [ ] validation' '- [ ] postflight/closeout'
write_status "$home" "always-four-scheduler" \
  "done: G-3 fix applied (pane count not meta count) | 27/27 tests pass | 309-line report written"
run_board "$home"
assert_status 0 "a realistic home must render"
assert_line "[minimax-m2.7 @ default·default:w1:p8Y] always-four-scheduler" "realistic header"
assert_line "- [x] preflight" "completed item keeps its check"
assert_line "  status: done: G-3 fix applied (pane count not meta count) | 27/27 tests pass | 309-line report written" \
  "the real status line survives intact"
end_case

# --- --init-lane ------------------------------------------------------------

start_case "--init-lane scaffolds the five mandatory items, all pending"
home=$(new_home init)
run_board "$home" --init-lane fresh-lane
assert_status 0 "--init-lane should succeed"
scaffold="$home/state/lanes/fresh-lane.todo.md"
assert_file "$scaffold" "scaffold must exist"
if [ -f "$scaffold" ]; then
  boxes=$(grep -cE '^[[:space:]]*- \[[ xX]\] ' "$scaffold" 2>/dev/null || true)
  checked=$(grep -cE '^[[:space:]]*- \[[xX]\] ' "$scaffold" 2>/dev/null || true)
  assert_eq "${boxes:-0}" "5" "scaffold must hold exactly the five mandatory items"
  assert_eq "${checked:-0}" "0" "a fresh scaffold must have nothing pre-checked"
  body=$(cat "$scaffold")
  assert_has "$body" "preflight" "scaffold must carry the preflight item"
  assert_has "$body" "scoped discovery" "scaffold must carry the scoped discovery item"
  assert_has "$body" "bounded work" "scaffold must carry the bounded work item"
  assert_has "$body" "validation" "scaffold must carry the validation item"
  assert_has "$body" "postflight" "scaffold must carry the postflight item"
fi
end_case

start_case "a scaffolded lane is immediately visible on the board"
home=$(new_home initrender)
run_board "$home" --init-lane visible-lane
run_board "$home"
assert_status 0 "render after scaffold must succeed"
assert_line "[unknown @ unknown] visible-lane" "scaffolded lane needs a header"
assert_has "- [ ] preflight" "scaffolded items must render"
end_case

start_case "--init-lane creates a missing state/lanes directory"
home=$(new_home initnodir)
run_board "$home" --init-lane mkdir-lane
assert_status 0 "--init-lane should create its parent directory"
assert_file "$home/state/lanes/mkdir-lane.todo.md" "--init-lane did not create state/lanes"
end_case

start_case "--init-lane refuses to clobber an existing todo file"
home=$(new_home initclobber)
write_todo "$home" "keep-me" "- [x] captain-authored item"
before=$(cat "$home/state/lanes/keep-me.todo.md")
run_board "$home" --init-lane keep-me
assert_status 2 "clobbering must fail closed"
after=$(cat "$home/state/lanes/keep-me.todo.md")
assert_eq "$after" "$before" "existing todo file must be byte-identical"
assert_lacks "preflight" "a refused scaffold must not print a fresh checklist"
end_case

start_case "--init-lane rejects a path-traversal lane name"
home=$(new_home inittraversal)
run_board "$home" --init-lane ../escape
assert_status 1 "a traversal name must be rejected"
assert_no_file "$home/escape.todo.md" "traversal created a file outside state/lanes"
end_case

start_case "--init-lane rejects a lane name with a path separator"
home=$(new_home initseparator)
run_board "$home" --init-lane "nested/lane"
assert_status 1 "a path separator must be rejected"
assert_no_file "$home/state/lanes/nested/lane.todo.md" "nested lane name created a nested path"
end_case

start_case "--init-lane needs a lane name"
home=$(new_home initnoname)
run_board "$home" --init-lane
assert_status 1 "a missing lane name must be rejected"
end_case

start_case "--init-lane can scaffold and render in one invocation"
home=$(new_home initboth)
run_board "$home" --init-lane combo-lane
assert_has "combo-lane" "--init-lane should report the lane it scaffolded"
end_case

# --- summary ---------------------------------------------------------------

start_case "the offline HTML dashboard renders lanes, tickets, comms, capacity, and gates"
home=$(new_home dash)
mkdir -p "$home/state/lanes" "$home/data" "$home/config" "$home/BRANDON-COMPUTE-COMMS/Hetz/inbound" "$home/BRANDON-COMPUTE-COMMS/Hetz/outbound"
cat > "$home/state/lanes/lane-alpha.lane" <<'LANE'
task=task-alpha
model=glm-5.3-flash
surface=controller
compaction_headroom_pct=35
LANE
printf 'working: compiling\n' > "$home/state/task-alpha.status"
cat > "$home/data/backlog.md" <<'BACKLOG'
## P1
- [ ] T-100 Offline dashboard
  claim: lane-alpha
  blocker: waiting for fixture review
- [x] T-099 Completed ticket
BACKLOG
printf 'controller=4\n' > "$home/config/project-capacity"
printf 'w1:p9 working pane alpha\n' > "$home/herdr-panes.txt"
printf 'inbound receipt\n' > "$home/BRANDON-COMPUTE-COMMS/Hetz/inbound/20261013-hello.receipt"
printf 'outbound receipt\n' > "$home/BRANDON-COMPUTE-COMMS/Hetz/outbound/20261013-ack.receipt"
touch -d '2 minutes ago' "$home/BRANDON-COMPUTE-COMMS/Hetz/inbound/20261013-hello.receipt" "$home/BRANDON-COMPUTE-COMMS/Hetz/outbound/20261013-ack.receipt"
printf 'GATE G-7 PASS: local fixture\n' > "$home/state/task-gate.status"
run_dash "$home" "$home/index.html"
assert_status 0 "dashboard generation must succeed"
assert_file "$home/index.html" "dashboard output must exist"
OUT=$(cat "$home/index.html")
assert_has "glm-5.3-flash" "lane model row missing"
assert_has "lane-alpha" "lane row missing"
assert_has "task-alpha" "lane task field missing"
assert_has "working" "lane state missing"
assert_has "T-100 Offline dashboard" "ticket row missing"
assert_has "waiting for fixture review" "ticket blocker missing"
assert_has "2m ago" "comms age line missing"
assert_has "Declared 4" "capacity line missing"
assert_has "Running 1" "running pane count missing"
assert_has "G-7" "gate line missing"
assert_has "Generated <time datetime=" "generated-at timestamp missing"
assert_has "id=\"pill\"" "right-edge metric pill missing"
assert_has "#pill:hover{width:252px;padding:12px 14px}" "pill hover width should match the design spec"
assert_has "Tickets done</span><span class=\"dv\">1 / 2 · 50%" "ticket completion percentage missing"
assert_has "Capacity used</span><span class=\"dv ok\">25%" "capacity used percentage missing"
assert_has "Compaction headroom</span><span class=\"dv ok\">35%" "reported compaction headroom missing"
assert_has "Refresh snapshot" "dashboard refresh control missing"
assert_has "id=\"state-filter\"" "state filter missing"
assert_has "id=\"priority-filter\"" "priority filter missing"
assert_has "id=\"host-filter\"" "host filter missing"
assert_has "<details>" "lane and ticket details should expand without JavaScript"
assert_lacks "https://" "offline dashboard must contain no external URLs"
run_dash "$home" "$home/index.html"
OUT=$(cat "$home/index.html")
count=$(printf '%s\n' "$OUT" | grep -o '<main>' | wc -l | tr -d '[:space:]')
assert_eq "$count" "1" "regeneration must replace the snapshot without duplicating markup"
assert_lacks "http://" "offline dashboard must contain no external URLs"
end_case

start_case "serve returns the generated dashboard and accepts Markdown feedback"
home=$(new_home serve)
mkdir -p "$home/data" "$home/state" "$home/fakebin"
cat > "$home/data/backlog.md" <<'BACKLOG'
## P1
- [ ] T-100 Offline dashboard
  claim: lane-alpha
  blocker: waiting for review
BACKLOG
cat > "$home/fakebin/tailscale" <<'TAILSCALE'
#!/usr/bin/env bash
printf '127.0.0.1\n'
TAILSCALE
chmod +x "$home/fakebin/tailscale"
port=$(free_port)
FM_HOME="$home" LANE_TODO_DASH_PORT="$port" PATH="$home/fakebin:$PATH" \
  bash "$DASH" serve >"$home/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 40); do
  if python3 - "$port" <<'PY' >/dev/null 2>&1
import sys, urllib.request
try:
    urllib.request.urlopen(f"http://127.0.0.1:{sys.argv[1]}/", timeout=0.2).close()
except Exception:
    raise SystemExit(1)
PY
  then break; fi
  sleep 0.1
done
OUT=$(python3 - "$port" <<'PY'
import sys, urllib.request
with urllib.request.urlopen(f"http://127.0.0.1:{sys.argv[1]}/", timeout=2) as response:
    print(response.status)
    print(response.read().decode())
PY
)
assert_has "200" "serve should return HTTP 200"
assert_has "T-100 Offline dashboard" "served page should contain a ticket row"
feedback_status=$(python3 - "$port" <<'PY'
import sys, urllib.parse, urllib.request
data = urllib.parse.urlencode({"ticket": "T-100 Offline dashboard", "comment": "Please keep the blocker visible."}).encode()
request = urllib.request.Request(f"http://127.0.0.1:{sys.argv[1]}/feedback", data=data, method="POST")
request.add_header("Origin", f"http://127.0.0.1:{sys.argv[1]}")
with urllib.request.urlopen(request, timeout=2) as response:
    print(response.status)
PY
)
assert_eq "$feedback_status" "201" "POST should create one feedback file"
feedback_files=("$home/state/dash-feedback/"*.md)
assert_file "${feedback_files[0]}" "POST should write into the feedback inbox"
assert_grep_file "${feedback_files[0]}" '^# Dashboard feedback$' "feedback should be a Markdown document"
assert_grep_file "${feedback_files[0]}" '^- Timestamp: [0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z$' "feedback should contain a UTC timestamp"
assert_grep_file "${feedback_files[0]}" '^- Ticket: T-100 Offline dashboard$' "feedback should retain the ticket reference"
assert_grep_file "$home/server.log" "^Serving dashboard at http://127.0.0.1:$port/$" "serve should print its bound URL"
printf '%s\n' '- [ ] T-101 Added after first request' >> "$home/data/backlog.md"
OUT=$(python3 - "$port" <<'PY'
import sys, urllib.request
with urllib.request.urlopen(f"http://127.0.0.1:{sys.argv[1]}/", timeout=2) as response:
    print(response.read().decode())
PY
)
assert_has "T-101 Added after first request" "a fresh GET should rerun the generator"
kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""
end_case

start_case "review opens the artifact as a Lavish session and arms the registered chat-back source"
home=$(new_home review)
write_lavish_stub "$home"
mkdir -p "$home/data"
cat > "$home/data/backlog.md" <<'BACKLOG'
## P1
- [ ] T-100 Offline dashboard
BACKLOG
run_dash_cmd "$home" review
assert_status 0 "review must succeed"
review_out="$OUT"
artifact="$home/.lavish/LANE-TODO-DASH.html"
artifact_real="$(cd "$(dirname "$artifact")" && pwd)/$(basename "$artifact")"
assert_file "$artifact" "review must regenerate the artifact at its stable path"
assert_no_file "$home/index.html" "review must not fall through and regenerate the default artifact"
OUT=$(cat "$artifact")
assert_has "T-100 Offline dashboard" "the artifact must still carry this script's own ticket data"
OUT="$review_out"
source_id=$(bash "$SELF_DIR/fm-procevent-lavish.sh" source-id "$artifact" 2>&1)
assert_has "lavish-" "source identity must come from the sanctioned adapter"
assert_file "$home/state/procevent/$source_id.source" "review must register the source with the runner"
assert_grep_file "$home/state/procevent/$source_id.source" '^adapter=lavish$' "the registered adapter must be lavish"
assert_grep_file "$home/state/procevent/$source_id.source" '^argv:$' "the registration must store a poll argv"
assert_file_has "$home/state/procevent/$source_id.source" "poll" "the registered argv must poll"
assert_file_has "$home/state/procevent/$source_id.source" "$artifact_real" "the poll argv must name the artifact realpath"
assert_has "armed: $source_id" "review must report the armed source id"
OUT=$(cat "$home/lavish-calls.log")
assert_has "CALL"$'\t'"$artifact" "review must open the artifact as a Lavish session"
assert_lacks $'\t'"share" "review must never publish to a third-party host"
end_case

start_case "reply and end drive the agent-to-human half and retire the source"
home=$(new_home reply)
write_lavish_stub "$home"
mkdir -p "$home/data"
cat > "$home/data/backlog.md" <<'BACKLOG'
## P1
- [ ] T-100 Offline dashboard
BACKLOG
run_dash_cmd "$home" review
assert_status 0 "review must succeed"
artifact="$home/.lavish/LANE-TODO-DASH.html"
source_id=$(bash "$SELF_DIR/fm-procevent-lavish.sh" source-id "$artifact" 2>&1)
assert_file "$home/state/procevent/$source_id.source" "review must register the source before it can be retired"
: > "$home/lavish-calls.log"
run_dash_cmd "$home" reply "Applied: the blocker stays visible"
assert_status 0 "reply must succeed"
OUT=$(cat "$home/lavish-calls.log")
assert_has "CALL"$'\t'"reply"$'\t'"$artifact"$'\t'"--agent-reply"$'\t'"Applied: the blocker stays visible" "reply must send the agent message into the board"
run_dash_cmd "$home" end
assert_status 0 "end must succeed"
OUT=$(cat "$home/lavish-calls.log")
assert_has "CALL"$'\t'"end"$'\t'"$artifact" "end must end the Lavish session"
assert_no_file "$home/state/procevent/$source_id.source" "end must retire the registered source"
end_case

start_case "reply and end refuse before a dashboard artifact exists"
home=$(new_home bare)
write_lavish_stub "$home"
run_dash_cmd "$home" reply "too early"
assert_status 1 "reply must refuse without an artifact"
assert_has "run review first" "reply must say which command to run"
run_dash_cmd "$home" end
assert_status 1 "end must refuse without an artifact"
assert_has "run review first" "end must say which command to run"
run_dash_cmd "$home" reply
assert_status 1 "reply must refuse an empty message"
end_case

printf '1..%d\n' "$CASES_RUN"
printf '# lane-todo-board: %d cases, %d assertions, %d failed\n' \
  "$CASES_RUN" "$CASE_ASSERTIONS" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
