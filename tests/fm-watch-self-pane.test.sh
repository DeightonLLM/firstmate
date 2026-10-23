#!/usr/bin/env bash
# tests/fm-watch-self-pane.test.sh - the watcher must not accuse the PRIMARY
# of being an invisible crew.
#
# WHY THIS EXISTS. The always-on watcher runs INSIDE the primary's own pane.
# The primary is not a crewmate: it does not write heartbeat lines to its own
# task record the way a crewmate writes to its report file. The
# crew-visibility check therefore measured the primary as permanently silent
# and escalated it to the Captain as an invisible crew - the watcher accusing
# the agent that is doing the watching. Measured on 2026-10-23:
# "crew-silent: m3.1f-firstmate-boardland silent 120645s past the 1800s
# heartbeat bound" against the primary's own window default:wDB:p2. That was
# the third false positive in the same escalation treadmill, after the
# safety-net lane-count false alarm and the guard-attest "done" signal.
#
# WHAT IS PROVEN HERE. Every assertion drives a real executable against a real
# state directory and asserts on observed output or state. Nothing here reads
# a script's source bytes to decide what it "should" do.
#
#   1. The resolver (bin/fm-self-pane-lib.sh) identifies the primary's own
#      pane in each backend's own target shape, and identifies NOTHING when it
#      cannot - it never guesses.
#   2. The watcher, driven end to end, does NOT queue a crew-silent wake for
#      the primary's own pane.
#   3. The disconfirming case: a genuinely silent CREW on a DIFFERENT pane
#      still queues its crew-silent wake. The exclusion is the primary's own
#      pane and nothing else.
#   4. An unresolvable self pane leaves the behaviour exactly as it was - the
#      check still runs for every window, including the primary's own.
#
# Usage: tests/fm-watch-self-pane.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=tests/lib.sh
. "$ROOT/tests/lib.sh"
# shellcheck source=bin/fm-self-pane-lib.sh
. "$ROOT/bin/fm-self-pane-lib.sh"

WATCH="$ROOT/bin/fm-watch.sh"
VIS="$ROOT/bin/fm-crew-visibility.sh"
TMP_ROOT=$(fm_test_tmproot fm-watch-self-pane)

# --------------------------------------------------------------------------
# Part 1: the resolver. bin/fm-self-pane-lib.sh is a public interface (a
# sourced library), so calling it directly is the honest way to test it.
# --------------------------------------------------------------------------

# resolve_with <env-assignments...>: run the resolver in a clean environment
# with the given assignments and echo what it printed.
resolve_with() {
  local out
  out=$(env -u FM_WATCH_SELF_PANE -u TMUX_PANE -u TMUX -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_SESSION "$@" \
    bash -c '. "$1"; fm_self_pane_resolve' "$0" "$ROOT/bin/fm-self-pane-lib.sh" 2>/dev/null || true)
  printf '%s' "$out"
}

# --- herdr: the target shape is "<session>:<pane-id>", the pane id itself
# carrying a colon. The session is always the FIRST field.
out=$(resolve_with HERDR_ENV=1 HERDR_PANE_ID=wDB:p2)
[ "$out" = "default:wDB:p2" ] \
  && pass "the herdr resolver returns the session-qualified pane target" \
  || fail "herdr resolution wrong: got [$out], expected [default:wDB:p2]"

out=$(resolve_with HERDR_ENV=1 HERDR_PANE_ID=wDB:p2 HERDR_SESSION=other)
[ "$out" = "other:wDB:p2" ] \
  && pass "the herdr resolver honours a non-default session" \
  || fail "herdr session resolution wrong: got [$out], expected [other:wDB:p2]"

# --- tmux: the target shape is "<session>:<window name>". A tmux pane nested
# inside herdr must resolve to tmux (innermost-first, like fm_backend_detect).
mkdir -p "$TMP_ROOT/fakebin"
cat > "$TMP_ROOT/fakebin/tmux" <<'SH'
#!/usr/bin/env bash
set -u
printf '%s\n' "firstmate:fm-m3.1f-firstmate-boardland"
exit 0
SH
chmod +x "$TMP_ROOT/fakebin/tmux"
out=$(PATH="$TMP_ROOT/fakebin:$PATH" resolve_with TMUX_PANE=%3 TMUX=/tmp/tmux-0/default HERDR_ENV=1 HERDR_PANE_ID=wDB:p2)
[ "$out" = "firstmate:fm-m3.1f-firstmate-boardland" ] \
  && pass "the tmux resolver returns the session-qualified window target" \
  || fail "tmux resolution wrong: got [$out], expected [firstmate:fm-m3.1f-firstmate-boardland]"

out=$(PATH="$TMP_ROOT/fakebin:$PATH" resolve_with TMUX_PANE=%3 TMUX=/tmp/tmux-0/default HERDR_ENV=1 HERDR_PANE_ID=wDB:p2)
[ "$out" != "default:wDB:p2" ] \
  && pass "a tmux pane nested inside herdr resolves to tmux, not herdr" \
  || fail "nested tmux inside herdr resolved to the herdr target"

# --- fail closed: with no backend signal there is nothing to resolve, and the
# resolver must print NOTHING rather than guess a fallback.
out=$(resolve_with)
[ -z "$out" ] \
  && pass "an unidentifiable pane resolves to nothing rather than a guess" \
  || fail "unresolvable pane produced a guess: [$out]"

out=$(resolve_with HERDR_PANE_ID=wDB:p2)
[ -z "$out" ] \
  && pass "a herdr pane id without the herdr marker is not treated as a pane" \
  || fail "a bare herdr pane id was accepted without HERDR_ENV: [$out]"

# --- the override wins over detection, for an operator whose backend does not
# expose its pane and for deterministic tests.
out=$(env -u TMUX_PANE -u TMUX -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_SESSION \
  FM_WATCH_SELF_PANE="chosen:pane" \
  bash -c '. "$1"; fm_self_pane_resolve' "$0" "$ROOT/bin/fm-self-pane-lib.sh" 2>/dev/null || true)
[ "$out" = "chosen:pane" ] \
  && pass "an explicit override wins over detection" \
  || fail "the override did not win: got [$out], expected [chosen:pane]"

# --------------------------------------------------------------------------
# Part 2 and 3: the watcher, driven end to end.
# --------------------------------------------------------------------------

# make_case <name>: a scratch home with a state dir, a fake tmux that answers
# the pane capture, and a fake crew-state verdict. Echoes the case dir.
make_case() {
  local name=$1 dir="$TMP_ROOT/$1" fakebin="$TMP_ROOT/$1/fakebin"
  mkdir -p "$dir/state" "$fakebin"
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  display-message) printf '%s\n' "firstmate:fm-m3.1f-firstmate-boardland"; exit 0 ;;
  capture-pane)    cat "${FM_FAKE_TMUX_CAPTURE:-/dev/null}" 2>/dev/null; exit 0 ;;
  list-windows)    printf '%s\n' "${FM_FAKE_TMUX_WINDOW:-}"; exit 0 ;;
esac
exit 1
SH
  chmod +x "$fakebin/tmux"
  printf 'idle shell\n' > "$dir/pane.txt"
  printf '%s' "$dir"
}

# write_meta <state> <task-id> <window>: a task record whose window target is
# <window>, with the spawn stamp the visibility detector reads.
write_meta() {
  local state=$1 id=$2 window=$3
  {
    printf 'window=%s\n' "$window"
    printf 'endpoint_task_id=%s\n' "$id"
    printf 'harness=minimax-code\n'
    printf 'kind=ship\n'
    printf 'backend=tmux\n'
    printf 'spawned_at=%s\n' "$(( $(date +%s) - 100000 ))"
  } > "$state/$id.meta"
}

# write_silent_status <state> <task-id>: a status file whose last line is NOT a
# terminal verb and NOT a declared pause, aged past the heartbeat bound. This
# is exactly the shape that made the detector call the primary invisible.
#
# The .seen- marker is primed with the file's own size:mtime signature, so the
# watcher's signal scan treats the status file as already-seen history rather
# than a fresh captain-relevant signal. Otherwise the signal scan fires first
# and the watcher exits before it ever reaches the crew-visibility check, which
# would make every assertion below pass for the wrong reason.
write_silent_status() {
  local state=$1 id=$2 back sf
  printf 'working: still going\n' > "$state/$id.status"
  back=$(( $(date +%s) - 100000 ))
  if [ "$(uname)" = Darwin ]; then touch -mt "$(date -r "$back" '+%Y%m%d%H%M.%S')" "$state/$id.status"
  else touch -m -d "@$back" "$state/$id.status"; fi
  sf="$state/.seen-$(printf '%s' "$id.status" | tr '.' '_')"
  if [ "$(uname)" = Darwin ]; then stat -f '%z:%Fm' "$state/$id.status" > "$sf"
  else stat -c '%s:%Y' "$state/$id.status" > "$sf"; fi
}

# run_watcher <case-dir> <self-pane> [extra env...]: run the real watcher for
# one cycle against the scratch home and echo the case's wake queue.
run_watcher() {
  local dir=$1 selfpane=$2
  shift 2
  local state="$dir/state" fakebin="$dir/fakebin"
  PATH="$fakebin:$PATH" \
    FM_STATE_OVERRIDE="$state" \
    FM_FAKE_TMUX_CAPTURE="$dir/pane.txt" \
    FM_FAKE_TMUX_WINDOW="firstmate:fm-m3.1f-firstmate-boardland" \
    FM_WATCH_SELF_PANE="$selfpane" \
    FM_CREW_VISIBILITY_NOW="$(( $(date +%s) ))" \
    FM_POLL=1 FM_SIGNAL_GRACE=1 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
    "$@" \
    timeout 30 "$WATCH" > "$dir/watch.out" 2>&1 || true
  cat "$state/.wake-queue" 2>/dev/null || true
}

# --- 2: the primary's own pane is NOT accused.
dir=$(make_case primary-own-pane)
state="$dir/state"
write_meta "$state" "m3.1f-firstmate-boardland" "firstmate:fm-m3.1f-firstmate-boardland"
write_silent_status "$state" "m3.1f-firstmate-boardland"
queue=$(run_watcher "$dir" "firstmate:fm-m3.1f-firstmate-boardland")
if printf '%s' "$queue" | grep -q "crew-silent"; then
  fail "the watcher accused the primary's own pane of being an invisible crew: $queue"
else
  pass "the watcher does not accuse the primary's own pane of being an invisible crew"
fi

# The detector, run directly, still reports that same task as silent. If it
# did not, the assertion above would pass for the wrong reason (a broken
# fixture rather than a working exclusion).
out=$(FM_CREW_VISIBILITY_NOW="$(( $(date +%s) ))" "$VIS" "m3.1f-firstmate-boardland" "$state" 2>&1 || true)
case "$out" in
  *"crew-silent:"*) pass "the same task IS invisible to the detector, so the exclusion is what suppressed it" ;;
  *) fail "the fixture does not reproduce a silent crew: detector said [$out]" ;;
esac

# --- 3: the disconfirming case. A genuinely silent CREW on a DIFFERENT pane
# still queues its crew-silent wake. The exclusion must be the primary's own
# pane and nothing else.
dir=$(make_case real-crew)
state="$dir/state"
write_meta "$state" "m3.1f-firstmate-boardland" "firstmate:fm-m3.1f-firstmate-boardland"
write_silent_status "$state" "m3.1f-firstmate-boardland"
write_meta "$state" "mcode-m3.1f-controller-somecrew" "firstmate:fm-mcode-m3.1f-controller-somecrew"
write_silent_status "$state" "mcode-m3.1f-controller-somecrew"
queue=$(run_watcher "$dir" "firstmate:fm-m3.1f-firstmate-boardland")
if printf '%s' "$queue" | grep -q "crew-silent: mcode-m3.1f-controller-somecrew"; then
  pass "a genuinely silent crew on a different pane still queues its crew-silent wake"
else
  fail "the exclusion silenced a real crew too: $queue"
fi
if printf '%s' "$queue" | grep -q "crew-silent: m3.1f-firstmate-boardland"; then
  fail "the primary's own pane was accused even with a real crew present: $queue"
else
  pass "the primary's own pane stays clear even with a real crew present"
fi

# --- 4: an unresolvable self pane leaves the behaviour exactly as it was. The
# check still runs for every window, including the primary's own.
dir=$(make_case unresolvable-self)
state="$dir/state"
write_meta "$state" "m3.1f-firstmate-boardland" "firstmate:fm-m3.1f-firstmate-boardland"
write_silent_status "$state" "m3.1f-firstmate-boardland"
queue=$(run_watcher "$dir" "")
if printf '%s' "$queue" | grep -q "crew-silent: m3.1f-firstmate-boardland"; then
  pass "an unresolvable self pane leaves the check running for every window"
else
  fail "an unresolvable self pane silently disabled the crew check: $queue"
fi

printf 'ALL TESTS PASSED\n'
