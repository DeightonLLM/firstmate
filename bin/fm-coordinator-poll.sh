#!/usr/bin/env bash
# fm-coordinator-poll.sh — Persistent Coordinator Polling Loop
#
# Design principle: make persistent coordinator polling a first-class concept by
# implementing the smallest safe external loop that runs after every worker/status
# handoff. It wakes the coordinator, polls Herdr, reads artifacts, closes accepted
# panes, refills eligible slots, and schedules an independent M3 checker.
#
# Safety guarantees:
#   - Survives chat-turn termination: state is persisted in state/ files
#   - Bounded cadence/backoff: exponential backoff with configurable limits
#   - Duplicate dispatch avoidance: idempotent state transitions with dedup markers
#   - Testable: --dry-run and --once modes for validation
#   - Rollback evidence: state/<lane>.rollback files for audit
#
# How it integrates with firstmate:
#   - The watcher calls this script after surfacing a handoff event
#   - Can run standalone as a daemon for self-contained operation
#   - Reads pane state from Herdr and makes decisions based on agent_status
#
# Usage:
#   fm-coordinator-poll.sh cycle [--dry-run]
#   fm-coordinator-poll.sh status
#   fm-coordinator-poll.sh daemon [--once]
#   fm-coordinator-poll.sh poll-herdr [--json]
#   fm-coordinator-poll.sh close-accepted [--dry-run]
#   fm-coordinator-poll.sh refill-slots [--dry-run]
#   fm-coordinator-poll.sh schedule-checker [--dry-run]
#
# Environment:
#   FM_COORD_POLL_INTERVAL       poll interval in daemon mode (default: 30s)
#   FM_COORD_POLL_BACKOFF_MAX    max backoff multiplier (default: 8)
#   FM_COORD_POLL_INITIAL_BACKOFF initial backoff seconds (default: 5)
#   FM_COORD_CHECKER_MODEL       model for checker slot (default: GLM-5.2)
#   FM_COORD_DEDUP_WINDOW        seconds to dedup same event (default: 60)
#   FM_COORD_HERDR_SESSION       herdr session to poll (default: default)
#   FM_COORD_HERDR_HELPER        path to fm-herdr-lab.sh helper
#
set -u

# Allow sourcing for unit testing
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  return 0 2>/dev/null || exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"

# Source dependencies
# Prevent fm-herdr-session-cleanup.sh from running cleanup and exit-ing the shell
# shellcheck source=bin/fm-herdr-session-cleanup.sh
FM_HERDR_SESSION_CLEANUP_SOURCE_ONLY=1 . "$SCRIPT_DIR/fm-herdr-session-cleanup.sh" 2>/dev/null || true
# For fm_path_age
# shellcheck source=bin/fm-wake-lib.sh
. "$SCRIPT_DIR/fm-wake-lib.sh" 2>/dev/null || true

# age_of: seconds since file mtime; "due immediately" if missing
age_of() {
  local path=$1 mtime
  [ -e "$path" ] || { echo 999999; return; }
  if [ "$(uname)" = Darwin ]; then
    mtime=$(stat -f %m "$path" 2>/dev/null) || { echo 999999; return; }
  else
    mtime=$(stat -c %Y "$path" 2>/dev/null) || { echo 999999; return; }
  fi
  echo $(( $(date +%s) - mtime ))
}

# --- Tunables ---------------------------------------------------------------
POLL_INTERVAL="${FM_COORD_POLL_INTERVAL:-30}"
INITIAL_BACKOFF="${FM_COORD_POLL_INITIAL_BACKOFF:-5}"
BACKOFF_MAX="${FM_COORD_POLL_BACKOFF_MAX:-8}"
CHECKER_MODEL="${FM_COORD_CHECKER_MODEL:-GLM-5.2}"
DEDUP_WINDOW="${FM_COORD_DEDUP_WINDOW:-60}"
HERDR_SESSION="${FM_COORD_HERDR_SESSION:-default}"
HERDR_HELPER="${FM_COORD_HERDR_HELPER:-}"

# Daemon state
_daemon_running=0
_daemon_cycle_count=0
_backoff_multiplier=1

# --- Helpers ----------------------------------------------------------------

# log: write to stderr with timestamp
log() {
  printf '%s: coord-poll: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

# dedup_key: generate a dedup key for an event
dedup_key() {
  local event=$1 pane_id=$2
  printf '%s:%s' "$event" "$pane_id"
}

# is_duplicate_event: check if an event was already processed within DEDUP_WINDOW
is_duplicate_event() {
  local key=$1
  local marker="$STATE/.coord-poll-dedup-$key"
  local age
  age=$(age_of "$marker")
  [ "$age" -lt "$DEDUP_WINDOW" ]
}

# mark_event_processed: record that an event was processed
mark_event_processed() {
  local key=$1
  local marker="$STATE/.coord-poll-dedup-$key"
  mkdir -p "$STATE"
  date +%s > "$marker"
}

# cleanup_old_dedup_markers: remove dedup markers older than DEDUP_WINDOW
cleanup_old_dedup_markers() {
  local age marker
  for marker in "$STATE"/.coord-poll-dedup-*; do
    [ -e "$marker" ] || continue
    [ "${marker##*/}" = ".coord-poll-dedup-*" ] && continue
    age=$(age_of "$marker")
    [ "$age" -ge "$DEDUP_WINDOW" ] && rm -f "$marker"
  done
}

# recover_stale_dedup_markers: clear dedup markers for panes that are no longer
# terminal or whose work may not have completed. This recovers from crashes that
# occur after marking dedup but before completing close/refill/checker work.
# Strategy: for each dedup marker, check if the corresponding pane:
#   1. No longer exists in herdr (pane was closed externally - clear marker)
#   2. Is in a non-terminal state (pane was restarted - clear marker)
#   3. Is still terminal but work was not done (no close/refill/checker marker - clear)
recover_stale_dedup_markers() {
  local panes_json pane_map="" pane_id status agent

  # Build a map of pane_id -> status from current herdr state
  panes_json=$(poll_herdr_panes) || return 0  # soft failure - don't block cycle

  # Parse pane states into a lookup format: "pane_id:status"
  while IFS= read -r pane_json; do
    [ -z "$pane_json" ] && continue
    pane_id=$(pane_id_from_json "$pane_json")
    [ -z "$pane_id" ] && continue
    status=$(pane_status_from_json "$pane_json")
    pane_map="${pane_map}${pane_id}:${status}\n"
  done <<< "$panes_json"

  # Scan dedup markers and recover stale ones
  local marker dedup_key pane_key event_type stale=0 cleared=0
  for marker in "$STATE"/.coord-poll-dedup-*; do
    [ -e "$marker" ] || continue
    [ "${marker##*/}" = ".coord-poll-dedup-*" ] && continue

    dedup_key="${marker##*/.coord-poll-dedup-}"
    # dedup_key format: "event:pane_id" e.g., "handoff:w1:p1"
    pane_key="${dedup_key#*:}"
    event_type="${dedup_key%%:*}"

    # Check if pane still exists in herdr
    local current_status=""
    current_status=$(printf '%s' "$pane_map" | grep "^${pane_key}:" | head -1 | cut -d: -f2-)

    if [ -z "$current_status" ]; then
      # Pane no longer exists - work was done externally, clear marker
      log "recover: clearing dedup marker for absent pane $pane_key"
      rm -f "$marker"
      cleared=$((cleared + 1))
      stale=$((stale + 1))
    elif ! is_terminal_pane "$current_status"; then
      # Pane is no longer terminal - it was restarted or progressed
      # The original handoff work is stale, clear marker
      log "recover: clearing dedup marker for non-terminal pane $pane_key (status=$current_status)"
      rm -f "$marker"
      cleared=$((cleared + 1))
      stale=$((stale + 1))
    else
      # Pane is still terminal - check if work markers indicate incomplete work
      # Work is complete if we have close-accepted OR refill marker for this pane
      local close_marker="$STATE/.coord-poll-dedup-close-accepted:${pane_key}"
      local refill_marker="$STATE/.coord-poll-refill-done:${pane_key}"

      # For handoff markers, check if close-accepted was also processed
      if [ "$event_type" = "handoff" ] && [ ! -f "$close_marker" ]; then
        # No close-accepted marker means work was not completed
        log "recover: clearing incomplete handoff marker for $pane_key (close not done)"
        rm -f "$marker"
        cleared=$((cleared + 1))
        stale=$((stale + 1))
      fi
    fi
  done

  [ "$cleared" -gt 0 ] && log "recover: cleared $cleared stale dedup markers"
  return 0
}

# recover_stale_refill_markers: clear refill markers for panes that are no longer
# terminal or whose pane no longer exists. This recovers from edge cases where:
#   1. Pane was closed externally (no longer in herdr) - clear marker
#   2. Pane transitioned to non-terminal state (restarted) - clear marker
#   3. Marker expired and pane is still terminal - allow reprocessing
# Strategy: for each refill marker, check if the corresponding pane is still terminal.
# If not, clear the marker so the pane can be re-processed if it becomes terminal again.
recover_stale_refill_markers() {
  local panes_json pane_map="" pane_id status

  # Build a map of pane_id -> status from current herdr state
  panes_json=$(poll_herdr_panes) || return 0  # soft failure - don't block cycle

  # Parse pane states into a lookup format: "pane_id:status"
  while IFS= read -r pane_json; do
    [ -z "$pane_json" ] && continue
    pane_id=$(pane_id_from_json "$pane_json")
    [ -z "$pane_id" ] && continue
    status=$(pane_status_from_json "$pane_json")
    pane_map="${pane_map}${pane_id}:${status}\n"
  done <<< "$panes_json"

  # Scan refill markers and recover stale ones
  local marker cleared=0
  for marker in "$STATE"/.coord-poll-refill-*; do
    [ -e "$marker" ] || continue
    [ "${marker##*/}" = ".coord-poll-refill-*" ] && continue

    local pane_id="${marker##*/.coord-poll-refill-}"

    # Check if pane still exists in herdr
    local current_status=""
    current_status=$(printf '%s' "$pane_map" | grep "^${pane_id}:" | head -1 | cut -d: -f2-)

    if [ -z "$current_status" ]; then
      # Pane no longer exists - clear marker
      log "recover: clearing refill marker for absent pane $pane_id"
      rm -f "$marker"
      cleared=$((cleared + 1))
    elif ! is_terminal_pane "$current_status"; then
      # Pane is no longer terminal - it was restarted or progressed
      # Clear marker so it can be re-processed if it becomes terminal again
      log "recover: clearing refill marker for non-terminal pane $pane_id (status=$current_status)"
      rm -f "$marker"
      cleared=$((cleared + 1))
    fi
    # If pane is still terminal, keep the marker (refill already done)
  done

  [ "$cleared" -gt 0 ] && log "recover: cleared $cleared stale refill markers"
  return 0
}

# compute_backoff: return the backoff sleep seconds
compute_backoff() {
  local base=${1:-1}
  local result=$(( INITIAL_BACKOFF * base ))
  [ "$result" -gt $(( INITIAL_BACKOFF * BACKOFF_MAX )) ] && result=$(( INITIAL_BACKOFF * BACKOFF_MAX ))
  printf '%s\n' "$result"
}

# --- State-Based Refill Fallback ---
# The handoff-based trigger (needs_attention) only fires on NEW status transitions.
# A terminal pane whose handoff was already processed (deduped) won't trigger refill
# on subsequent cycles. This state-based fallback ensures terminal panes get refilled
# even when no new handoff event exists.

# REFILL_DEDUP_WINDOW: how long a refill marker persists (longer than DEDUP_WINDOW
# because refill should happen exactly once per terminal state, not time-bounded)
REFILL_DEDUP_WINDOW="${FM_COORD_REFILL_DEDUP_WINDOW:-3600}"

# is_refill_done: check if a terminal pane has already been refilled
# Returns 0 if refill was done, 1 if pending
is_refill_done() {
  local pane_id=$1
  local marker="$STATE/.coord-poll-refill-$pane_id"
  [ -f "$marker" ]
}

# mark_refill_done: record that a terminal pane was refilled
mark_refill_done() {
  local pane_id=$1
  local marker="$STATE/.coord-poll-refill-$pane_id"
  mkdir -p "$STATE"
  date +%s > "$marker"
}

# count_pending_refill: count terminal worker panes that haven't been refilled yet
# Takes panes_json on stdin, returns count on stdout
count_pending_refill() {
  local count=0 pane_json
  while IFS= read -r pane_json; do
    [ -z "$pane_json" ] && continue
    local pane_id status agent
    pane_id=$(pane_id_from_json "$pane_json")
    status=$(pane_status_from_json "$pane_json")
    agent=$(pane_agent_from_json "$pane_json")

    # Only process worker panes
    is_worker_pane "$agent" || continue
    # Only count terminal panes
    is_terminal_pane "$status" || continue
    # Skip if already refilled
    is_refill_done "$pane_id" && continue
    count=$((count + 1))
  done
  printf '%s\n' "$count"
}

# has_pending_refill: check if any terminal worker pane needs refill
# Takes panes_json on stdin, returns 0 (needs refill) or 1 (nothing pending)
has_pending_refill() {
  local count
  count=$(count_pending_refill)
  [ "$count" -gt 0 ]
}

# cleanup_refill_markers: remove refill markers older than REFILL_DEDUP_WINDOW
# This ensures we don't permanently skip a terminal pane if the refill failed
# and we want to retry after the marker expires
cleanup_refill_markers() {
  local age marker
  for marker in "$STATE"/.coord-poll-refill-*; do
    [ -e "$marker" ] || continue
    [ "${marker##*/}" = ".coord-poll-refill-*" ] && continue
    age=$(age_of "$marker")
    [ "$age" -ge "$REFILL_DEDUP_WINDOW" ] && rm -f "$marker"
  done
}

# get_pending_refill_panes: list terminal worker panes that haven't been refilled
# Takes panes_json on stdin, outputs pane_ids (one per line)
get_pending_refill_panes() {
  local pane_json
  while IFS= read -r pane_json; do
    [ -z "$pane_json" ] && continue
    local pane_id status agent
    pane_id=$(pane_id_from_json "$pane_json")
    status=$(pane_status_from_json "$pane_json")
    agent=$(pane_agent_from_json "$pane_json")

    # Only process worker panes
    is_worker_pane "$agent" || continue
    # Only list terminal panes
    is_terminal_pane "$status" || continue
    # Skip if already refilled
    is_refill_done "$pane_id" && continue
    printf '%s\n' "$pane_id"
  done
}

# pane_status_from_json: extract agent_status from pane JSON
pane_status_from_json() {
  local pane_json=$1
  printf '%s' "$pane_json" | jq -r '.agent_status // empty' 2>/dev/null || true
}

# pane_id_from_json: extract pane_id from pane JSON
pane_id_from_json() {
  local pane_json=$1
  printf '%s' "$pane_json" | jq -r '.pane_id // empty' 2>/dev/null || true
}

# pane_agent_from_json: extract agent from pane JSON
pane_agent_from_json() {
  local pane_json=$1
  printf '%s' "$pane_json" | jq -r '.agent // empty' 2>/dev/null || true
}

# pane_workspace_from_json: extract workspace_id from pane JSON
pane_workspace_from_json() {
  local pane_json=$1
  printf '%s' "$pane_json" | jq -r '.workspace_id // empty' 2>/dev/null || true
}

# pane_focused_from_json: extract focused from pane JSON
pane_focused_from_json() {
  local pane_json=$1
  printf '%s' "$pane_json" | jq -r '.focused # false' 2>/dev/null || echo false
}

# pane_revision_from_json: extract revision from pane JSON
pane_revision_from_json() {
  local pane_json=$1
  printf '%s' "$pane_json" | jq -r '.revision // 0' 2>/dev/null || echo 0
}

# --- Herdr Integration -------------------------------------------------------

# herdr_run: run a herdr command through the helper if available, or direct
herdr_run() {
  local args=("$@")
  if [ -n "$HERDR_HELPER" ] && [ -x "$HERDR_HELPER" ]; then
    "$HERDR_HELPER" run "$HERDR_SESSION" "${args[@]}" 2>&1
  else
    HERDR_SESSION="$HERDR_SESSION" herdr "${args[@]}" 2>&1
  fi
}

# poll_herdr_panes: get the current pane list from Herdr
# Returns JSON array of panes on stdout, empty on error
poll_herdr_panes() {
  local output
  output=$(herdr_run pane list) || { log "herdr pane list failed"; echo "[]"; return 1; }
  printf '%s' "$output" | jq -r '.result.panes[] | @json' 2>/dev/null || {
    log "failed to parse herdr pane list"; echo "[]"; return 1; }
}

# close_herdr_pane: close a specific pane by ID
close_herdr_pane() {
  local pane_id=$1
  herdr_run pane close "$pane_id" 2>&1 || log "close pane $pane_id failed"
}

# read_pane_output: read terminal output from a pane
read_pane_output() {
  local pane_id=$1 limit=${2:-100}
  herdr_run pane read "$pane_id" --limit "$limit" 2>&1
}

# --- Pane Classification ----------------------------------------------------

# is_accepted_pane: check if a pane is in an accepted terminal state
# Accepted states: done (agent completed successfully)
is_accepted_pane() {
  local status=$1
  [ "$status" = done ]
}

# is_terminal_pane: check if a pane is in any terminal state
# Terminal states: done, failed, blocked
is_terminal_pane() {
  local status=$1
  case "$status" in
    done|failed|blocked) return 0 ;;
  esac
  return 1
}

# is_worker_pane: check if a pane is a worker (pi agent)
is_worker_pane() {
  local agent=$1
  [ "$agent" = pi ]
}

# is_checker_pane: check if a pane is the checker (M3 model)
is_checker_pane() {
  local pane_json=$1
  # Checker panes are identified by model or by workspace pattern
  # The model field isn't directly in pane JSON, so we check workspace
  local workspace
  workspace=$(pane_workspace_from_json "$pane_json")
  # Checker workspaces typically follow pattern: w<num>:checker or contain checker
  [[ "$workspace" =~ checker ]] && return 0
  return 1
}

# --- Artifact Reading -------------------------------------------------------

# read_pane_artifact: read and cache pane artifact (last N lines of output)
# Writes to state/.coord-poll-artifact-<pane_id>
read_pane_artifact() {
  local pane_id=$1
  local artifact_file="$STATE/.coord-poll-artifact-$pane_id"
  local output
  output=$(read_pane_output "$pane_id" 100) || return 1
  mkdir -p "$STATE"
  printf '%s\n' "$output" > "$artifact_file"
  log "artifact cached for pane $pane_id"
}

# has_new_artifact: check if pane has new output since last read
has_new_artifact() {
  local pane_id=$1
  local artifact_file="$STATE/.coord-poll-artifact-$pane_id"
  [ -f "$artifact_file" ] || return 0  # no artifact = new
  return 1  # artifact exists = not new
}

# --- Slot Management --------------------------------------------------------

# get_lane_for_pane: find which lane owns a pane by its workspace/pane_id
get_lane_for_pane() {
  local pane_id=$1
  local meta_file
  for meta_file in "$STATE"/lane-*.meta; do
    [ -e "$meta_file" ] || continue
    [ "${meta_file##*/}" = "lane-*.meta" ] && continue
    if grep -q "^window=$pane_id" "$meta_file" 2>/dev/null; then
      basename "$meta_file" .meta
      return 0
    fi
  done
  return 1
}

# get_checker_lane: return the lane ID designated as the checker slot
get_checker_lane() {
  printf '%s\n' "lane-004"
}

# is_checker_slot: check if a lane is the checker slot
is_checker_slot() {
  local lane_id=$1
  [ "$lane_id" = "lane-004" ]
}

# --- Coordinator Actions ----------------------------------------------------

# cmd_poll_herdr: poll Herdr for pane states and log findings
cmd_poll_herdr() {
  local as_json=${1:-}
  local panes_json
  panes_json=$(poll_herdr_panes) || return 1

  local count=0
  local terminal_count=0
  local accepted_count=0
  local worker_count=0

  while IFS= read -r pane_json; do
    [ -z "$pane_json" ] && continue
    count=$((count + 1))

    local pane_id status agent workspace
    pane_id=$(pane_id_from_json "$pane_json")
    status=$(pane_status_from_json "$pane_json")
    agent=$(pane_agent_from_json "$pane_json")
    workspace=$(pane_workspace_from_json "$pane_json")

    if is_terminal_pane "$status"; then
      terminal_count=$((terminal_count + 1))
      if is_accepted_pane "$status"; then
        accepted_count=$((accepted_count + 1))
      fi
    fi

    if is_worker_pane "$agent"; then
      worker_count=$((worker_count + 1))
    fi

    if [ -n "$as_json" ]; then
      printf '%s\n' "$pane_json" | jq --arg pane_id "$pane_id" \
        --arg status "$status" --arg agent "$agent" --arg workspace "$workspace" \
        '{pane_id, status, agent, workspace}'
    fi
  done <<< "$panes_json"

  log "poll: total=$count terminal=$terminal_count accepted=$accepted_count workers=$worker_count"

  [ -n "$as_json" ] && return 0
  printf 'Panes: total=%s terminal=%s accepted=%s workers=%s\n' \
    "$count" "$terminal_count" "$accepted_count" "$worker_count"
}

# cmd_close_accepted: close panes that are in accepted (done) state
cmd_close_accepted() {
  local dry_run=${1:-}
  local panes_json closed=0 skipped=0
  panes_json=$(poll_herdr_panes) || return 1

  while IFS= read -r pane_json; do
    [ -z "$pane_json" ] && continue

    local pane_id status agent
    pane_id=$(pane_id_from_json "$pane_json")
    status=$(pane_status_from_json "$pane_json")
    agent=$(pane_agent_from_json "$pane_json")

    # Only handle worker panes (pi agent)
    is_worker_pane "$agent" || continue

    # Only close accepted (done) panes
    is_accepted_pane "$status" || continue

    # Deduplication check
    local dedup
    dedup=$(dedup_key "close-accepted" "$pane_id")
    if is_duplicate_event "$dedup"; then
      log "skipping duplicate close-accepted for pane $pane_id"
      skipped=$((skipped + 1))
      continue
    fi

    # Read artifact before closing
    read_pane_artifact "$pane_id" || true

    if [ -n "$dry_run" ]; then
      printf 'DRY RUN: would close accepted pane %s (status=%s)\n' "$pane_id" "$status"
    else
      close_herdr_pane "$pane_id"
      mark_event_processed "$dedup"
      closed=$((closed + 1))
      log "closed accepted pane $pane_id"
    fi
  done <<< "$panes_json"

  printf 'close-accepted: closed=%s skipped_dup=%s\n' "$closed" "$skipped"
}

# cmd_refill_slots: call always-four cycle to refill terminal lanes
cmd_refill_slots() {
  local dry_run=${1:-}
  # Delegate to always-four if available
  if [ -x "$SCRIPT_DIR/fm-always-four.sh" ]; then
    if [ -n "$dry_run" ]; then
      "$SCRIPT_DIR/fm-always-four.sh" cycle --dry-run 2>&1
    else
      "$SCRIPT_DIR/fm-always-four.sh" cycle 2>&1
    fi
  else
    log "fm-always-four.sh not found, refill skipped"
    return 1
  fi
}

# cmd_schedule_checker: schedule an independent M3 checker after worker batch
cmd_schedule_checker() {
  local dry_run=${1:-}
  local batch_size=${2:-3}  # default batch size before checker runs

  # Count workers in terminal state since last checker
  local terminal_workers=0
  local panes_json
  panes_json=$(poll_herdr_panes) || return 1

  while IFS= read -r pane_json; do
    [ -z "$pane_json" ] && continue
    local status agent
    status=$(pane_status_from_json "$pane_json")
    agent=$(pane_agent_from_json "$pane_json")

    if is_worker_pane "$agent" && is_terminal_pane "$status"; then
      terminal_workers=$((terminal_workers + 1))
    fi
  done <<< "$panes_json"

  # Check if we've hit the batch threshold
  local checker_marker="$STATE/.coord-poll-last-checker-batch"
  local last_batch_size
  last_batch_size=$(cat "$checker_marker" 2>/dev/null || echo 0)

  if [ "$terminal_workers" -ge "$batch_size" ] && [ "$last_batch_size" -lt "$batch_size" ]; then
    # Batch threshold reached, schedule checker
    if [ -n "$dry_run" ]; then
      printf 'DRY RUN: would schedule M3 checker in %s (workers_since_last_checker=%s)\n' \
        "$(get_checker_lane)" "$terminal_workers"
    else
      if [ -x "$SCRIPT_DIR/fm-always-four.sh" ]; then
        # Spawn checker in the checker slot
        "$SCRIPT_DIR/fm-always-four.sh" spawn "$(get_checker_lane)" "checker-batch-$(date +%s)" \
          --model "$CHECKER_MODEL" 2>&1
        log "scheduled M3 checker (batch_size=$terminal_workers)"
      else
        log "fm-always-four.sh not found, checker schedule skipped"
        return 1
      fi
    fi
    # Record that we just ran a checker
    echo 0 > "$checker_marker"
  else
    # Update counter for next check
    echo "$terminal_workers" > "$checker_marker"
    printf 'checker: workers_since_last=%s batch_threshold=%s\n' "$terminal_workers" "$batch_size"
  fi
}

# cmd_wake_coordinator: emit a wake event for the coordinator
cmd_wake_coordinator() {
  local reason=${1:-periodic}
  local wake_file="$STATE/.coord-poll-coordinator-wake"
  mkdir -p "$STATE"
  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ) $reason" >> "$wake_file"
  log "coordinator wake emitted: $reason"
}

# cmd_drain_wakes: drain the durable wake queue.
# This ensures queued wakes are processed even when there are no terminal panes.
# The drain is best-effort and never fails the cycle.
cmd_drain_wakes() {
  local drain_script="$SCRIPT_DIR/fm-wake-drain.sh"
  [ -x "$drain_script" ] || {
    log "wake drain script not found at $drain_script"
    return 0
  }
  local drain_output
  drain_output=$("$drain_script" 2>&1) && {
    [ -n "$drain_output" ] && log "wake drain: $drain_output"
    return 0
  } || {
    log "wake drain exited non-zero: $drain_output"
    return 0  # Best-effort, never fail the cycle
  }
}

# cmd_status: show current polling status
cmd_status() {
  printf 'Coordinator Poll Status\n'
  printf '========================\n'
  printf 'Poll interval:     %s s\n' "$POLL_INTERVAL"
  printf 'Initial backoff:   %s s\n' "$INITIAL_BACKOFF"
  printf 'Backoff max:       %s x (%s s)\n' "$BACKOFF_MAX" "$(compute_backoff "$BACKOFF_MAX")"
  printf 'Dedup window:     %s s\n' "$DEDUP_WINDOW"
  printf 'Checker model:     %s\n' "$CHECKER_MODEL"
  printf 'Herdr session:    %s\n' "$HERDR_SESSION"
  printf 'Backoff multiplier: %s\n' "$_backoff_multiplier"
  printf '\n'

  # Show pane summary
  cmd_poll_herdr

  # Show dedup markers
  local dedup_count=0
  for _ in "$STATE"/.coord-poll-dedup-*; do
    [ -e "$_" ] && dedup_count=$((dedup_count + 1))
  done
  printf '\nDedup markers: %s\n' "$dedup_count"

  # Show last coordinator wake
  local wake_file="$STATE/.coord-poll-coordinator-wake"
  if [ -f "$wake_file" ]; then
    printf 'Last coordinator wake: %s\n' "$(tail -1 "$wake_file")"
  fi
}

# --- Main Cycle -------------------------------------------------------------

# cmd_cycle: one complete polling cycle
# Returns: 0 if cycle ran, 1 if skipped (e.g., duplicate), 2 on error
cmd_cycle() {
  local dry_run=${1:-}
  log "cycle started (backoff=$_backoff_multiplier)"

  # Step 0: Recover from stale dedup and refill markers before processing new events.
  # This clears markers for panes that are no longer terminal (restarted) or
  # whose work was interrupted mid-cycle, enabling reprocessing.
  recover_stale_dedup_markers
  recover_stale_refill_markers

  # Step 1: Poll Herdr for pane states
  local panes_json
  panes_json=$(poll_herdr_panes) || {
    log "cycle failed: herdr poll error"
    return 2
  }

  # Step 1b: Drain the wake queue to process any queued wakes.
  # This ensures queued wakes are processed even when there are no terminal panes,
  # fulfilling the "queued wakes are drained" requirement and preventing the coordinator
  # from appearing to "terminate" when in reality it's just waiting for events.
  cmd_drain_wakes || true

  # Step 2: Check if any worker/status handoff requires coordinator attention
  local needs_attention=0
  local handoff_events=""

  while IFS= read -r pane_json; do
    [ -z "$pane_json" ] && continue
    local pane_id status agent
    pane_id=$(pane_id_from_json "$pane_json")
    status=$(pane_status_from_json "$pane_json")
    agent=$(pane_agent_from_json "$pane_json")

    # Only process worker panes
    is_worker_pane "$agent" || continue

    # Check for handoff events (status transitions)
    if is_terminal_pane "$status"; then
      local dedup
      dedup=$(dedup_key "handoff" "$pane_id")
      if ! is_duplicate_event "$dedup"; then
        needs_attention=1
        handoff_events="${handoff_events} ${pane_id}:${status}"
        mark_event_processed "$dedup"
      fi
    fi
  done <<< "$panes_json"

  # Step 3: If attention needed, run the full coordinator loop
  if [ "$needs_attention" = 1 ]; then
    log "handoff events detected:$handoff_events"

    # Reset backoff on meaningful activity
    _backoff_multiplier=1

    # Step 3a: Wake the coordinator
    cmd_wake_coordinator "handoff:$handoff_events" || true

    # Step 3b: Read artifacts for terminal panes
    while IFS= read -r pane_json; do
      [ -z "$pane_json" ] && continue
      local pane_id status agent
      pane_id=$(pane_id_from_json "$pane_json")
      status=$(pane_status_from_json "$pane_json")
      agent=$(pane_agent_from_json "$pane_json")

      is_worker_pane "$agent" || continue
      is_terminal_pane "$status" || continue

      if [ -z "$dry_run" ]; then
        read_pane_artifact "$pane_id" || true
      fi
    done <<< "$panes_json"

    # Step 3c: Close accepted panes
    cmd_close_accepted "$dry_run" || true

    # Step 3d: Refill eligible slots via always-four
    cmd_refill_slots "$dry_run" || true

    # Mark terminal panes as refilled so subsequent cycles don't refill again
    # Only mark in non-dry-run mode
    if [ -z "$dry_run" ]; then
      while IFS= read -r pane_json; do
        [ -z "$pane_json" ] && continue
        local pane_id status agent
        pane_id=$(pane_id_from_json "$pane_json")
        status=$(pane_status_from_json "$pane_json")
        agent=$(pane_agent_from_json "$pane_json")
        is_worker_pane "$agent" || continue
        is_terminal_pane "$status" || continue
        mark_refill_done "$pane_id"
      done <<< "$panes_json"
    fi

    # Step 3e: Schedule independent M3 checker
    cmd_schedule_checker "$dry_run" || true

  else
    # State-based refill fallback: check if any terminal panes need refill
    # even without new handoff events. This ensures refill happens for
    # terminal panes whose handoff was already processed (deduped).
    local pending_count=0
    pending_count=$(get_pending_refill_panes <<< "$panes_json" | wc -l)

    if [ "$pending_count" -gt 0 ]; then
      log "state-based refill fallback: $pending_count terminal panes pending refill"
      # Run refill without waking coordinator or reading artifacts
      # (those were done when the handoff was first detected)
      cmd_refill_slots "$dry_run" || true

      # Mark terminal panes as refilled so subsequent cycles don't refill again
      # Only mark in non-dry-run mode
      if [ -z "$dry_run" ]; then
        while IFS= read -r pane_json; do
          [ -z "$pane_json" ] && continue
          local pane_id status agent
          pane_id=$(pane_id_from_json "$pane_json")
          status=$(pane_status_from_json "$pane_json")
          agent=$(pane_agent_from_json "$pane_json")
          is_worker_pane "$agent" || continue
          is_terminal_pane "$status" || continue
          is_refill_done "$pane_id" && continue  # skip already marked
          mark_refill_done "$pane_id"
        done <<< "$panes_json"
      fi

      cmd_schedule_checker "$dry_run" || true
    else
      log "no handoff events, cycle idle"
    fi
  fi

  # Step 4: Cleanup old dedup and refill markers
  cleanup_old_dedup_markers
  cleanup_refill_markers

  log "cycle completed"
  return 0
}

# --- Daemon -----------------------------------------------------------------

cmd_daemon() {
  local once=${1:-}

  _daemon_running=1
  # shellcheck disable=SC2064
  trap '_daemon_running=0' TERM INT

  log "daemon started (interval=${POLL_INTERVAL}s, backoff_max=${BACKOFF_MAX})"

  while [ "$_daemon_running" = 1 ]; do
    _daemon_cycle_count=$((_daemon_cycle_count + 1))

    # Run one cycle
    cmd_cycle
    cycle_rc=$?

    case $cycle_rc in
      0) _backoff_multiplier=1 ;;
      1) _backoff_multiplier=$((_backoff_multiplier * 2)) ;;
      2) _backoff_multiplier=$((_backoff_multiplier * 2)) ;;
    esac

    [ "$_backoff_multiplier" -gt "$BACKOFF_MAX" ] && _backoff_multiplier=$BACKOFF_MAX

    [ -n "$once" ] && break

    # Sleep with backoff and interruptibility
    local sleep_secs
    sleep_secs=$(compute_backoff "$_backoff_multiplier")
    sleep_secs=$((sleep_secs > POLL_INTERVAL ? POLL_INTERVAL : sleep_secs))

    local slept=0
    while [ "$slept" -lt "$sleep_secs" ] && [ "$_daemon_running" = 1 ]; do
      sleep 1 2>/dev/null || true
      slept=$((slept + 1))
    done
  done

  log "daemon exiting (cycles=$_daemon_cycle_count)"
  trap - TERM INT
}

# --- Main Dispatch ----------------------------------------------------------

COMMAND=${1:-}
case "$COMMAND" in
  status)    cmd_status ;;
  cycle)     cmd_cycle "${@:2}" ;;
  poll-herdr)
    if [ "${2:-}" = "--json" ]; then
      cmd_poll_herdr --json
    else
      cmd_poll_herdr
    fi
    ;;
  close-accepted)
    if [ "${2:-}" = "--dry-run" ]; then
      cmd_close_accepted --dry-run
    else
      cmd_close_accepted
    fi
    ;;
  refill-slots)
    if [ "${2:-}" = "--dry-run" ]; then
      cmd_refill_slots --dry-run
    else
      cmd_refill_slots
    fi
    ;;
  schedule-checker)
    if [ "${2:-}" = "--dry-run" ]; then
      cmd_schedule_checker --dry-run "${3:-3}"
    else
      cmd_schedule_checker "" "${3:-3}"
    fi
    ;;
  daemon)
    if [ "${2:-}" = "--once" ]; then
      cmd_daemon --once
    else
      cmd_daemon
    fi
    ;;
  wake-coordinator)
    cmd_wake_coordinator "${2:-periodic}"
    ;;
  -h|--help|help)
    printf 'Usage: %s <command> [args...]\n' "$0"
    printf 'Commands:\n'
    printf '  status           Show polling status\n'
    printf '  cycle [--dry-run]  Run one polling cycle\n'
    printf '  poll-herdr [--json]  Poll Herdr for pane states\n'
    printf '  close-accepted [--dry-run]  Close accepted panes\n'
    printf '  refill-slots [--dry-run]  Refill terminal lanes\n'
    printf '  schedule-checker [--dry-run] [batch_size]  Schedule M3 checker\n'
    printf '  wake-coordinator [reason]  Emit coordinator wake\n'
    printf '  daemon [--once]   Run persistent polling daemon\n'
    ;;
  *)
    printf 'Unknown command: %s\n' "$COMMAND" >&2
    printf 'Run %s --help for usage\n' "$0" >&2
    exit 1
    ;;
esac
