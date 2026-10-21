#!/usr/bin/env bash
# tests/fm-comms-notify-hang.test.sh - the comms ingest must not be wedged by
# a notification that never returns.
#
# Why this suite exists (lane m3.1f-firstmate-lockdeadline, 2026-10-21):
# the Controller's comms receipt lock was held forever by a scan that had
# called the notifier while still holding that lock. The notifier's prompt
# blocks until the recipient pane accepts the submission, and the measured
# `herdr agent list` returned an EMPTY list with agent_status "unknown", so
# the old gate fell straight through to the prompt branch. One unresponsive
# pane became an unbounded comms outage: every later scan piled up behind the
# stuck lock holder, each spinning at 10 Hz and leaking a lock owner dir.
#
# What this suite PROVES:
#   1. A recipient whose agent status cannot be read is NOT prompted. The
#      notification is deferred into the durable pending queue instead.
#   2. A prompt that never returns is BOUNDED. The notifier gives up on its
#      own deadline instead of blocking forever.
#   3. A notification that never returns must not wedge the ingest: the scan
#      completes, the receipts are recorded, and the receipts lock is
#      released.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INGEST="$ROOT/bin/fm-comms-ingest.sh"
NOTIFY="$ROOT/bin/fm-comms-notify.sh"

TMP_ROOT=$(fm_test_tmproot fm-comms-notify-hang-tests)

# fake_herdr <dir> <mode>
# A stand-in for the herdr CLI.
#   mode=unknown : `agent list` returns the measured EMPTY list and `pane
#                   list` returns one pane whose agent_status is "unknown".
#   mode=idle    : `agent list` returns one agent that is idle and ready.
# In BOTH modes `agent prompt` HANGS FOREVER and records that it was called,
# so a test can prove whether the prompt branch was reached at all.
fake_herdr() {
  local dir=$1 mode=$2
  mkdir -p "$dir/bin"
  cat >"$dir/bin/herdr" <<'HERDR'
#!/usr/bin/env bash
set -u
mode="$FM_FAKE_HERDR_MODE"
case "${1:-} ${2:-}" in
  "agent list")
    if [ "$mode" = "idle" ]; then
      printf '%s\n' '{"id":"cli:agent:list","result":{"agents":[{"name":"controller","pane_id":"pane-1","label":"","agent_status":"idle","interactive_ready":true}],"type":"agent_list"}}'
    else
      # The measured 2026-10-21 response: an EMPTY agent list.
      printf '%s\n' '{"id":"cli:agent:list","result":{"agents":[],"type":"agent_list"}}'
    fi
    exit 0
    ;;
  "pane list")
    printf '%s\n' '{"id":"cli:pane:list","result":{"panes":[{"pane_id":"pane-1","label":"","agent_status":"unknown"}],"type":"pane_list"}}'
    exit 0
    ;;
  "agent prompt")
    # The prompt branch was reached. Record it, then never return.
    printf '%s\n' "$*" >>"$FM_FAKE_HERDR_PROMPT_LOG"
    while :; do sleep 1; done
    ;;
esac
exit 0
HERDR
  chmod +x "$dir/bin/herdr"
}

# ---------------------------------------------------------------------------
# 1. An UNKNOWN agent status must DEFER, not prompt.
# ---------------------------------------------------------------------------
test_unknown_agent_status_defers_instead_of_prompting() {
  local dir state src prompt_log out
  dir="$TMP_ROOT/unknown"
  mkdir -p "$dir/state" "$dir/src"
  state="$dir/state"
  src="$dir/src"
  prompt_log="$dir/prompt.log"
  : >"$prompt_log"
  printf 'a reply nobody can see the state of\n' >"$src/reply.md"

  fake_herdr "$dir" unknown

  out=$(PATH="$dir/bin:$PATH" FM_FAKE_HERDR_MODE=unknown \
    FM_FAKE_HERDR_PROMPT_LOG="$prompt_log" \
    FM_HOME="$dir" FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" \
    FM_COMMS_NO_NOTIFY=0 FM_COMMS_NOTIFY_TIMEOUT_S=5 \
    timeout 30 "$NOTIFY" notify --route controller --file reply.md --sha deadbeef 2>&1) || true

  printf '%s\n' "$out" >"$dir/out.txt"
  assert_grep "deferred:" "$dir/out.txt" \
    "an unknown agent status must defer the notification, not prompt it"
  if [ -s "$prompt_log" ]; then
    fail "an unknown agent status must never reach the prompt branch (prompt log: $(cat "$prompt_log"))"
  fi
  # The deferral is durable, so the notification is not lost.
  assert_present "$state/comms-pending-notify/controller/deadbeef.pending" \
    "a deferred notification must be recorded in the durable pending queue"
  pass "an unknown agent status defers the notification instead of prompting"
}

# ---------------------------------------------------------------------------
# 2. A prompt that never returns is bounded.
# ---------------------------------------------------------------------------
test_hanging_prompt_is_bounded() {
  local dir state prompt_log out started ended elapsed rc
  dir="$TMP_ROOT/bounded"
  mkdir -p "$dir/state"
  state="$dir/state"
  prompt_log="$dir/prompt.log"
  : >"$prompt_log"

  fake_herdr "$dir" idle

  started=$(date +%s)
  out=$(PATH="$dir/bin:$PATH" FM_FAKE_HERDR_MODE=idle \
    FM_FAKE_HERDR_PROMPT_LOG="$prompt_log" \
    FM_HOME="$dir" FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" \
    FM_COMMS_NOTIFY_TIMEOUT_S=5 \
    timeout 60 "$NOTIFY" notify --route controller --file reply.md --sha cafe 2>&1) && rc=0 || rc=$?
  ended=$(date +%s)
  elapsed=$((ended - started))

  printf '%s\n' "$out" >"$dir/out.txt"
  [ "$elapsed" -le 30 ] \
    || fail "the hanging prompt was not bounded: the notifier took ${elapsed}s (the bound was 5s)"
  assert_no_grep "notified:" "$dir/out.txt" \
    "a prompt that never returned must not be reported as notified"
  assert_grep "exceeded its" "$dir/out.txt" \
    "an abandoned prompt must say that it exceeded its bound"
  pass "a prompt that never returns is bounded (${elapsed}s against a 5s bound)"
}

# ---------------------------------------------------------------------------
# 3. A notification that never returns must not wedge the ingest: the scan
#    completes, the receipts are recorded, and the receipts lock is released.
# ---------------------------------------------------------------------------
test_hanging_notification_does_not_wedge_the_ingest() {
  local dir state src prompt_log started ended elapsed rc out receipts lock
  dir="$TMP_ROOT/wedge"
  mkdir -p "$dir/state" "$dir/src"
  state="$dir/state"
  src="$dir/src"
  prompt_log="$dir/prompt.log"
  : >"$prompt_log"
  printf 'a reply that will be notified into a pane that never answers\n' >"$src/reply.md"

  fake_herdr "$dir" idle

  receipts="$state/comms-receipts/hangprobe/receipts.tsv"
  lock="$state/comms-receipts/hangprobe/.lock"

  started=$(date +%s)
  out=$(PATH="$dir/bin:$PATH" FM_FAKE_HERDR_MODE=idle \
    FM_FAKE_HERDR_PROMPT_LOG="$prompt_log" \
    FM_HOME="$dir" FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$state" \
    FM_COMMS_NO_NOTIFY=0 FM_COMMS_NOTIFY_TIMEOUT_S=5 \
    FM_COMMS_NOTIFY_DISPATCH_TIMEOUT_S=5 \
    timeout 60 "$INGEST" scan hangprobe "$src" 2>&1) && rc=0 || rc=$?
  ended=$(date +%s)
  elapsed=$((ended - started))

  printf '%s\n' "$out" >"$dir/out.txt"
  [ "$elapsed" -le 45 ] \
    || fail "the ingest was wedged by the notification: it took ${elapsed}s"
  [ "$rc" -eq 0 ] \
    || fail "the ingest did not complete: exit $rc"$'\n'"--- output ---"$'\n'"$out"
  assert_grep "ingested: 1" "$dir/out.txt" "the scan must report the ingested reply"

  # The reply must be RECEIPTED. Before this fix the ingest was killed with
  # the lock still held, so the receipt was never written and the reply was
  # re-scanned forever.
  assert_present "$receipts" "the ingest must write the receipts ledger"
  assert_grep "reply.md" "$receipts" "the reply must be receipted even though the notification never returned"

  # And the receipts lock must be RELEASED, so the next scan is not blocked.
  if [ -e "$lock" ] || [ -L "$lock" ]; then
    fail "the receipts lock was not released after the scan (still present: $lock)"
  fi
  pass "a notification that never returns does not wedge the ingest (${elapsed}s, receipted, lock released)"
}

test_unknown_agent_status_defers_instead_of_prompting
test_hanging_prompt_is_bounded
test_hanging_notification_does_not_wedge_the_ingest
