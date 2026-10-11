#!/usr/bin/env bash
# fm-always-four.sh — Always-Four Lane Concurrency Policy (v2, cap-enforced)
#
# Design principle: keep exactly N concurrent worker lanes active (default: 4).
# Each lane is a named slot (lane-001 .. lane-004). When a lane reaches a terminal
# state, it is replaced with the next eligible queued task. The policy never kills
# active work, never oversubscribes resources, honors model routing and bounded
# attempts, and emits a coordinator wake/review event on each replacement.
#
# Key safety guarantees (v2 additions):
#   - Subagent cap enforcement: herdr-subagent-cap-check is called before EVERY
#     spawn attempt. If the cap is reached, the spawn is refused (exit 64) and
#     the coordinator is notified via a wake event.
#   - M3 lane protection: herdr-m3-guardian is consulted before closing/replacing
#     a pane. Protected M3 lanes (assigned a verification task) are never replaced.
#   - POSIX awk: next_eligible_task uses portable awk, not gawk-specific match().
#   - gbrain integration: lane state is stored in gbrain for multi-agent coordination.
#   - Wake events: coordinator is woken via fm_wake_append (signal kind).
#   - Review events: terminal classifications are sent via herdr-review-send.
#
# How it integrates with firstmate:
#   - Lanes are named task slots. Each has a state/lane-<N>.meta (if a task is
#     loaded) and state/lane-<N>.status (append-only event log).
#   - The watcher's actionable-wake path calls this script after surfacing a lane's
#     terminal state. The always-on watcher can also call it periodically.
#   - For self-contained operation (no watcher integration), run as a daemon:
#     fm-always-four.sh daemon
#   - Each invocation does ONE cycle: reads state, decides whether to spawn, acts,
#     and exits. Idempotent — safe to call from a watcher hook or cron.
#
# Safety guarantees:
#   - NEVER kill or teardown a pane that is provably working (busy pane, active
#     run-step). A settled pane is closed only after a fresh report artifact is
#     present and the task has been queued for the protected M3 review lane.
#   - NEVER spawn if herdr-subagent-cap-check refuses (exit 64).
#   - NEVER replace a protected M3 lane (herdr-m3-guardian blocks it).
#   - Never exceed the configured concurrency limit (default: 4).
#   - Never replace if the spawn would exceed the bounded attempt limit.
#   - Coordinators are notified via a written event, never a silent state change.
#   - Daemon mode handles SIGTERM/SIGINT gracefully, completing the in-flight
#     cycle before exiting.
#
# Usage:
#   fm-always-four.sh cycle [--dry-run]
#   fm-always-four.sh status
#   fm-always-four.sh spawn <lane-id> <task-id> [--harness <h>] [--model <m>] [--effort <e>]
#   fm-always-four.sh check-eligible <task-id>
#   fm-always-four.sh daemon [--once]
#
# Environment:
#   FM_ALWAYS_FOUR_TARGET              concurrency target (default: 4)
#   FM_ALWAYS_FOUR_MAX_ATTEMPTS        max spawn attempts per lane (default: 3)
#   FM_ALWAYS_FOUR_SEQUENCE            space-separated lane numbers (default: "001 002 003 004")
#   FM_ALWAYS_FOUR_POLL_SECS           poll interval in daemon mode (default: 30)
#   FM_ALWAYS_FOUR_CHECKER_SLOT        which lane is the checker slot (default: lane-004)
#   FM_ALWAYS_FOUR_WORKER_MODEL        model for worker slots (default: MiniMax-M2.7)
#   FM_ALWAYS_FOUR_CHECKER_MODEL       model for checker slot (default: GLM-5.3-Flash)
#   FM_ALWAYS_FOUR_CHECKER_LANES       comma-separated lanes for checker (default: lane-004)
#   FM_ALWAYS_FOUR_HARNESS             required concrete verified worker adapter;
#                                      unset, Pi, AGY, Gemini, and role aliases stop safely
#   FM_ALWAYS_FOUR_DRY_RUN             set to 1 for dry-run mode (default: 0)
#   FM_ALWAYS_FOUR_GBRAIN_SYNC         sync lane state to gbrain (default: 1)
#
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
CONFIG="${FM_CONFIG_OVERRIDE:-$FM_HOME/config}"

# Source supporting libraries
( . "$SCRIPT_DIR/fm-crew-state.sh" 2>/dev/null ) || true  # subshell protects against fm-crew-state.sh exit-2-on-missing-arg
. "$SCRIPT_DIR/fm-classify-lib.sh" 2>/dev/null || true
. "$SCRIPT_DIR/fm-busy-lib.sh" 2>/dev/null || true

# Source fm-wake-lib.sh for wake event emission
. "$SCRIPT_DIR/fm-wake-lib.sh" 2>/dev/null || true

# Source cap.sh for subagent cap enforcement (canonical source of truth)
CAP_SH="/root/lib/subagent-cap/cap.sh"
if [ -r "$CAP_SH" ]; then
  . "$CAP_SH"
fi

# RAW_HERDR_SENPI mode: refuse all fleet mutations when mode is active.
# shellcheck source=bin/fm-raw-herdr-senpi-lib.sh
. "$SCRIPT_DIR/fm-raw-herdr-senpi-lib.sh"

# --- Tunables ---------------------------------------------------------------
TARGET="${FM_ALWAYS_FOUR_TARGET:-4}"
MAX_ATTEMPTS="${FM_ALWAYS_FOUR_MAX_ATTEMPTS:-3}"
SEQUENCE="${FM_ALWAYS_FOUR_SEQUENCE:-001 002 003 004}"
POLL_SECS="${FM_ALWAYS_FOUR_POLL_SECS:-30}"
CHECKER_SLOT="${FM_ALWAYS_FOUR_CHECKER_SLOT:-lane-004}"
WORKER_MODEL="${FM_ALWAYS_FOUR_WORKER_MODEL:-MiniMax-M2.7}"
CHECKER_MODEL="${FM_ALWAYS_FOUR_CHECKER_MODEL:-GLM-5.3-Flash}"
# First Mate is the coordinator role, not a launch adapter.  This scheduler
# must never infer a worker harness from the controller, a pane icon, or a
# provider/model label; the operator or First Mate must pass one explicitly.
SCHEDULER_HARNESS=""
DRY_RUN="${FM_ALWAYS_FOUR_DRY_RUN:-0}"
GBRAIN_SYNC="${FM_ALWAYS_FOUR_GBRAIN_SYNC:-1}"

# Paths to canonical enforcement hooks
CAP_CHECK="/root/bin/herdr-subagent-cap-check"
CAP_REAP="/root/bin/herdr-subagent-cap-reap"
M3_GUARDIAN="/root/bin/herdr-m3-guardian"
REVIEW_SEND="/root/bin/herdr-review-send"
WAKE_LIB="$SCRIPT_DIR/fm-wake-lib.sh"

# --- Daemon state ----------------------------------------------------------
_daemon_running=0
_daemon_cycle_count=0

# Validate and bind the concrete adapter for a scheduler spawn.  Reading the
# environment at call time keeps retries deterministic without caching a stale
# provider choice at script load.  Pi, AGY, Gemini, and First Mate are display,
# provider, or role names here—not approved scheduler adapters.
scheduler_harness_guard() {
  local requested="${1:-${FM_ALWAYS_FOUR_HARNESS:-}}"
  local normalized
  normalized=$(printf '%s' "$requested" | tr '[:upper:]' '[:lower:]')

  case "$normalized" in
    ''|default|firstmate|first-mate|pi|pi-signed|agy|gemini)
      printf 'always-four: spawn BLOCKED — explicit non-Pi/non-AGY worker adapter required (got %s)\n' \
        "${requested:-<unset>}" >&2
      return 64
      ;;
    claude|codex|grok|kimi|opencode)
      SCHEDULER_HARNESS="$normalized"
      return 0
      ;;
    *)
      printf 'always-four: spawn BLOCKED — unverified worker adapter %s\n' "$requested" >&2
      return 64
      ;;
  esac
}

# --- Helpers ----------------------------------------------------------------

# Echo the lane IDs (lane-001 .. lane-004 by default)
lane_ids() {
  printf '%s\n' $SEQUENCE | tr ' ' '\n' | while read -r n; do
    printf 'lane-%s\n' "$n"
  done
}

# Terminal state verbs from status lines that warrant replacement
is_terminal_verb() {
  local verb=$1
  case "$verb" in
    done|failed|blocked) return 0 ;;
  esac
  return 1
}

# is_checker_lane: return 0 if the lane is a checker slot.
# Reads the slot config at CALL TIME (not parse time), so inline env vars work.
is_checker_lane() {
  local lane_id=$1
  # Resolve checker slot(s) at call time: prefer explicit comma-list, then single-slot env,
  # then compile-time default. This lets tests use inline VAR=value func patterns.
  local checker_lanes="${FM_ALWAYS_FOUR_CHECKER_LANES:-${FM_ALWAYS_FOUR_CHECKER_SLOT:-${CHECKER_SLOT}}}"
  local oldifs="$IFS"
  IFS=','
  for c in $checker_lanes; do
    [ "$lane_id" = "$c" ] && IFS="$oldifs" && return 0
  done
  IFS="$oldifs"
  return 1
}

# slot_model_for_lane: return the model for a given lane based on slot policy.
# Checker lanes (default: lane-004) get CHECKER_MODEL (default: GLM-5.3-Flash).
# All other slots get WORKER_MODEL (default: MiniMax-M2.7).
# This enforces the "always-four" policy: 3 workers + 1 checker.
slot_model_for_lane() {
  local lane_id=$1
  if is_checker_lane "$lane_id"; then
    printf '%s' "$CHECKER_MODEL"
  else
    printf '%s' "$WORKER_MODEL"
  fi
}

# can_replace_lane: check if a lane can be safely replaced.
# Returns 0 if replace is permitted, 1 if blocked.
# Blocks on: protected M3 lanes (herdr-m3-guardian), active working panes.
can_replace_lane() {
  local lane_id=$1
  local meta="$STATE/$lane_id.meta"
  local pane_id=""

  # Get pane_id from meta if available
  if [ -f "$meta" ]; then
    pane_id=$(grep '^herdr_pane_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)
    [ -z "$pane_id" ] && pane_id=$(grep '^window=' "$meta" 2>/dev/null | cut -d= -f2- | sed 's/.*://' || true)
  fi

  # Check M3 guardian protection if we have a pane_id
  if [ -n "$pane_id" ] && [ -x "$M3_GUARDIAN" ]; then
    if ! timeout 8s "$M3_GUARDIAN" --action check --pane-id "$pane_id" >/dev/null 2>&1; then
      printf 'always-four: cannot replace %s — pane %s is a protected M3 lane\n' \
        "$lane_id" "$pane_id" >&2
      return 1
    fi
  fi

  return 0
}

# Return 0 if the given lane is provably working (active).
# A working lane must NOT be replaced.
lane_is_active() {
  local lane_id=$1
  local meta="$STATE/$lane_id.meta"
  local status_log="$STATE/$lane_id.status"
  local target backend harness label

  [ -f "$meta" ] || return 1
  [ -f "$status_log" ] || return 1

  target=$(grep '^window=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  if [ -z "$target" ]; then
    return 1
  fi

  backend=$(grep '^backend=' "$meta" 2>/dev/null | cut -d= -f2- || echo 'tmux')

  if ! fm_backend_target_exists "$backend" "$target" "fm-$lane_id" >/dev/null 2>&1; then
    return 1
  fi

  harness=$(grep '^harness=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  label="fm-$lane_id"

  local tail40 verdict
  tail40=$(fm_backend_capture "$backend" "$target" 40 "$label" 2>/dev/null || true)
  verdict=$(fm_busy_classify "$backend" "$target" "$harness" "$lane_id" "$STATE" "$tail40")

  case "${verdict%% *}" in
    busy) return 0 ;;
  esac

  local last state
  last=$(last_status_line "$status_log" 2>/dev/null || true)
  state=$(status_line_verb "$last" 2>/dev/null || true)
  if is_terminal_verb "$state"; then
    return 1
  fi

  if [ -z "$state" ]; then
    return 1
  fi

  return 1
}

# Read lane state from status log. Fully self-contained — does NOT call
# fm-crew-state.sh as a subshell because its dispatch guard fires when invoked
# from a subshell context (BASH_SOURCE[0]==$0 in that caller's subshell).
# Classification: terminal verb -> terminal; otherwise check pane busy state.
lane_state() {
  local lane_id=$1
  local status_log="$STATE/$lane_id.status"
  local meta="$STATE/$lane_id.meta"
  local last_line last_verb verb_classified

  # No meta = no lane
  if [ ! -f "$meta" ]; then
    printf 'state: unknown · source: none'
    return
  fi
  if [ ! -f "$status_log" ]; then
    printf 'state: unknown · source: no-status-log'
    return
  fi

  # Read last non-empty status line
  last_line=$(grep -v '^[[:space:]]*$' "$status_log" 2>/dev/null | tail -1 || true)
  if [ -z "$last_line" ]; then
    printf 'state: unknown · source: empty-status-log'
    return
  fi

  # Extract verb: first word after the colon following the timestamp.
  # Format: "YYYY-MM-DDTHH:MM:SSZ: verb: detail"
  # Extract verb: split by colon, verb is field 4 in
    # "YYYY-MM-DDTHH:MM:SSZ: verb: detail" (fields: date, HH, MMSSZ, verb, ...)
    last_verb=$(printf '%s' "$last_line" | awk '{
    n = split($0, f, ":")
    for (i=1; i<=n; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", f[i])
    # Field 4 after colon-split is the verb (field 1=date, 2=HH, 3=SSZ, 4=verb)
    verb = (n >= 4) ? f[4] : f[2]
    sub(/:$/, "", verb)
    print verb
  }' 2>/dev/null | tr -d '[:space:]' || true)

  if [ -z "$last_verb" ]; then
    printf 'state: unknown · source: no-verb-in-status'
    return
  fi

  # Classify terminal verbs directly from status log
  case "$last_verb" in
    done|failed|blocked)
      printf 'state: %s · source: status-log' "$last_verb"
      return
      ;;
  esac

  # For non-terminal verbs, check pane busy state if available
  local backend target verdict tail40
  target=$(grep '^window=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  if [ -n "$target" ] && command -v fm_backend_capture >/dev/null 2>&1; then
    backend=$(grep '^backend=' "$meta" 2>/dev/null | cut -d= -f2- || echo 'tmux')
    tail40=$(fm_backend_capture "$backend" "$target" 40 "fm-$lane_id" 2>/dev/null || true)
    verdict=$(fm_busy_classify "$backend" "$target" "pi" "$lane_id" "$STATE" "$tail40" 2>/dev/null || true)
    case "${verdict%% *}" in
      busy) printf 'state: working · source: pane-busy'; return ;;
    esac
  fi

  # Classify non-terminal verb
  case "$last_verb" in
    working) verb_classified=working ;;
    idle)    verb_classified=idle ;;
    needs-decision|paused) verb_classified=parked ;;
    *)        verb_classified="$last_verb" ;;
  esac
  printf 'state: %s · source: status-log' "$verb_classified"
}


# Get the current task id loaded in a lane (from its meta), or empty.
lane_current_task() {
  local lane_id=$1
  # Check FM_STATE_OVERRIDE first so test overrides work
  local state_dir="${FM_STATE_OVERRIDE:-${STATE}}"
  local meta="$state_dir/$lane_id.meta"
  grep '^endpoint_task_id=' "$meta" 2>/dev/null | cut -d= -f2- || true
}

# Get attempt count for a lane from state/lane-<N>.attempts
lane_attempts() {
  local lane_id=$1
  local f="$STATE/$lane_id.attempts"
  [ -f "$f" ] && cat "$f" || echo 0
}

lane_inc_attempts() {
  local lane_id=$1
  local f="$STATE/$lane_id.attempts"
  local n
  n=$(lane_attempts "$lane_id")
  n=$((n + 1))
  mkdir -p "$STATE"
  printf '%s\n' "$n" > "$f"
}

lane_reset_attempts() {
  local lane_id=$1
  rm -f "$STATE/$lane_id.attempts"
}

lane_at_max_attempts() {
  local lane_id=$1
  local n
  n=$(lane_attempts "$lane_id")
  [ "$n" -ge "$MAX_ATTEMPTS" ]
}

# cleanup_lane_resources: advisory browser/process cleanup for a lane.
# Only acts on tasks that declare browser usage. Advisory-only — does not hard-kill.
cleanup_lane_resources() {
  local lane_id=$1
  # Declare override-aware dirs BEFORE using them in other local declarations.
  # (set -u: `$state_dir` in `local x="$state_dir/..."` is evaluated before assignment.)
  local state_dir="${FM_STATE_OVERRIDE:-${STATE}}"
  local data_dir="${FM_DATA_OVERRIDE:-${DATA:-${FM_HOME:-${FM_ROOT}/firstmate}/data}}"
  local meta="$state_dir/$lane_id.meta"
  local task_id
  task_id=$(lane_current_task "$lane_id" 2>/dev/null || true)
  [ -z "$task_id" ] && return 0

  local browser_markers="browser|chrome|playwright|puppeteer|frontend-testing|browser_cleanup"
  local has_browser=0
  local brief_path="$data_dir/$task_id/brief.md"
  local worktree=""

  if [ -f "$meta" ]; then
    worktree=$(grep '^worktree=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  fi
  [ -z "$worktree" ] && worktree="${FM_ROOT_OVERRIDE:-${FM_ROOT}}/projects/$task_id"

  if [ -f "$brief_path" ] && grep -qiE "$browser_markers" "$brief_path" 2>/dev/null; then
    has_browser=1
  fi

  if [ -f "$meta" ]; then
    local kind
    kind=$(grep '^kind=' "$meta" 2>/dev/null | cut -d= -f2- || true)
    case "$kind" in
      *browser*|*chrome*|*playwright*) has_browser=1 ;;
    esac
  fi

  [ "$has_browser" = 0 ] && return 0

  if ! command -v pgrep >/dev/null 2>&1; then
    printf 'always-four: browser cleanup skipped for %s (pgrep not available)\n' "$lane_id" >&2
    return 0
  fi

  local wt_escaped
  wt_escaped=$(printf '%s' "$worktree" | sed 's/[/.*^$\\[\\]]/\\&/g')

  local pre_count post_count
  pre_count=$(pgrep -c -f "chrome.*$wt_escaped" 2>/dev/null || echo 0)
  pre_count=${pre_count//[^0-9]/}
  pre_count=${pre_count:-0}

  # Advisory only — no hard-kill here
  post_count=$(pgrep -c -f "chrome.*$wt_escaped" 2>/dev/null || echo 0)
  post_count=${post_count//[^0-9]/}
  post_count=${post_count:-0}

  if [ "$post_count" -gt "$pre_count" ]; then
    printf 'always-four: warning: browser process count increased from %s to %s for %s\n' \
      "$pre_count" "$post_count" "$lane_id" >&2
  else
    printf 'always-four: browser cleanup: %s -> %s processes for %s\n' \
      "$pre_count" "$post_count" "$lane_id"
  fi

  return 0
}

record_rollback_evidence() {
  local lane_id=$1
  local task_id=${2:-<unknown>}
  local reason=${3:-unknown}
  local context="${4:-}"
  # Use FM_STATE_OVERRIDE if set (for testability); declare before use for set -u safety
  local state_dir="${FM_STATE_OVERRIDE:-${STATE}}"
  local rollback_file="$state_dir/$lane_id.rollback"
  local status_file="$state_dir/$lane_id.status"
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  mkdir -p "$state_dir"
  cat >> "$rollback_file" <<EOF
[$timestamp] rollback: lane=$lane_id task=$task_id reason=$reason $context
EOF

  printf '%s: always-four[rollback]: lane=%s task=%s reason=%s %s\n' \
    "$timestamp" "$lane_id" "$task_id" "$reason" "$context" >> "$status_file"
}

count_active_lanes() {
  local count=0
  for lane_id in $(lane_ids); do
    if lane_is_active "$lane_id"; then
      count=$((count + 1))
    fi
  done
  printf '%s\n' "$count"
}

# Count live worker processes from authoritative task metadata.  Real Herdr
# lanes are keyed by task ID (core-next-v3.meta, etc.), not lane-001.meta; the
  # old slot-only census therefore reported active=0 while a worker was visibly
# working.  Checker/controller models are excluded from the worker target.
count_active_worker_tasks() {
  local count=0 meta id model verdict
  for meta in "$STATE"/*.meta; do
    [ -f "$meta" ] || continue
    model=$(grep '^model=' "$meta" 2>/dev/null | cut -d= -f2- || true)
    case "$model" in
      minimax-m2.7|MiniMax-M2.7|minimax-m2.7-highspeed) ;;
      *) continue ;;
    esac
    id=$(grep '^endpoint_task_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)
    [ -n "$id" ] || continue
    verdict=$(fm_busy_classify_meta "$meta" "$id" "$STATE" 2>/dev/null || true)
    [ "${verdict%% *}" = busy ] && count=$((count + 1))
  done
  # Preserve compatibility with isolated test homes that only create slot
  # metadata and do not have endpoint_task_id records.
  [ "$count" -gt 0 ] || count=$(count_active_lanes)
  printf '%s\n' "$count"
}

count_terminal_lanes() {
  local count=0
  for lane_id in $(lane_ids); do
    local task
    task=$(lane_current_task "$lane_id")
    [ -z "$task" ] && continue
    local state_line crew_state verb
    state_line=$(lane_state "$lane_id")
    crew_state=${state_line%% · *}
    crew_state=${crew_state#state: }
    verb=$(status_line_verb "$crew_state" 2>/dev/null || true)
    if is_terminal_verb "$verb"; then
      count=$((count + 1))
    fi
  done
  printf '%s\n' "$count"
}

# next_eligible_task: POSIX-compatible task selection from backlog.md.
# Uses only POSIX awk features (no gawk-specific 3-arg match()).
# Returns the first queued, unblocked, non-in-flight task id.
next_eligible_task() {
  local backlog="$DATA/backlog.md"
  [ -f "$backlog" ] || { echo ''; return; }

  # Build in-flight set from lane metas
  local in_flight_cmd="grep -l 'endpoint_task_id=' $STATE/lane-*.meta 2>/dev/null | "
  in_flight_cmd="${in_flight_cmd}while read f; do "
  in_flight_cmd="${in_flight_cmd}grep '^endpoint_task_id=' \"\$f\" 2>/dev/null | "
  in_flight_cmd="${in_flight_cmd}cut -d= -f2; done"

  # POSIX awk: scan backlog for first queued item without blocked-by.
  # Scans for lines matching: "  - [ ] task-id - title"
  # Skips lines containing "blocked-by:" to avoid picking blocked tasks.
  # Exits after first match.
  awk '
    BEGIN {
      section = ""
      # Populate in_flight from shell-generated temp file
      while ((getline line < ("'"$STATE"'/.always-four.inflight.tmp")) > 0) {
        in_flight[line] = 1
      }
      close("'"$STATE"'/.always-four.inflight.tmp")
    }
    /^##[[:space:]]+/ {
      section = $0
      sub(/^##[[:space:]]+/, "", section)
      sub(/[[:space:]]+$/, "", section)
      next
    }
    section == "Queued" && /^[[:space:]]*-[[:space:]]+\[[[:space:]]\][[:space:]]/ {
      # Parse task id: "- [ ] task-id - title"
      # Skip if contains blocked-by
      if (index($0, "blocked-by:") > 0) next

      # Extract task id: it is the first non-flag word after "- [ ]"
      rest = $0
      sub(/^[[:space:]]*-[[:space:]]+\[[[:space:]]\][[:space:]]*/, "", rest)
      # rest now starts with the task id
      # Task id ends at the first space after it (before " - ")
      n = split(rest, parts, /[[:space:]]+-+[[:space:]]+/)
      if (n >= 1) {
        task_id = parts[1]
        # Remove any trailing spaces
        sub(/[[:space:]]+$/, "", task_id)
        if (task_id != "" && !(task_id in in_flight)) {
          print task_id
          exit
        }
      }
    }
  ' "$backlog" 2>/dev/null || true
}

# build_inflight_tmp: write current in-flight tasks to a temp file for awk.
build_inflight_tmp() {
  local tmp="$STATE/.always-four.inflight.tmp"
  : > "$tmp"
  # Task metadata is keyed by task ID (not scheduler slot), so lane-only
  # scanning misses real in-flight work and allows duplicate respawns.  Include
  # every authoritative meta record, then retain slot fallback for test homes.
  local meta task
  for meta in "$STATE"/*.meta; do
    [ -f "$meta" ] || continue
    task=$(grep '^endpoint_task_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)
    [ -n "$task" ] && printf '%s\n' "$task"
  done
  for lane_id in $(lane_ids); do
    task=$(lane_current_task "$lane_id")
    [ -n "$task" ] && printf '%s\n' "$task"
  done >> "$tmp"
}

backlog_task_to_project() {
  local task_id=$1
  local backlog="$DATA/backlog.md"
  [ -f "$backlog" ] || { echo "projects/$task_id"; return; }

  # POSIX grep to find the task in Queued section
  local repo
  repo=$(awk -v id="$task_id" '
    BEGIN { section = "" }
    /^##[[:space:]]+/ {
      section = $0
      sub(/^##[[:space:]]+/, "", section)
      sub(/[[:space:]]+$/, "", section)
      next
    }
    section == "Queued" && index($0, id) > 0 {
      if (match($0, /repo:[[:space:]]*[^)]*/)) {
        repo = substr($0, RSTART, RLENGTH)
        sub(/^repo:[[:space:]]*/, "", repo)
        sub(/[[:space:]]+$/, "", repo)
        print repo
        exit
      }
    }
  ' "$backlog" 2>/dev/null || true)

  [ -n "$repo" ] && echo "$repo" || echo "projects/$task_id"
}

# emit_coordinator_wake: write a wake event to the durable queue AND status log.
# kind: replacement | stall | overcapacity | cap-blocked | m3-protected
emit_coordinator_wake() {
  local kind=$1
  local lane_id=$2
  local task_id=${3:-}
  local detail="$4"

  local msg="always-four[$kind]: lane=$lane_id"
  [ -n "$task_id" ] && msg="$msg task=$task_id"
  [ -n "$detail" ] && msg="$msg $detail"

  mkdir -p "$STATE"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  printf '%s: %s\n' "$ts" "$msg" >> "$STATE/$lane_id.status"

  # Emit a durable wake signal via fm_wake_append if available.
  # Fallback: write to the general wake queue file directly.
  local wake_key="always-four.$kind.$lane_id.${task_id:-none}"
  if [ -f "$WAKE_LIB" ]; then
    fm_wake_append signal "$wake_key" "$msg" 2>/dev/null || true
  else
    # Fallback: append to the global wake queue
    local q="$STATE/.wake-queue"
    local qlock="$STATE/.wake-queue.lock"
    fm_lock_acquire_wait "$qlock" 2>/dev/null || true
    printf '%s\t%d\tsignal\t%s\t%s\n' \
      "$(date +%s)" "0" "$wake_key" "$msg" >> "$q" 2>/dev/null || true
    fm_lock_release "$qlock" 2>/dev/null || true
  fi

  return 0
}

# emit_review_event: send a terminal classification to the coordinator via
# herdr-review-send for lanes that reached a terminal state.
# classification: ACCEPTED | REVISION_REQUIRED | TERMINAL
emit_review_event() {
  local pane_id=$1
  local classification=$2
  local detail=$3

  [ -z "$pane_id" ] && return 0
  [ -z "$classification" ] && return 0

  if [ -x "$REVIEW_SEND" ]; then
    "$REVIEW_SEND" "$pane_id" "$classification — $detail" 2>/dev/null || true
  fi
}

# sync_gbrain: write current lane state to gbrain for multi-agent coordination.
sync_gbrain() {
  [ "$GBRAIN_SYNC" != "1" ] && return 0
  command -v gbrain >/dev/null 2>&1 || return 0

  local ts state_json=""
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Build JSON state
  state_json="## Updated: $ts\n\n"
  state_json="${state_json}## Active Lanes\n"
  state_json="${state_json}| lane | task | state | model | attempts |\n"
  state_json="${state_json}|------|------|-------|-------|----------|\n"

  for lane_id in $(lane_ids); do
    local task state model attempts pane
    task=$(lane_current_task "$lane_id")
    state=$(lane_state "$lane_id")
    state=${state%% · *}
    state=${state#state: }
    model=$(slot_model_for_lane "$lane_id")
    attempts=$(lane_attempts "$lane_id")
    pane=$(grep '^herdr_pane_id=' "$STATE/$lane_id.meta" 2>/dev/null | cut -d= -f2- || echo '—')

    state_json="${state_json}| $lane_id | ${task:-<none>} | ${state:-unknown} | $model | ${attempts}/$MAX_ATTEMPTS |\n"
  done

  echo -e "$state_json" | gbrain put always-four-scheduler-state 2>/dev/null || true
}

# check_cap: verify the subagent cap allows spawning. Returns 0 if OK, 1 if blocked.
check_cap() {
  if [ ! -x "$CAP_CHECK" ]; then
    # Fallback: direct cap.sh check
    if [ -r "$CAP_SH" ]; then
      . "$CAP_SH"
      subagent_cap_can_spawn >/dev/null 2>&1 && return 0 || return 1
    fi
    return 0  # If no cap mechanism available, allow
  fi

  if ! timeout 12s "$CAP_CHECK" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# A worker may be retired only after its current spawn produced a report. This
# prevents the old "idle means disposable" bug: settled-without-deliverable
# lanes remain visible for M3 to diagnose instead of being blindly closed.
lane_report_ready() {
  local lane_id=$1 task meta report meta_mtime report_mtime
  task=$(lane_current_task "$lane_id")
  [ -n "$task" ] || return 1
  meta="$STATE/$lane_id.meta"
  report="$DATA/$task/report.md"
  [ -f "$meta" ] && [ -s "$report" ] || return 1
  meta_mtime=$(stat -c %Y "$meta" 2>/dev/null || echo 0)
  report_mtime=$(stat -c %Y "$report" 2>/dev/null || echo 0)
  [ "$report_mtime" -ge "$meta_mtime" ]
}

review_marker_path() {
  printf '%s/%s.review-pending' "$STATE" "$1"
}

queue_lane_for_m3() {
  local lane_id=$1 task=$2 pane=${3:-} marker ts
  marker=$(review_marker_path "$lane_id")
  [ -f "$marker" ] && return 0
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  mkdir -p "$STATE"
  {
    printf 'task=%s\n' "$task"
    printf 'pane=%s\n' "$pane"
    printf 'queued_at=%s\n' "$ts"
    printf 'reason=report-ready\n'
  } > "${marker}.tmp"
  mv -f "${marker}.tmp" "$marker"
  emit_review_event "$pane" TERMINAL "report queued for M3 review task=$task"
  emit_coordinator_wake m3-review-queued "$lane_id" "$task" "fresh report present; pane eligible for close"
}

# Close only managed panes explicitly queued for M3. Global cap reaping remains
# available for other lifecycle tooling, but this scheduler must not close
# unrelated idle Herdr panes (or a pane whose report is missing).
reap_stale() {
  local lane_id marker pane lifecycle close_bin
  for lane_id in $(lane_ids); do
    marker=$(review_marker_path "$lane_id")
    [ -f "$marker" ] || continue
    pane=$(grep '^pane=' "$marker" 2>/dev/null | cut -d= -f2- || true)
    [ -n "$pane" ] || continue
    lifecycle=$(subagent_cap_pane_state "$pane" 2>/dev/null || true)
    case "$lifecycle" in
      idle|done) ;;
      *) continue ;;
    esac
    close_bin=$(command -v herdr-pane-close-safe 2>/dev/null || printf '%s' /root/bin/herdr-pane-close-safe)
    if timeout 12s "$close_bin" "$pane" >/dev/null 2>&1; then
      printf '%s\n' "closed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$marker"
      emit_coordinator_wake pane-closed "$lane_id" "$(lane_current_task "$lane_id")" "report queued for M3; settled pane closed"
    fi
  done
}

# --- Commands ----------------------------------------------------------------

cmd_status() {
  printf 'Always-Four Policy Status\n'
  printf '=========================\n'
  printf 'Target concurrency: %s\n' "$TARGET"
  printf 'Max attempts/lane: %s\n' "$MAX_ATTEMPTS"
  printf 'Poll interval:     %s s\n' "$POLL_SECS"
  printf 'Checker slot:      %s\n' "${FM_ALWAYS_FOUR_CHECKER_LANES:-$CHECKER_SLOT}"
  printf 'Worker model:      %s\n' "$WORKER_MODEL"
  printf 'Checker model:     %s\n' "$CHECKER_MODEL"
  printf 'Scheduler harness: %s\n' "${FM_ALWAYS_FOUR_HARNESS:-<unset>}"
  printf 'Dry run:           %s\n' "$DRY_RUN"
  printf 'GBrain sync:       %s\n' "$GBRAIN_SYNC"
  printf '%s\n' "$(fm_raw_herdr_senpi_report 2>/dev/null || echo 'RAW_HERDR_SENPI: unknown (library not sourced)')"
  printf '\n'

  # Cap status
  if [ -r "$CAP_SH" ]; then
    . "$CAP_SH"
    local sub total
    sub=$(subagent_cap_count_open_subagent 2>/dev/null || echo "?")
    total=$(subagent_cap_count_open_total 2>/dev/null || echo "?")
    printf 'Subagent cap: open_subagent=%s/%s open_total=%s/%s\n' \
      "$sub" "$MAX_SUBAGENT_PANES" "$total" "$MAX_TOTAL_PANES"
    printf '\n'
  fi

  local total_active=0
  local total_terminal=0
  local total_empty=0

  for lane_id in $(lane_ids); do
    local meta="$STATE/$lane_id.meta"
    local task attempts state_line verb detail model pane m3_protected=""

    task=$(lane_current_task "$lane_id")
    attempts=$(lane_attempts "$lane_id")

    if [ -z "$task" ]; then
      state_line="empty"
      verb=""
      detail=""
      model=$(slot_model_for_lane "$lane_id")
      total_empty=$((total_empty + 1))
    else
      state_line=$(lane_state "$lane_id")
      verb=$(echo "$state_line" | sed -n 's/.*state: \([^ ]*\).*/\1/p' | head -1 || true)
      detail=${state_line#*· }
      model=$(grep '^model=' "$meta" 2>/dev/null | cut -d= -f2- || slot_model_for_lane "$lane_id")
      pane=$(grep '^herdr_pane_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)

      if [ -n "$pane" ] && [ -x "$M3_GUARDIAN" ]; then
        if ! timeout 4s "$M3_GUARDIAN" --action check --pane-id "$pane" >/dev/null 2>&1; then
          m3_protected=" [M3-PROTECTED]"
        fi
      fi

      if lane_is_active "$lane_id"; then
        total_active=$((total_active + 1))
      elif is_terminal_verb "$verb"; then
        total_terminal=$((total_terminal + 1))
      else
        total_active=$((total_active + 1))
      fi
    fi

    printf '%s | task=%-28s | state=%-14s | model=%-12s | attempts=%s%s\n' \
      "$lane_id" "${task:-<none>}" "${verb:-empty}" "${model:-<slot policy>}" \
      "$attempts" "$m3_protected"
  done

  printf '\nActive: %s  Terminal: %s  Empty: %s  Target: %s\n' \
    "$total_active" "$total_terminal" "$total_empty" "$TARGET"

  local eligible
  eligible=$(next_eligible_task)
  printf 'Next eligible task: %s\n' "${eligible:-<none>}"
}

cmd_check_eligible() {
  local task_id=$1
  local backlog="$DATA/backlog.md"

  if grep -qP "^\s*-\s*\[\s*\]\s+\Q${task_id}\E\s" "$backlog" 2>/dev/null; then
    printf '%s: QUEUED\n' "$task_id"
  else
    printf '%s: NOT QUEUED or NOT FOUND\n' "$task_id"
  fi
}

cmd_spawn() {
  fm_raw_herdr_senpi_refuse_mutate "fm-always-four.sh spawn"
  local lane_id=$2
  local task_id=$3
  shift 3
  local harness_arg="" model_arg="" effort_arg=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --harness) harness_arg=$2; shift 2 ;;
      --model) model_arg=$2; shift 2 ;;
      --effort) effort_arg=$2; shift 2 ;;
      *) echo "unknown arg: $1" >&2; return 1 ;;
    esac
  done

  # Validate before pane replacement, cap reaping, or queue movement: there is
  # no safe implicit fallback for a missing or ambiguous worker adapter.
  if ! scheduler_harness_guard "${harness_arg:-}"; then
    return 64
  fi

  # Check M3 protection before spawning into this lane slot
  if ! can_replace_lane "$lane_id"; then
    emit_coordinator_wake m3-protected "$lane_id" "$task_id" "protected lane — replacement blocked"
    return 1
  fi

  # CRITICAL: Reap stale panes and check subagent cap BEFORE spawning
  reap_stale
  if ! check_cap; then
    printf 'always-four: spawn BLOCKED — subagent cap reached (cap-check refused)\n' >&2
    emit_coordinator_wake cap-blocked "$lane_id" "$task_id" "cap-reached"
    record_rollback_evidence "$lane_id" "$task_id" "cap-blocked" "spawn refused by subagent-cap"
    return 64
  fi

  local project
  project=$(backlog_task_to_project "$task_id" 2>/dev/null || true)
  [ -z "$project" ] && project="projects/$task_id"

  if [ -z "$model_arg" ]; then
    model_arg=$(slot_model_for_lane "$lane_id")
  fi

  # Pass the explicitly guarded adapter so fm-spawn cannot silently resolve a
  # controller or pane-default harness for this worker/checker lane.
  local spawn_args=("$task_id" "$project" --harness "$SCHEDULER_HARNESS")
  [ -n "$harness_arg" ] && spawn_args+=(--harness "$harness_arg")
  [ -n "$model_arg" ] && spawn_args+=(--model "$model_arg")
  [ -n "$effort_arg" ] && spawn_args+=(--effort "$effort_arg")

  "$SCRIPT_DIR/fm-spawn.sh" "${spawn_args[@]}" && spawn_rc=$? || spawn_rc=$?

  if [ "${spawn_rc:-0}" -eq 0 ]; then
    lane_reset_attempts "$lane_id"
    emit_coordinator_wake replacement "$lane_id" "$task_id" "spawned ok"
    sync_gbrain
    printf 'always-four: spawned %s in %s\n' "$task_id" "$lane_id"
  else
    lane_inc_attempts "$lane_id"
    record_rollback_evidence "$lane_id" "$task_id" "spawn-failed" "rc=$spawn_rc model=$model_arg"
    emit_coordinator_wake replacement "$lane_id" "$task_id" "spawn FAILED rc=$spawn_rc"
    sync_gbrain
    printf 'always-four: spawn %s in %s FAILED (rc=%s, attempts=%s)\n' \
      "$task_id" "$lane_id" "$spawn_rc" "$(lane_attempts "$lane_id")"
  fi

  return 0
}

# One policy cycle: check the gap, fill it.
cmd_cycle() {
  fm_raw_herdr_senpi_refuse_mutate "fm-always-four.sh cycle"
  local dry_run=${1:-}
  [ "$DRY_RUN" = "1" ] && dry_run=1
  local changes=0

  # Fire the independent M3 review asynchronously when settled evidence
  # changes.  This is deliberately before worker refill and never waits for
  # the checker; the protected lane owns its own bounded review turn.
  "$SCRIPT_DIR/fm-m3-review-loop.sh" >/dev/null 2>&1 || true

  # Step 0: Build in-flight task set for awk parser
  build_inflight_tmp

  # Step 1: Count active lanes
  local active_count
  active_count=$(count_active_worker_tasks)

  # Step 1b: Fill genuinely empty managed slots immediately.  A checker/M3
  # review may be running in parallel, but it is not a reason to leave worker
  # capacity idle.  This also makes a fresh daemon start self-seeding instead
  # of waiting for a terminal-lane event that can never arrive.
  for lane_id in $(lane_ids); do
    [ "$active_count" -ge "$TARGET" ] && break
    [ -n "$(lane_current_task "$lane_id")" ] && continue
    eligible=$(next_eligible_task)
    [ -z "$eligible" ] && break
    if [ -z "$dry_run" ]; then
      if cmd_spawn spawn "$lane_id" "$eligible"; then
        active_count=$((active_count + 1))
        changes=$((changes + 1))
      fi
    else
      printf 'always-four [DRY RUN]: would fill empty %s with %s\n' "$lane_id" "$eligible"
    fi
  done

  # Step 2: Find terminal lanes that need replacement
  local -A replace_lanes
  for lane_id in $(lane_ids); do
    local task state_line verb
    task=$(lane_current_task "$lane_id")
    [ -z "$task" ] && continue

    state_line=$(lane_state "$lane_id")
    verb=$(echo "$state_line" | sed -n 's/.*state: \([^ ]*\).*/\1/p' | head -1 || true)
    [ -z "$verb" ] && verb=$(status_line_verb "$state_line" 2>/dev/null || true)

    if is_terminal_verb "$verb"; then
      # Check if this lane can be replaced (M3 protection)
      if ! can_replace_lane "$lane_id"; then
        emit_coordinator_wake m3-protected "$lane_id" "$task" "protected — not replacing"
        continue
      fi
      replace_lanes[$lane_id]=$task
      cleanup_lane_resources "$lane_id"
    fi
  done

  local -A spawns_done

  # Step 3: For each terminal lane, replace if we have eligible tasks
  for lane_id in $(lane_ids); do
    [ -z "${replace_lanes[$lane_id]:-}" ] && continue

    # CRITICAL: Reap stale panes before counting capacity
    reap_stale

    # Check subagent cap — if at capacity, don't spawn
    if ! check_cap; then
      printf 'always-four: cycle BLOCKED — subagent cap reached\n' >&2
      emit_coordinator_wake cap-blocked "$lane_id" "" "cap-reached at cycle start"
      continue
    fi

    # The global cap check above is the resource-safety gate.  The scheduler
    # target is deliberately scoped to its managed worker slots, not the raw
    # Herdr pane count: the controller and protected M3 reviewer are separate
    # lanes and must not prevent an idle/terminal worker slot being refilled.
    # This keeps review asynchronous: dispatch M3, then immediately refill
    # eligible worker slots while M3 verifies in parallel.
    . "$CAP_SH" 2>/dev/null || true
    local managed_active
    managed_active=$(count_active_worker_tasks)

    if [ "$managed_active" -ge "$TARGET" ]; then
      emit_coordinator_wake overcapacity "$lane_id" "" "at managed_capacity=TARGET(${TARGET}) active_worker_lanes(${managed_active})"
      continue
    fi

    # Find next eligible task
    local eligible
    eligible=$(next_eligible_task)

    if [ -z "$eligible" ]; then
      emit_coordinator_wake stall "$lane_id" "" "no eligible queued tasks"
      continue
    fi

    # Check attempt limit
    if lane_at_max_attempts "$lane_id"; then
      emit_coordinator_wake stall "$lane_id" "" "max attempts reached ($(lane_attempts "$lane_id")/$MAX_ATTEMPTS)"
      continue
    fi

    # Replace!
    if [ -z "$dry_run" ]; then
      # Require the same explicit adapter before moving the queued task.  This
      # prevents a red-herring adapter failure from orphaning queue ownership.
      if ! scheduler_harness_guard; then
        emit_coordinator_wake route-blocked "$lane_id" "$eligible" "explicit worker adapter required"
        continue
      fi

      # Update backlog state
      if command -v tasks-axi >/dev/null 2>&1; then
        tasks-axi mv "$eligible" --file "$DATA/backlog.md" --to-section "In flight" 2>/dev/null || true
      fi

      local slot_model
      slot_model=$(slot_model_for_lane "$lane_id")

      # SECOND cap check immediately before spawn (double-check after backlog update)
      reap_stale
      if ! check_cap; then
        printf 'always-four: replacement spawn BLOCKED — subagent cap reached (pre-spawn check)\n' >&2
        emit_coordinator_wake cap-blocked "$lane_id" "$eligible" "cap-reached pre-spawn"
        continue
      fi

      # Keep replacement lanes on the explicitly guarded adapter; never inherit
      # the controller harness while refilling a terminal slot.
      local spawn_args=("$eligible" "projects/$eligible" --harness "$SCHEDULER_HARNESS" --model "$slot_model")
      "$SCRIPT_DIR/fm-spawn.sh" "${spawn_args[@]}" && spawn_rc=$? || spawn_rc=$?

      if [ "${spawn_rc:-0}" -eq 0 ]; then
        lane_reset_attempts "$lane_id"
        emit_coordinator_wake replacement "$lane_id" "$eligible" "spawned ok model=$slot_model"
        sync_gbrain
        printf 'always-four: replaced %s with %s in %s (model=%s)\n' \
          "${replace_lanes[$lane_id]}" "$eligible" "$lane_id" "$slot_model"
      else
        lane_inc_attempts "$lane_id"
        record_rollback_evidence "$lane_id" "$eligible" "replacement-spawn-failed" \
          "rc=$spawn_rc model=$slot_model"
        emit_coordinator_wake replacement "$lane_id" "$eligible" \
          "spawn FAILED rc=$spawn_rc model=$slot_model"
        sync_gbrain
        printf 'always-four: replacement spawn of %s in %s FAILED (rc=%s, model=%s, attempts=%s/%s)\n' \
          "$eligible" "$lane_id" "$spawn_rc" "$slot_model" "$(lane_attempts "$lane_id")" "$MAX_ATTEMPTS"
      fi
    else
      printf 'always-four [DRY RUN]: would replace %s with %s in %s\n' \
        "${replace_lanes[$lane_id]}" "$eligible" "$lane_id"
    fi

    changes=$((changes + 1))
  done

  if [ "$changes" -eq 0 ] && [ -z "$dry_run" ]; then
    # Guard: ${#replace_lanes[@]} triggers set -u "unbound" if array is uninitialized.
    # Use ${arr[@]+${#arr[@]}} so it expands to 0 when unset.
    printf 'always-four: no replacement needed (active=%s, terminal=%s)\n' \
      "$(count_active_worker_tasks)" "${replace_lanes[@]+${#replace_lanes[@]}}"
  fi
}

cmd_daemon() {
  fm_raw_herdr_senpi_refuse_mutate "fm-always-four.sh daemon"
  local once=${1:-}

  _daemon_running=1
  trap '_daemon_running=0' TERM INT

  printf 'always-four: daemon started (target=%s, poll=%ss, checker_slot=%s, worker_model=%s, checker_model=%s)\n' \
    "$TARGET" "$POLL_SECS" "${FM_ALWAYS_FOUR_CHECKER_LANES:-$CHECKER_SLOT}" \
    "$WORKER_MODEL" "$CHECKER_MODEL"

  while [ "$_daemon_running" = 1 ]; do
    _daemon_cycle_count=$((_daemon_cycle_count + 1))
    printf 'always-four: cycle %s started at %s\n' \
      "$_daemon_cycle_count" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    cmd_cycle

    printf 'always-four: cycle %s completed at %s\n' \
      "$_daemon_cycle_count" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    [ -n "$once" ] && break

    sleep "$POLL_SECS" 2>/dev/null || true
  done

  printf 'always-four: daemon exiting (cycles completed=%s)\n' "$_daemon_cycle_count"
  trap - TERM INT
}

# --- Main dispatch -----------------------------------------------------------
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  COMMAND=${1:-}
  case "$COMMAND" in
  status)       cmd_status "${@:2}" ;;
  cycle)        cmd_cycle "${@:2}" ;;
  check-eligible)
    task_id=${2:-}
    [ -z "$task_id" ] && { echo "usage: $0 check-eligible <task-id>" >&2; exit 1; }
    cmd_check_eligible "$task_id"
    ;;
  spawn)
    lane_id=${2:-}
    task_id=${3:-}
    [ -z "$lane_id" ] || [ -z "$task_id" ] && { echo "usage: $0 spawn <lane-id> <task-id> [--harness ...] [--model ...] [--effort ...]" >&2; exit 1; }
    cmd_spawn "$@"
    ;;
  daemon)
    shift
    if [ "${1:-}" = "--once" ]; then
      cmd_daemon "--once"
    else
      cmd_daemon
    fi
    ;;
  -h|--help|help) echo "Usage: $0 {status|cycle|check-eligible <id>|spawn <lane> <task-id>|daemon [--once]}" ;;
  *) echo "Usage: $0 {status|cycle|check-eligible <id>|spawn <lane> <task-id>|daemon [--once]}" >&2; exit 1 ;;
  esac
fi
