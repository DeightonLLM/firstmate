#!/usr/bin/env bash
# tests/fm-watch-supervise.test.sh - behaviour tests for bin/fm-watch-supervise.sh,
# the arm owner that gives the minimax-code primary a continuous, self-owned
# supervision cycle.
#
# HERMETIC BY CONSTRUCTION:
#   - Every run gets its own FM_HOME and FM_STATE_OVERRIDE under a temp root.
#   - The real bin/fm-watch-arm.sh is NEVER executed: FM_WATCH_SUPERVISE_ARM
#     points at a stub arm that prints a scripted wake reason. The live
#     watcher, the live watch lock, the live board and every real pane are
#     therefore untouched by this suite.
#   - The crew-state reader is stubbed too (FM_CREW_STATE_BIN), so the shared
#     classifier's absorb decision is deterministic and no no-mistakes call is
#     ever made.
#
# The six behaviours under test are the ones the lane was opened for:
#   1. a routine wake does not stop the loop and produces no escalation
#   2. a captain-relevant wake does stop the loop and the escalation names it
#   3. the bounded park interval exits with a summary
#   4. a watcher that cannot be kept alive exits non-zero with a loud line
#   5. the script never uses a shell `&` for the watcher
#   6. the loop survives at least three consecutive routine wakes with no
#      operator re-run in between
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPERVISE="$ROOT/bin/fm-watch-supervise.sh"
fail=0
checks=0

say() { printf '%s\n' "$*"; }
ok()  { checks=$((checks + 1)); printf 'ok   %s\n' "$*"; }
bad() { checks=$((checks + 1)); fail=$((fail + 1)); printf 'FAIL %s\n' "$*"; }
fatal() { printf 'FAIL %s\n' "$*"; exit 1; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/fm-watch-supervise.XXXXXX") || fatal "could not create a temp root"
cleanup() { rm -rf "$TMP" 2>/dev/null || true; }
trap cleanup EXIT

# --- the home-isolation snapshot ---------------------------------------------
#
# The suite must not pollute the home it runs in. The check at the end of this
# file compares the set of supervisor artefact NAMES in that home's state
# directory before the suite's work with the set after it.
#
# Comparing NAMES, not contents, is what makes the check meaningful on a live
# host. A standing supervisor legitimately lives in the production home and
# legitimately writes .watch-supervise.log, .watch-supervise.lock and
# .watch-supervise-output.* into that home's state directory, and it APPENDS
# to its log while the suite runs. So that file's contents, size and mtime all
# change for reasons that are not pollution, and a checksum comparison would
# fail on a busy host for no reason at all. A pre-existing artefact is
# legitimate; only a NEW name is pollution.
#
# ATTRIBUTION: on a production host a live supervisor is writing into this very
# directory WHILE the suite runs, so a new name is not automatically the
# suite's doing. The lock the supervisor holds says who owns the home: the lock
# is a directory carrying the holder's pid, and a live pid means a supervisor is
# running. Artefacts a live supervisor owns are attributed to it and are not
# pollution; anything else that appears IS. With no supervisor live - a CI box, a
# dev box - nothing is attributed and the check keeps its full teeth.
#
# The owned names are the supervisor's own, and they are asserted against the
# supervisor's source below so the two cannot drift apart silently.
#
# The "before" snapshot is taken HERE, before any case runs, so the comparison
# measures the whole suite and is not vacuous. The snapshot lives under the
# suite's own temp root, never in the home it is measuring.
HOME_ARTEFACTS_BEFORE="$TMP/home-artefacts.before"
HOME_ARTEFACTS_AFTER="$TMP/home-artefacts.after"

snapshot_home_artefacts() {  # <out-file>
  local out=$1 f
  : > "$out" || return 1
  [ -d "$ROOT/state" ] || return 0
  (
    cd "$ROOT/state" 2>/dev/null || exit 0
    for f in .watch-supervise*; do
      [ -e "$f" ] || continue
      printf '%s\n' "$f"
    done
  ) | LC_ALL=C sort > "$out"
  return 0
}

# supervisor_owns_artefact <name> - true for a name a running supervisor owns.
# The lock and its owner sidecar belong to the shared lock library, so the
# whole .watch-supervise.lock* family is the lock's.
supervisor_owns_artefact() {
  case "$1" in
    .watch-supervise.log) return 0 ;;
    .watch-supervise.lock|.watch-supervise.lock.*) return 0 ;;
    .watch-supervise-output.*) return 0 ;;
  esac
  return 1
}

# live_supervisor_pid - the pid of a supervisor holding this home's lock, or
# empty when no supervisor is running.
live_supervisor_pid() {
  local lockdir="$ROOT/state/.watch-supervise.lock" pid=''
  [ -d "$lockdir" ] || return 0
  IFS= read -r pid 2>/dev/null <"$lockdir/pid" || true
  case "$pid" in ''|*[!0-9]*) return 0 ;; esac
  [ -d "/proc/$pid" ] || return 0
  printf '%s\n' "$pid"
}

# supervisor_log_size - the byte size of this home's supervisor log, or 0 when
# there is no log. The log grows on every supervisor exit path, so a size that
# moved during the run is proof that a supervisor was active during it.
supervisor_log_size() {
  local f="$ROOT/state/.watch-supervise.log" size=0
  [ -f "$f" ] || { printf '0\n'; return 0; }
  size=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
  printf '%s\n' "${size:-0}"
}

# The owned-artefact list above must not drift from the supervisor's own source.
for lit in '.watch-supervise.log' '.watch-supervise.lock' '.watch-supervise-output.'; do
  grep -qF -- "$lit" "$SUPERVISE" \
    || fatal "the supervisor's source no longer contains '$lit' - update supervisor_owns_artefact() in this suite"
done

snapshot_home_artefacts "$HOME_ARTEFACTS_BEFORE" \
  || fatal "could not snapshot the home's supervisor artefacts"
SUPERVISOR_PID_BEFORE=$(live_supervisor_pid)
SUPERVISOR_LOG_BEFORE=$(supervisor_log_size)

# A portable bounded runner: timeout, gtimeout, or perl's alarm.
run_bounded() {  # <seconds> <cmd...>
  local secs=$1; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
  fi
}

[ -x "$SUPERVISE" ] || fatal "missing or non-executable $SUPERVISE"

# --- the stub arm ------------------------------------------------------------
# It prints the arm's readiness line, then the next scripted wake reason, then
# exits 0. When the fixture runs out it repeats its last line, so a bounded
# park test can keep producing routine wakes.
STUB_ARM="$TMP/stub-arm.sh"
cat > "$STUB_ARM" <<'STUB'
#!/usr/bin/env bash
set -u
fixture=${FM_STUB_ARM_FIXTURE:?}
counter=${FM_STUB_ARM_COUNTER:?}
n=$(cat "$counter" 2>/dev/null || printf '0')
n=$((n + 1))
printf '%s\n' "$n" > "$counter"
printf 'watcher: started pid=%s (beacon fresh)\n' "$$"
last=$(sed -n "${n}p" "$fixture")
if [ -z "$last" ]; then
  last=$(sed -n '$p' "$fixture")
fi
[ -n "$last" ] || exit 0
printf '%s\n' "$last"
sleep "${FM_STUB_ARM_DELAY:-0}"
exit 0
STUB
chmod +x "$STUB_ARM"

# A stub arm that fails the way a real arm fails when no watcher is alive.
STUB_ARM_FAIL="$TMP/stub-arm-fail.sh"
cat > "$STUB_ARM_FAIL" <<'STUB'
#!/usr/bin/env bash
set -u
counter=${FM_STUB_ARM_COUNTER:?}
n=$(cat "$counter" 2>/dev/null || printf '0')
n=$((n + 1))
printf '%s\n' "$n" > "$counter"
printf 'watcher: FAILED - no live watcher with a fresh beacon\n'
exit 1
STUB
chmod +x "$STUB_ARM_FAIL"

# A stub arm that prints the readiness line and then HOLDS the cycle open, the
# way a real watcher holds a cycle open while it waits for a wake. It exists to
# prove that the readiness line reaches the caller while the cycle is still
# running, instead of sitting in a stdio buffer until the cycle closes.
STUB_ARM_HOLD="$TMP/stub-arm-hold.sh"
cat > "$STUB_ARM_HOLD" <<'STUB'
#!/usr/bin/env bash
set -u
counter=${FM_STUB_ARM_COUNTER:?}
n=$(cat "$counter" 2>/dev/null || printf '0')
n=$((n + 1))
printf '%s\n' "$n" > "$counter"
printf 'watcher: started pid=%s (beacon fresh)\n' "$$"
sleep "${FM_STUB_ARM_HOLD_SECS:-30}"
printf 'signal: %s\n' "${FM_STUB_ARM_HOLD_REASON:-signal: held}"
exit 0
STUB
chmod +x "$STUB_ARM_HOLD"

# --- the stub crew-state reader ----------------------------------------------
# The shared classifier reads one "state: <s> source: <src> ..." line per crew.
STUB_CREW="$TMP/stub-crew-state.sh"
cat > "$STUB_CREW" <<'STUB'
#!/usr/bin/env bash
set -u
verdict=${FM_STUB_CREW_VERDICT:?}
printf '%s\n' "$verdict"
exit 0
STUB
chmod +x "$STUB_CREW"

# --- one isolated home per case ----------------------------------------------
CASE=0
new_home() {  # <name> -> exports HOME_DIR, STATE_DIR, FIXTURE, COUNTER, OUT
  CASE=$((CASE + 1))
  HOME_DIR="$TMP/case-$CASE"
  STATE_DIR="$HOME_DIR/state"
  mkdir -p "$STATE_DIR" "$HOME_DIR/config"
  FIXTURE="$TMP/case-$CASE.fixture"
  COUNTER="$TMP/case-$CASE.counter"
  OUT="$TMP/case-$CASE.out"
  : > "$FIXTURE"
  : > "$COUNTER"
  export FM_HOME="$HOME_DIR"
  export FM_STATE_OVERRIDE="$STATE_DIR"
  export FM_CONFIG_OVERRIDE="$HOME_DIR/config"
  export FM_STUB_ARM_FIXTURE="$FIXTURE"
  export FM_STUB_ARM_COUNTER="$COUNTER"
  export FM_CREW_STATE_BIN="$STUB_CREW"
  export FM_WATCH_SUPERVISE_CYCLE_GAP_SECS=0
  export FM_WATCH_SUPERVISE_PARK_SECS=60
  export FM_WATCH_SUPERVISE_ARM_ATTEMPTS=1
}

# A routine wake: a no-verb status on a crew the classifier proves is working.
routine_status() {  # <task>
  printf 'working: lane %s is still running\n' "$1" > "$STATE_DIR/$1.status"
}

# A captain-relevant wake: a terminal verb on the crew's status.
terminal_status() {  # <task>
  printf 'done: lane %s shipped the fix\n' "$1" > "$STATE_DIR/$1.status"
}

# The script's CODE, with comments removed: the textual proofs below are about
# what the script DOES, not about what its header says about itself.
code_lines() {  # <file>
  sed -e 's/[[:space:]]*#.*$//' "$1" | grep -v '^[[:space:]]*$'
}

# ============================================================================
# 1 + 6. A routine wake does not stop the loop, produces no escalation, and the
#         loop survives at least three consecutive routine wakes with no
#         operator re-run in between.
# ============================================================================
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
export FM_STUB_CREW_VERDICT='state: working · source: run-step · stub'
export FM_STUB_ARM_DELAY=0.2
# The park bound is a test PARAMETER, not an assertion: it only decides how
# many cycles the loop gets. It is set generously so the "at least three
# consecutive routine wakes" assertion has headroom on a busy host, because a
# suite that passes only when the machine is idle is a suite nobody trusts.
export FM_WATCH_SUPERVISE_PARK_SECS=5
routine_status lane1
{
  printf 'signal: %s\n' "$STATE_DIR/lane1.status"
  printf 'signal: %s\n' "$STATE_DIR/lane1.status"
  printf 'signal: %s\n' "$STATE_DIR/lane1.status"
} > "$FIXTURE"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
runs=$(cat "$COUNTER" 2>/dev/null || printf '0')
absorbed=$(grep -c 'routine wake absorbed' "$OUT" 2>/dev/null || printf '0')

if [ "$rc" -eq 0 ]; then
  ok "routine wakes: the supervisor ends on its own park bound with exit 0"
else
  bad "routine wakes: expected exit 0, got $rc"
  sed 's/^/       /' "$OUT"
fi

if [ "$absorbed" -ge 3 ]; then
  ok "routine wakes: at least three consecutive routine wakes were absorbed ($absorbed)"
else
  bad "routine wakes: expected at least 3 absorbed routine wakes, got $absorbed"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'ESCALATION' "$OUT" 2>/dev/null; then
  bad "routine wakes: a routine wake must not produce an escalation"
  sed 's/^/       /' "$OUT"
else
  ok "routine wakes: no escalation was produced"
fi

if [ "$runs" -ge 4 ]; then
  ok "the loop re-armed itself: the arm ran $runs times inside ONE supervisor run"
else
  bad "the loop did not survive three consecutive routine wakes: arm ran $runs time(s)"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'watcher: started pid=' "$OUT" 2>/dev/null; then
  ok "the arm's readiness line is relayed as soon as the watcher is verified"
else
  bad "the arm's readiness line was never relayed"
  sed 's/^/       /' "$OUT"
fi

# The supervisor must have kept its own state inside the temporary home. The
# supervisor lock is released on exit, so the log is the durable witness.
if [ -f "$STATE_DIR/.watch-supervise.log" ]; then
  ok "the supervisor kept its state inside the temporary home (the live home was untouched)"
else
  bad "the supervisor did not keep its state inside the temporary home"
  ls -la "$STATE_DIR" | sed 's/^/       /'
fi

# The suite's own isolation from the home it runs in is checked at the END of
# this file, against the before/after artefact-name snapshot taken before any
# case ran. Asserting here would have measured only this one case.

# ============================================================================
# 2. A captain-relevant wake stops the loop and the escalation names it.
# ============================================================================
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
export FM_STUB_CREW_VERDICT='state: working · source: run-step · stub'
routine_status lane1
terminal_status lane2
{
  printf 'signal: %s\n' "$STATE_DIR/lane1.status"
  printf 'signal: %s\n' "$STATE_DIR/lane2.status"
  printf 'signal: %s\n' "$STATE_DIR/lane2.status"
} > "$FIXTURE"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
runs=$(cat "$COUNTER" 2>/dev/null || printf '0')

if [ "$rc" -eq 0 ]; then
  ok "captain-relevant wake: the supervisor exits 0 after handing the wake back"
else
  bad "captain-relevant wake: expected exit 0, got $rc"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'ESCALATION' "$OUT" 2>/dev/null; then
  ok "captain-relevant wake: an escalation was printed"
else
  bad "captain-relevant wake: no escalation was printed"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'done: lane lane2 shipped the fix' "$OUT" 2>/dev/null; then
  ok "captain-relevant wake: the escalation names the wake"
else
  bad "captain-relevant wake: the escalation does not name the wake"
  sed 's/^/       /' "$OUT"
fi

if [ "$runs" -eq 2 ]; then
  ok "captain-relevant wake: the loop stopped on the escalation (arm ran $runs times)"
else
  bad "captain-relevant wake: the loop did not stop on the escalation (arm ran $runs times)"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'routine wake absorbed (signal: '"$STATE_DIR"'/lane1.status)' "$OUT" 2>/dev/null; then
  ok "captain-relevant wake: the routine wake before it was absorbed, not escalated"
else
  bad "captain-relevant wake: the preceding routine wake was not absorbed"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# 3. The bounded park interval exits with a compact summary.
# ============================================================================
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
export FM_STUB_CREW_VERDICT='state: working · source: run-step · stub'
# A test PARAMETER, not an assertion: it only sets how long the loop runs
# before the park exit. Generous, so the "kept the cycle alive" assertion does
# not depend on host speed.
export FM_WATCH_SUPERVISE_PARK_SECS=3
export FM_STUB_ARM_DELAY=0.2
routine_status lane1
printf 'signal: %s\n' "$STATE_DIR/lane1.status" > "$FIXTURE"

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
runs=$(cat "$COUNTER" 2>/dev/null || printf '0')

if [ "$rc" -eq 0 ]; then
  ok "park interval: the supervisor exits 0 when the park bound is reached"
else
  bad "park interval: expected exit 0, got $rc"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'PARKED after' "$OUT" 2>/dev/null; then
  ok "park interval: the park exit is announced"
else
  bad "park interval: no park exit was announced"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'summary cycles=' "$OUT" 2>/dev/null; then
  ok "park interval: the park exit carries a compact summary"
else
  bad "park interval: the park exit carries no summary"
  sed 's/^/       /' "$OUT"
fi

if [ "$runs" -ge 2 ]; then
  ok "park interval: the supervisor kept the cycle alive across the park window (arm ran $runs times)"
else
  bad "park interval: the supervisor did not keep the cycle alive (arm ran $runs time(s))"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# 4. A watcher that cannot be kept alive produces a non-zero exit and a loud
#    line.
# ============================================================================
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM_FAIL"
export FM_WATCH_SUPERVISE_ARM_ATTEMPTS=2
export FM_STUB_ARM_DELAY=0
export FM_STUB_CREW_VERDICT='state: stopped · source: none · stub'

run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
runs=$(cat "$COUNTER" 2>/dev/null || printf '0')

if [ "$rc" -ne 0 ]; then
  ok "failed watcher: the supervisor exits non-zero ($rc)"
else
  bad "failed watcher: expected a non-zero exit, got 0"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'supervise: FAILED' "$OUT" 2>/dev/null; then
  ok "failed watcher: the failure is loud"
else
  bad "failed watcher: no loud failure line was printed"
  sed 's/^/       /' "$OUT"
fi

if grep -q 'supervision is DOWN' "$OUT" 2>/dev/null; then
  ok "failed watcher: the failure says supervision is down"
else
  bad "failed watcher: the failure does not say supervision is down"
  sed 's/^/       /' "$OUT"
fi

if [ "$runs" -eq 2 ]; then
  ok "failed watcher: the arm was retried within the attempt budget (arm ran $runs times)"
else
  bad "failed watcher: expected 2 attempts, the arm ran $runs time(s)"
  sed 's/^/       /' "$OUT"
fi

# ============================================================================
# 5. The script never uses a shell `&` for the watcher.
#    The proof is textual and mechanical: after every file-descriptor
#    duplication (2>&1 and friends) is removed, no `&` remains anywhere in the
#    script, and the script never names the watcher itself - the watcher is
#    launched only by bin/fm-watch-arm.sh, as that arm's own tracked child.
# ============================================================================
stripped=$(code_lines "$SUPERVISE" | sed -E 's/&>>/>/g; s/[0-9]*>&[0-9-]//g; s/&&//g; s/&>//g')
if printf '%s\n' "$stripped" | grep -q '&'; then
  bad "the script uses a shell '&' somewhere"
  printf '%s\n' "$stripped" | grep -n '&' | sed 's/^/       /'
else
  ok "the script contains no shell '&' at all (no backgrounded child, least of all the watcher)"
fi

if code_lines "$SUPERVISE" | grep -q 'fm-watch\.sh'; then
  bad "the script references the watcher directly"
  code_lines "$SUPERVISE" | grep -n 'fm-watch\.sh' | sed 's/^/       /'
else
  ok "the script never launches the watcher: only bin/fm-watch-arm.sh does"
fi

if code_lines "$SUPERVISE" | grep -q 'fm-watch-arm\.sh'; then
  ok "the script owns the cycle through bin/fm-watch-arm.sh"
else
  bad "the script does not run bin/fm-watch-arm.sh"
fi

if code_lines "$SUPERVISE" | grep -Eq '(^|[^0-9&])&[[:space:]]*$'; then
  bad "the script backgrounds a command with a trailing '&'"
  code_lines "$SUPERVISE" | grep -En '(^|[^0-9&])&[[:space:]]*$' | sed 's/^/       /'
else
  ok "the script backgrounds no command"
fi

# ============================================================================
# 7. The readiness line is delivered WHILE the cycle is still running.
#    The arm's "watcher: started ..." line must reach the caller the moment it
#    is printed, so a caller waiting for readiness sees it immediately. A
#    block-buffered pipe would hold the line until the cycle closed, which is
#    exactly the failure this check exists to catch: the supervisor is killed
#    mid-cycle here, so anything still buffered is lost.
# ============================================================================
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM_HOLD"
export FM_STUB_ARM_HOLD_SECS=30
export FM_STUB_CREW_VERDICT='state: working · source: run-step · stub'
routine_status lane1
printf 'signal: %s\n' "$STATE_DIR/lane1.status" > "$FIXTURE"

# The bounded runner stops the supervisor mid-cycle. The wait is generous so
# a busy host still gets the supervisor started and the arm's readiness line
# relayed; the stub arm holds the cycle open for 30s, so the cycle is still
# OPEN when the runner stops it and the assertion is unchanged.
run_bounded 10 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
if grep -q 'watcher: started pid=' "$OUT" 2>/dev/null; then
  ok "readiness: the arm's readiness line reached the caller while the cycle was still open"
else
  bad "readiness: the readiness line never reached the caller (it was buffered until the cycle closed)"
  sed 's/^/       /' "$OUT"
fi
if [ "$rc" -ne 0 ]; then
  ok "readiness: the supervisor was still inside the cycle when the bounded runner stopped it"
else
  bad "readiness: expected the bounded runner to stop the supervisor, got exit $rc"
fi

# ============================================================================
# 8. PEER RECEIPT COALESCING - one model turn per meaningful peer update,
#    not one per republication.
#
#    A peer that drops files into this home's comms inbox produces one comms
#    receipt per file, and every receipt enqueues its own signal wake. The
#    fixture writes exactly what a peer drop produces:
#
#      - a receipt ledger line (the receipt's own metadata, with the full
#        sha256) under state/comms-receipts/<id>/receipts.tsv;
#      - a comms-received status line on state/<id>.status;
#      - one PENDING wake record in the durable wake queue.
#
#    The stub arm surfaces the peer status file as a signal, the way the
#    watcher surfaces it. The stub crew verdict is deliberately NOT provably
#    working, so an escalation here can only come from the supervisor's own
#    peer decision: if the peer path did not handle the wake, the ordinary
#    classifier would escalate it and the "absorbed" checks below would fail.
# ============================================================================

PEER_ID=
PEER_LEDGER=
PEER_STATUS=
PEER_QUEUE=
PEER_SEQ=0

# peer_reset <id>
# Prepare a peer source with an empty receipt ledger, an empty status file and
# an empty wake queue.
peer_reset() {  # <id>
  PEER_ID=$1
  PEER_SEQ=0
  PEER_LEDGER="$STATE_DIR/comms-receipts/$PEER_ID/receipts.tsv"
  PEER_STATUS="$STATE_DIR/$PEER_ID.status"
  PEER_QUEUE="$STATE_DIR/.wake-queue"
  mkdir -p "$STATE_DIR/comms-receipts/$PEER_ID"
  : > "$PEER_LEDGER"
  : > "$PEER_STATUS"
  : > "$PEER_QUEUE"
  # The coalescing window used by the peer cases. It has to be long enough
  # that the supervisor's next run reliably lands INSIDE it (the window is
  # anchored at the last escalation), and the expiry sleeps below are longer
  # than the window so the expiry itself is real rather than assumed.
  export FM_WATCH_SUPERVISE_COALESCE_SECS=20
  export FM_STUB_CREW_VERDICT='state: stopped · source: none · stub'
  export FM_WATCH_SUPERVISE_PARK_SECS=2
  export FM_STUB_ARM_DELAY=0.05
  printf 'signal: %s\n' "$PEER_STATUS" > "$FIXTURE"
}

# peer_drop <name> [content]
# One received file: its receipt, its status line, and its pending wake.
# Prints the file's sha256.
peer_drop() {  # <name> [content]
  local name=$1 content="${2:-content of $1}" sha
  sha=$(printf '%s' "$content" | sha256sum | awk '{print $1}')
  PEER_SEQ=$((PEER_SEQ + 1))
  printf '%s\t%s\n' "$sha" "$name" >> "$PEER_LEDGER"
  printf 'comms-received: %s %s sha=%s bytes=%s | untrusted-reply-text: %s\n' \
    "$PEER_ID" "$name" "$(printf '%s' "$sha" | cut -c1-12)" "${#content}" "$content" \
    >> "$PEER_STATUS"
  printf '%s\t%s\tsignal\t%s.status\tcomms received from %s: %s\n' \
    "$(date +%s)" "$PEER_SEQ" "$PEER_ID" "$PEER_ID" "$name" >> "$PEER_QUEUE"
  printf '%s' "$sha"
}

# --- 8a. A republished machine artefact escalates the FIRST time ------------
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
peer_reset peer-a
sha_board=$(peer_drop CAPTAIN-BOARD.html)
run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?

if [ "$rc" -eq 0 ] && grep -q 'ESCALATION' "$OUT" 2>/dev/null; then
  ok "peer republication: the first republished machine artefact escalates"
else
  bad "peer republication: the first republished machine artefact did not escalate (rc=$rc)"
  sed 's/^/       /' "$OUT"
fi

if grep -q "source=peer-a" "$OUT" 2>/dev/null \
   && grep -q "latest=CAPTAIN-BOARD.html" "$OUT" 2>/dev/null \
   && grep -q "sha=$sha_board" "$OUT" 2>/dev/null; then
  ok "peer republication: the escalation names the source, the artefact and its sha256"
else
  bad "peer republication: the escalation does not name the source, the artefact and its sha256"
  sed 's/^/       /' "$OUT"
fi

# --- 8b. Republishing inside the window is absorbed, and the escalation
#        states the absorbed count, the source, the latest artefact and sha --
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
peer_reset peer-a
sha_board=$(peer_drop CAPTAIN-BOARD.html)
run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?
if [ "$rc" -eq 0 ] && grep -q 'ESCALATION' "$OUT" 2>/dev/null; then
  ok "peer coalescing: the first republication establishes the window and escalates"
else
  bad "peer coalescing: the first republication did not escalate (rc=$rc)"
  sed 's/^/       /' "$OUT"
fi

# Two more republications of the same artefact from the same source, inside
# the window.
peer_drop CAPTAIN-BOARD.html 'second republication' >/dev/null
peer_drop CAPTAIN-BOARD.html 'third republication' >/dev/null
run_bounded 30 "$SUPERVISE" > "$OUT.2" 2>&1
rc=$?

if grep -q 'republication absorbed' "$OUT.2" 2>/dev/null; then
  ok "peer coalescing: republications inside the window are absorbed, not escalated"
else
  bad "peer coalescing: the republications inside the window were not absorbed"
  sed 's/^/       /' "$OUT.2"
fi

if grep -q 'ESCALATION' "$OUT.2" 2>/dev/null; then
  bad "peer coalescing: an absorbed republication produced an escalation"
  sed 's/^/       /' "$OUT.2"
else
  ok "peer coalescing: an absorbed republication produced no escalation"
fi

if grep -q 'absorbed=2' "$OUT.2" 2>/dev/null; then
  ok "peer coalescing: the absorbed count states how many republications were folded in"
else
  bad "peer coalescing: the absorbed count is missing or wrong"
  sed 's/^/       /' "$OUT.2"
fi

# The window closes, and the next republication escalates. That escalation is
# where the absorbed republications are reported.
# Longer than the coalescing window, so the window really has closed.
sleep 25
sha_board4=$(peer_drop CAPTAIN-BOARD.html 'fourth republication')
run_bounded 30 "$SUPERVISE" > "$OUT.3" 2>&1
rc=$?

if grep -q 'ESCALATION' "$OUT.3" 2>/dev/null; then
  ok "peer coalescing: the republication after the window escalates again"
else
  bad "peer coalescing: the republication after the window did not escalate"
  sed 's/^/       /' "$OUT.3"
fi

if grep -q "source=peer-a" "$OUT.3" 2>/dev/null \
   && grep -q 'absorbed=2' "$OUT.3" 2>/dev/null \
   && grep -q "latest=CAPTAIN-BOARD.html" "$OUT.3" 2>/dev/null \
   && grep -q "sha=$sha_board4" "$OUT.3" 2>/dev/null; then
  ok "peer coalescing: the escalation states the absorbed count, the source, the latest artefact and its sha256"
else
  bad "peer coalescing: the escalation does not state the absorbed count, the source, the latest artefact and its sha256"
  sed 's/^/       /' "$OUT.3"
fi

# --- 8c. The absorbed count resets after the window ------------------------
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
peer_reset peer-a
peer_drop CAPTAIN-BOARD.html 'first republication' >/dev/null
run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
peer_drop CAPTAIN-BOARD.html 'second republication' >/dev/null
run_bounded 30 "$SUPERVISE" > "$OUT.2" 2>&1
if grep -q 'absorbed=1' "$OUT.2" 2>/dev/null; then
  ok "peer coalescing: one republication inside the window is counted as absorbed"
else
  bad "peer coalescing: the first absorbed republication was not counted"
  sed 's/^/       /' "$OUT.2"
fi

# Longer than the coalescing window, so the window really has closed.
sleep 25
peer_drop CAPTAIN-BOARD.html 'third republication' >/dev/null
run_bounded 30 "$SUPERVISE" > "$OUT.3" 2>&1
if grep -q 'ESCALATION' "$OUT.3" 2>/dev/null && grep -q 'absorbed=1' "$OUT.3" 2>/dev/null; then
  ok "peer coalescing: the escalation after the window reports the count that was folded in"
else
  bad "peer coalescing: the escalation after the window does not report the folded-in count"
  sed 's/^/       /' "$OUT.3"
fi

# The count must start again from zero in the new window.
peer_drop CAPTAIN-BOARD.html 'fourth republication' >/dev/null
run_bounded 30 "$SUPERVISE" > "$OUT.4" 2>&1
if grep -q 'republication absorbed' "$OUT.4" 2>/dev/null && grep -q 'absorbed=1' "$OUT.4" 2>/dev/null; then
  ok "peer coalescing: the absorbed count resets after the window"
else
  bad "peer coalescing: the absorbed count did not reset after the window"
  sed 's/^/       /' "$OUT.4"
fi

# --- 8d. A message to the Controller escalates immediately, inside the
#        window, even when republications were absorbed before it ----------
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
peer_reset peer-a
export FM_WATCH_SUPERVISE_COALESCE_SECS=300
peer_drop CAPTAIN-BOARD.html 'board republication' >/dev/null
run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
if grep -q 'ESCALATION' "$OUT" 2>/dev/null; then
  ok "peer message: the window is established by the first republication"
else
  bad "peer message: the first republication did not escalate"
  sed 's/^/       /' "$OUT"
fi

peer_drop lane-ledger.tsv 'ledger republication' >/dev/null
run_bounded 30 "$SUPERVISE" > "$OUT.2" 2>&1
if grep -q 'republication absorbed' "$OUT.2" 2>/dev/null; then
  ok "peer message: a republication inside the window is absorbed before the message arrives"
else
  bad "peer message: the republication before the message was not absorbed"
  sed 's/^/       /' "$OUT.2"
fi

sha_msg=$(peer_drop 2026-10-21-hetz-to-controller-three-lanes-landed.md 'a message to the Controller')
run_bounded 30 "$SUPERVISE" > "$OUT.3" 2>&1
rc=$?

if grep -q 'ESCALATION' "$OUT.3" 2>/dev/null; then
  ok "peer message: a message to the Controller escalates immediately, inside the window"
else
  bad "peer message: the message to the Controller did not escalate inside the window"
  sed 's/^/       /' "$OUT.3"
fi

if grep -q '2026-10-21-hetz-to-controller-three-lanes-landed.md' "$OUT.3" 2>/dev/null; then
  ok "peer message: the escalation names the message the peer sent"
else
  bad "peer message: the escalation does not name the message"
  sed 's/^/       /' "$OUT.3"
fi

if grep -q 'absorbed=1' "$OUT.3" 2>/dev/null; then
  ok "peer message: the escalation still reports the republications that were absorbed before it"
else
  bad "peer message: the escalation does not report the absorbed republications"
  sed 's/^/       /' "$OUT.3"
fi

# --- 8e. A message and a republication arriving together produce ONE
#        escalation that names both ----------------------------------------
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
peer_reset peer-a
sha_board=$(peer_drop CAPTAIN-BOARD.html 'board republication')
sha_msg=$(peer_drop 2026-10-21-hetz-to-controller-three-lanes-landed.md 'a message to the Controller')
run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
rc=$?

escalations=$(grep -c 'ESCALATION' "$OUT" 2>/dev/null || printf '0')
if [ "$escalations" -eq 1 ]; then
  ok "peer message and republication together: exactly one escalation was produced"
else
  bad "peer message and republication together: expected 1 escalation, got $escalations"
  sed 's/^/       /' "$OUT"
fi

if grep -q '2026-10-21-hetz-to-controller-three-lanes-landed.md' "$OUT" 2>/dev/null \
   && grep -q "latest=CAPTAIN-BOARD.html" "$OUT" 2>/dev/null \
   && grep -q "sha=$sha_board" "$OUT" 2>/dev/null \
   && grep -q "sha=$sha_msg" "$OUT" 2>/dev/null; then
  ok "peer message and republication together: the single escalation names both"
else
  bad "peer message and republication together: the single escalation does not name both"
  sed 's/^/       /' "$OUT"
fi

# --- 8f. An unrecognised artefact kind escalates, never absorbed ----------
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
peer_reset peer-a
export FM_WATCH_SUPERVISE_COALESCE_SECS=300
peer_drop CAPTAIN-BOARD.html 'board republication' >/dev/null
run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
if grep -q 'ESCALATION' "$OUT" 2>/dev/null; then
  ok "peer unrecognised artefact: the window is established by the first republication"
else
  bad "peer unrecognised artefact: the first republication did not escalate"
  sed 's/^/       /' "$OUT"
fi

peer_drop 2026-10-21-hetz-ack-capacity-and-brandon-delivery.md 'an unrecognised artefact kind' >/dev/null
run_bounded 30 "$SUPERVISE" > "$OUT.2" 2>&1
if grep -q 'ESCALATION' "$OUT.2" 2>/dev/null; then
  ok "peer unrecognised artefact: an unrecognised artefact kind escalates inside the window"
else
  bad "peer unrecognised artefact: the unrecognised artefact kind was not escalated"
  sed 's/^/       /' "$OUT.2"
fi

if grep -q 'republication absorbed' "$OUT.2" 2>/dev/null; then
  bad "peer unrecognised artefact: the unrecognised artefact kind was absorbed"
  sed 's/^/       /' "$OUT.2"
else
  ok "peer unrecognised artefact: the unrecognised artefact kind was not absorbed"
fi

# --- 8g. The supervisor does not consume or mutate the wake queue ---------
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
peer_reset peer-a
peer_drop CAPTAIN-BOARD.html 'board republication' >/dev/null
peer_drop lane-ledger.tsv 'ledger republication' >/dev/null
queue_before=$(sha256sum "$PEER_QUEUE" 2>/dev/null | awk '{print $1}')
queue_lines_before=$(wc -l < "$PEER_QUEUE" 2>/dev/null | tr -d '[:space:]')
run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
queue_after=$(sha256sum "$PEER_QUEUE" 2>/dev/null | awk '{print $1}')
queue_lines_after=$(wc -l < "$PEER_QUEUE" 2>/dev/null | tr -d '[:space:]')

if [ -n "$queue_before" ] && [ "$queue_before" = "$queue_after" ]; then
  ok "peer wake queue: the supervisor did not mutate the wake queue"
else
  bad "peer wake queue: the supervisor changed the wake queue"
  sed 's/^/       /' "$OUT"
fi

if [ "$queue_lines_before" = "$queue_lines_after" ] && [ "$queue_lines_after" -ge 2 ]; then
  ok "peer wake queue: the pending records are still in the queue for the primary to drain"
else
  bad "peer wake queue: the pending records did not survive (before=$queue_lines_before after=$queue_lines_after)"
fi

# --- 8h. An absorbed republication is still on disk and in the ledger -----
new_home
export FM_WATCH_SUPERVISE_ARM="$STUB_ARM"
peer_reset peer-a
export FM_WATCH_SUPERVISE_COALESCE_SECS=300
peer_drop CAPTAIN-BOARD.html 'board republication' >/dev/null
run_bounded 30 "$SUPERVISE" > "$OUT" 2>&1
sha_ledger=$(peer_drop lane-ledger.tsv 'ledger republication')
run_bounded 30 "$SUPERVISE" > "$OUT.2" 2>&1

if grep -qxF "$sha_ledger"$'\t'"lane-ledger.tsv" "$PEER_LEDGER" 2>/dev/null; then
  ok "peer nothing dropped: the absorbed republication is still in the durable receipt ledger"
else
  bad "peer nothing dropped: the absorbed republication is not in the receipt ledger"
fi

if grep -q "comms-received: peer-a lane-ledger.tsv" "$PEER_STATUS" 2>/dev/null; then
  ok "peer nothing dropped: the absorbed republication is still recorded on the peer status channel"
else
  bad "peer nothing dropped: the absorbed republication is not recorded on the peer status channel"
fi

# ============================================================================
# House-style checks on the new script itself.
# ============================================================================
if bash -n "$SUPERVISE" 2>/dev/null; then
  ok "bash -n is clean"
else
  bad "bash -n failed"
fi

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S error "$SUPERVISE" >/dev/null 2>&1; then
    ok "shellcheck reports no errors"
  else
    bad "shellcheck reported errors"
    shellcheck -S error "$SUPERVISE" 2>&1 | head -20 | sed 's/^/       /'
  fi
fi

for needle in 'WHAT IT DOES' 'WHAT IT NEVER DOES' 'OUTPUT LINES' 'EXIT STATUS'; do
  if grep -q "$needle" "$SUPERVISE"; then
    ok "the header documents '$needle'"
  else
    bad "the header does not document '$needle'"
  fi
done

# ============================================================================
# The suite must not pollute the home it runs in.
#
# This compares the set of supervisor artefact NAMES in that home's state
# directory before the suite's work with the set after it. The "before" set
# was snapshotted before any case ran, so this measures the WHOLE suite, not
# one case.
#
# Names, not contents: a standing supervisor appends to its log while the
# suite runs, so a pre-existing artefact changes under us for reasons that are
# not pollution. A pre-existing artefact is legitimate; only a NEW name is
# pollution, and a new name is what would overwrite a live supervisor's state
# or make a later run believe a supervisor is running when it is not.
#
# A new name is not automatically the SUITE's doing: on a production host the
# standing supervisor is writing into this same directory while the suite
# runs, and its lock says who owns the home. Artefacts a live supervisor owns
# are attributed to it; anything else that appears is pollution and is named.
# ============================================================================
snapshot_home_artefacts "$HOME_ARTEFACTS_AFTER"
added_file="$TMP/home-artefacts.added"
pollution_file="$TMP/home-artefacts.pollution"
awk 'FILENAME == ARGV[1] { seen[$0] = 1; next } !($0 in seen)' \
  "$HOME_ARTEFACTS_BEFORE" "$HOME_ARTEFACTS_AFTER" > "$added_file"

supervisor_pid=$(live_supervisor_pid)
supervisor_log_after=$(supervisor_log_size)
# A supervisor counts as having been active during the run if it held the lock
# at either end of it, or if its log grew while the suite ran. That covers a
# supervisor that was up throughout, one that started mid-run, and one that
# exited mid-run - without which a transient artefact of the supervisor's own
# would be blamed on the suite.
supervisor_active=0
if [ -n "$SUPERVISOR_PID_BEFORE" ] || [ -n "$supervisor_pid" ]; then
  supervisor_active=1
elif [ "$supervisor_log_after" -gt "$SUPERVISOR_LOG_BEFORE" ]; then
  supervisor_active=1
fi

: > "$pollution_file"
attributed=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  if [ "$supervisor_active" -eq 1 ] && supervisor_owns_artefact "$name"; then
    attributed=$((attributed + 1))
    continue
  fi
  printf '%s\n' "$name" >> "$pollution_file"
done < "$added_file"

pollution_count=$(wc -l < "$pollution_file" | tr -d ' ')
pollution_count=${pollution_count:-0}
if [ "$pollution_count" -eq 0 ]; then
  if [ "$attributed" -gt 0 ]; then
    ok "the suite added no artefact of its own to the home's state directory ($attributed supervisor-owned artefact(s) appeared and were attributed to the supervisor active during the run)"
  else
    ok "the suite added no artefact of its own to the home's state directory"
  fi
else
  bad "the suite added $pollution_count artefact(s) of its own to the home's state directory"
  sed 's/^/       /' "$pollution_file"
fi

say ""
if [ "$fail" -eq 0 ]; then
  say "ALL TESTS PASSED ($checks checks)"; exit 0
fi
say "$fail of $checks CHECK(S) FAILED"; exit 1
