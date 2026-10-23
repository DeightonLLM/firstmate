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
#   FM_ALWAYS_FOUR_MINT_LANE_KEY       mint a compliant lane key from the
#                                      backlog planning id (default: 1). Set to 0
#                                      to hand the planning id to fm-spawn.sh
#                                      unchanged (the pre-2026-10-22 behaviour,
#                                      which every backlog dispatch refused with
#                                      exit 5).
#   FM_ALWAYS_FOUR_SCAFFOLD_BRIEF      scaffold a brief from the backlog row
#                                      when a queued task has none (default: 1).
#                                      Set to 0 to dispatch only work whose brief
#                                      already exists.
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
# fm-backend.sh owns the backend/meta primitives (fm_backend_of_meta,
# fm_backend_target_of_meta, fm_backend_target_exists, fm_backend_capture,
# fm_backend_busy_state, fm_meta_get).  It MUST be sourced at TOP LEVEL: a
# subshell's function definitions never escape into the caller, so sourcing it
# inside a subshell left every backend helper undefined here - the measured
# consequence was fm_busy_classify_meta answering "unknown no-target" for
# every meta and fm_backend_target_exists failing as "command not found", which
# killed the lane liveness gate.  Sourced after fm-classify-lib.sh so the
# classification helpers exist first.
. "$SCRIPT_DIR/fm-backend.sh" 2>/dev/null || true
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
# minimax-code IS an approved scheduler adapter: bin/fm-harness.sh lists it in
# its verified set and bin/fm-spawn.sh builds a real mcode launch command for
# it. It is accepted on that evidence alone. The Pi/AGY/Gemini/First Mate
# refusals below are unchanged and stay refusals.
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
    claude|codex|grok|kimi|opencode|minimax-code)
      SCHEDULER_HARNESS="$normalized"
      return 0
      ;;
    *)
      printf 'always-four: spawn BLOCKED — unverified worker adapter %s\n' "$requested" >&2
      return 64
      ;;
  esac
}

# --- Lane key minting -------------------------------------------------------
# The backlog's planning ids are NOT lane keys. bin/fm-spawn.sh treats its
# first positional argument as the lane key and enforces the canonical
# <harness>-<model>-<host>-<task> shape through bin/fm-lane-naming-check.sh
# (exit 5). A planning id such as
# "core-gate-twin-parity-absent-member-bypass-20261021" begins with a project
# segment, so EVERY dispatch of a backlog task was refused with rc=5 and the
# lane slot stayed empty.
#
# The backlog rows are shared with other lanes and are referenced from outside
# this home, so they are NOT rewritten. The scheduler MINTS a compliant lane
# key from the planning id instead and keeps the planning id as the backlog
# identity. The minted key is the LANE identity.
#
# Minting rule:  <harness>-<model>-<host>-<task>
#   harness  the configured scheduler harness in its lane-key spelling
#            (minimax-code -> mcode; see the naming owner's harness tokens)
#   model    the canonical alias of the lane's configured model id, read from
#            the naming owner's OWN alias table so the vocabulary stays in one
#            place (minimax/MiniMax-M3.1-Flash -> m3.1f)
#   host     this machine's host token (the hostname label; brandon-compute ->
#            brandon)
#   task     the planning id, sanitized to the lane-task pattern and shortened
#            to the 64-character task-id cap, with a deterministic hash suffix
#            so two long planning ids can never share one lane key
#
# The minted key is used only when the naming owner accepts it, so this file
# never carries a second copy of the naming rules.
MINT_LANE_KEY="${FM_ALWAYS_FOUR_MINT_LANE_KEY:-1}"

# Scaffold a brief for a queued row that has none, so a settled lane can take
# genuinely new work. Set to 0 to dispatch only work whose brief already
# exists.
SCAFFOLD_BRIEF="${FM_ALWAYS_FOUR_SCAFFOLD_BRIEF:-1}"

# lane_key_harness_segment: the lane-key harness token for a harness name.
lane_key_harness_segment() {
  local harness=${1:-}
  case "$harness" in
    minimax-code) printf 'mcode' ;;
    ''|*[!A-Za-z0-9.-]*) printf '' ;;
    *) printf '%s' "$harness" ;;
  esac
}

# lane_key_model_segment <model-id>: the canonical model alias for a model id,
# read from the naming owner's own alias table. Fails when the id names no
# alias the owner knows (a retired family included: the owner refuses a
# retired alias for a NEW lane key, and this script must not second-guess it).
lane_key_model_segment() {
  local model_id=${1:-}
  [ -n "$model_id" ] || return 1
  local alias identifier
  while IFS=$'\t' read -r alias identifier; do
    [ -n "$alias" ] || continue
    if [ "$identifier" = "$model_id" ]; then
      printf '%s' "$alias"
      return 0
    fi
  done < <("$SCRIPT_DIR/fm-todo-prefix-check.sh" --alias-table 2>/dev/null)
  return 1
}

# lane_key_host_segment: this machine's host token. The fleet's host tokens
# are the first label of the machine name (brandon-compute -> brandon,
# hd2stack -> hd2stack, controller -> controller).
lane_key_host_segment() {
  local host
  host=$(hostname 2>/dev/null || true)
  [ -n "$host" ] || host=${HOSTNAME:-}
  [ -n "$host" ] || return 1
  host=$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')
  host=${host%%.*}
  host=${host%%-*}
  host=$(printf '%s' "$host" \
    | sed 's/[^a-z0-9.-]\{1,\}/-/g; s/-\{2,\}/-/g; s/^[.-]*//; s/[.-]*$//')
  [ -n "$host" ] || return 1
  printf '%s' "$host"
}

# lane_key_task_segment <planning-id> <budget>: the lane-key task segment.
lane_key_task_segment() {
  local planning_id=$1 budget=$2
  [ -n "$planning_id" ] || return 1
  local slug
  slug=$(printf '%s' "$planning_id" | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9.-]\{1,\}/-/g; s/-\{2,\}/-/g; s/^[.-]*//; s/[.-]*$//')
  [ -n "$slug" ] || return 1
  if [ "${#slug}" -le "$budget" ]; then
    printf '%s' "$slug"
    return 0
  fi
  # Longer than the id cap: keep a readable prefix and append a deterministic
  # hash of the FULL planning id, so two long ids never share a lane key.
  local digest suffix keep
  digest=$(printf '%s' "$planning_id" | sha256sum 2>/dev/null | cut -c1-6)
  [ -n "$digest" ] || digest=000000
  suffix="-$digest"
  keep=$(( budget - ${#suffix} ))
  [ "$keep" -gt 0 ] || return 1
  slug=$(printf '%s' "$slug" | cut -c1-"$keep")
  case "$slug" in *-*) slug=${slug%-*} ;; esac
  [ -n "$slug" ] || return 1
  printf '%s%s' "$slug" "$suffix"
}

# lane_key_for_task <lane-id> <planning-id> [model-id]: the compliant lane
# key for a backlog planning id. Fails when no compliant key can be minted.
# The model segment names the model the lane ACTUALLY runs, so a caller that
# overrides the model must pass it in.
lane_key_for_task() {
  local lane_id=$1 planning_id=$2 model_id=${3:-}
  [ -n "$planning_id" ] || return 1
  if [ "$MINT_LANE_KEY" != "1" ]; then
    printf '%s' "$planning_id"
    return 0
  fi
  local harness model host prefix budget task key
  harness=$(lane_key_harness_segment "${FM_ALWAYS_FOUR_HARNESS:-}")
  [ -n "$harness" ] || return 1
  [ -n "$model_id" ] || model_id=$(slot_model_for_lane "$lane_id")
  model=$(lane_key_model_segment "$model_id") || return 1
  host=$(lane_key_host_segment) || return 1
  prefix="$harness-$model-$host-"
  budget=$(( 64 - ${#prefix} ))
  [ "$budget" -ge 8 ] || return 1

  # A planning id that is ALREADY a lane key must not be prefixed a second
  # time. The decision-hold lifecycle names its Captain rows after the lane
  # that raised them ("codex-luna6-brandon-luna-<task>-decision-<key>"), and
  # minting that produced "codex-luna6-brandon-codex-luna6-brandon-...". Shorten
  # the TASK segment of an already-prefixed id instead of prefixing it again.
  case "$planning_id" in
    "$prefix"*)
      local already_rest="${planning_id#"$prefix"}"
      [ -n "$already_rest" ] || return 1
      task=$(lane_key_task_segment "$already_rest" "$budget") || return 1
      key="$prefix$task"
      [ "${#key}" -le 64 ] || return 1
      "$SCRIPT_DIR/fm-lane-naming-check.sh" "$key" >/dev/null 2>&1 || return 1
      printf '%s' "$key"
      return 0
      ;;
  esac

  task=$(lane_key_task_segment "$planning_id" "$budget") || return 1
  key="$prefix$task"
  [ "${#key}" -le 64 ] || return 1
  # The naming owner is the single authority for the vocabulary.
  "$SCRIPT_DIR/fm-lane-naming-check.sh" "$key" >/dev/null 2>&1 || return 1
  printf '%s' "$key"
}

# backlog_row_text <planning-id>: the queued backlog row's text for a
# planning id, with the list marker and the id token removed. The row is the
# task's authoritative text.
backlog_row_text() {
  local task_id=$1
  local backlog="$DATA/backlog.md"
  [ -f "$backlog" ] || return 1
  awk -v id="$task_id" '
    /^##[[:space:]]+/ {
      section = $0
      sub(/^##[[:space:]]+/, "", section)
      sub(/[[:space:]]+$/, "", section)
      next
    }
    section == "Queued" && index($0, id) > 0 {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]+\[[[:space:]]\][[:space:]]*/, "", line)
      if (index(line, id) == 1 &&
          (length(line) == length(id) || substr(line, length(id) + 1, 1) == " ")) {
        sub(/^[^[:space:]]+[[:space:]]*/, "", line)
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        print line
        exit
      }
    }
  ' "$backlog" 2>/dev/null
}

# fill_brief_task <brief-path> <task-text>: replace the {TASK} placeholder a
# scaffolded brief carries with the task text. python3 does the substitution
# because the text is arbitrary prose with backticks and quotes.
fill_brief_task() {
  local brief=$1 text=$2
  [ -f "$brief" ] || return 1
  command -v python3 >/dev/null 2>&1 || return 1
  FM_BRIEF_TASK_TEXT="$text" python3 - "$brief" <<'PY' || return 1
import os, sys
path = sys.argv[1]
text = os.environ.get("FM_BRIEF_TASK_TEXT", "")
with open(path, encoding="utf-8") as fh:
    body = fh.read()
if "{TASK}" not in body:
    sys.exit(1)
body = body.replace("{TASK}", text, 1)
with open(path, "w", encoding="utf-8") as fh:
    fh.write(body)
PY
}

# scaffold_lane_key_brief <lane-key> <planning-id>: create the lane key's
# brief when the planning id has none. bin/fm-brief.sh owns the brief
# contract, so it is CALLED and never re-implemented; the {TASK} placeholder
# it leaves is filled with the backlog row, which is that row's authoritative
# text. A lane with no brief is not dispatchable at all (fm-spawn.sh refuses a
# spawn without data/<id>/brief.md), so this is what lets a settled lane take
# genuinely NEW queued work instead of only work whose brief was hand-written
# for it.
scaffold_lane_key_brief() {
  local lane_key=$1 planning_id=$2
  [ -n "$lane_key" ] && [ -n "$planning_id" ] || return 1
  [ "$SCAFFOLD_BRIEF" = "1" ] || return 1
  local dst="$DATA/$lane_key/brief.md"
  [ -f "$dst" ] && return 0
  local row repo kind
  row=$(backlog_row_text "$planning_id") || return 1
  [ -n "$row" ] || return 1
  repo=$(printf '%s' "$row" | sed -n 's/.*(repo: \([^)]*\)).*/\1/p')
  [ -n "$repo" ] || return 1
  kind=$(printf '%s' "$row" | sed -n 's/.*(kind: \([^)]*\)).*/\1/p')
  local -a brief_args=("$lane_key" "$repo" --harness "${FM_ALWAYS_FOUR_HARNESS:-}")
  [ "$kind" = "scout" ] && brief_args+=(--scout)
  "$SCRIPT_DIR/fm-brief.sh" "${brief_args[@]}" >/dev/null 2>&1 || return 1
  fill_brief_task "$dst" "$row" || return 1
  return 0
}

# prepare_lane_key_brief <planning-id> <lane-key>: make sure the lane key's
# brief exists. bin/fm-spawn.sh refuses to spawn without data/<id>/brief.md.
# The brief is authored against the planning id, so the bridge copies it and
# rewrites the three id-bearing references a brief carries (branch, status
# file, report file) to the minted lane key. The task text is carried over
# verbatim. When the planning id has no brief at all, one is scaffolded from
# the backlog row. An existing brief is never overwritten.
prepare_lane_key_brief() {
  local planning_id=$1 lane_key=$2
  [ -n "$planning_id" ] && [ -n "$lane_key" ] || return 1
  # The rewrite below is a literal text substitution, so both ids must be
  # plain identifiers.
  case "$planning_id" in *[!A-Za-z0-9._-]*) return 1 ;; esac
  case "$lane_key" in *[!A-Za-z0-9._-]*) return 1 ;; esac
  local src="$DATA/$planning_id/brief.md"
  local dst_dir="$DATA/$lane_key"
  local dst="$dst_dir/brief.md"
  [ -f "$dst" ] && return 0
  if [ -f "$src" ]; then
    mkdir -p "$dst_dir" || return 1
    local tmp="$dst_dir/.brief.md.$$.tmp"
    if sed -e "s|fm/$planning_id|fm/$lane_key|g" \
           -e "s|$planning_id\.status|$lane_key.status|g" \
           -e "s|$planning_id/report\.md|$lane_key/report.md|g" \
           "$src" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
      if mv "$tmp" "$dst" 2>/dev/null; then
        return 0
      fi
    fi
    return 1
  fi
  scaffold_lane_key_brief "$lane_key" "$planning_id"
}

# record_lane_key_origin <lane-key> <planning-id>: remember which backlog
# planning id a minted lane key serves. The lane's own meta records the lane
# key, so without this record the queued row would look free and the same
# backlog task could be dispatched twice.
record_lane_key_origin() {
  local lane_key=$1 planning_id=$2
  [ -n "$lane_key" ] && [ -n "$planning_id" ] || return 1
  printf '%s\n' "$planning_id" > "$STATE/$lane_key.planning-id" 2>/dev/null || return 1
}

# record_lane_slot_binding <lane-id> <lane-key>: point the lane slot at the
# task it now runs. state/lane-<N>.meta is THIS scheduler's record of which
# task a lane holds (see the header contract). Nothing wrote it, so a refilled
# slot kept naming the task that had just finished: the slot then read as
# terminal and was replaced again on the very next cycle, burning the bounded
# attempt budget on a lane that was already working. The endpoint fields are
# copied from the task's own meta, which fm-spawn.sh just wrote.
record_lane_slot_binding() {
  local lane_id=$1 lane_key=$2
  local task_meta="$STATE/$lane_key.meta"
  [ -f "$task_meta" ] || return 1
  local key value tmp="$STATE/$lane_id.meta.new"
  {
    printf 'endpoint_task_id=%s\n' "$lane_key"
    for key in window backend herdr_pane_id model harness worktree; do
      value=$(grep "^$key=" "$task_meta" 2>/dev/null | cut -d= -f2- || true)
      [ -n "$value" ] && printf '%s=%s\n' "$key" "$value"
    done
  } > "$tmp" 2>/dev/null || return 1
  mv "$tmp" "$STATE/$lane_id.meta" 2>/dev/null || return 1
  return 0
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

# status_verb_of_line: the leading verb of a status line, after an optional
# ISO-8601 timestamp prefix is stripped.  fm-classify-lib.sh owns the verb
# grammar (status_line_verb) but reads the line verbatim, so a timestamped
# line would yield "2026-10-23T10" as its verb.  lane_state strips the same
# prefix before reading a verb, and the two censuses must read a line exactly
# the same way.
status_verb_of_line() {
  local line=$1 stripped
  stripped=$(printf '%s' "$line" \
    | sed -e 's/^\[[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:]\{8\}Z\] *//' \
          -e 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:]\{8\}Z: *//')
  status_line_verb "$stripped" 2>/dev/null || true
}

# worker_task_is_working: the scheduler's OWN honest liveness rule, shared by
# lane_is_active and count_active_worker_tasks so the two censuses can never
# disagree.  <meta-file> <endpoint_task_id> <state-dir>
#
# Returns 0 (the worker is working) only when ALL of these hold:
#   1. the meta file exists and has a non-empty endpoint_task_id=
#   2. the meta has a non-empty window= target
#   3. the backend target still EXISTS - a gone endpoint is NEVER working
#   4. the task status log <state-dir>/<endpoint_task_id>.status exists and its
#      last non-empty line's verb is non-empty and NOT a terminal verb
#
# No CPU time, process sleep state, marker mtime, or rendered-UI regex is read
# here: bin/fm-busy-lib.sh explicitly forbids those as liveness signals, so
# this rule stays inside the repository's busy contract.
worker_task_is_working() {
  local meta=$1 id=$2 state_dir=$3
  local backend target log last verb

  [ -f "$meta" ] || return 1

  if [ -z "$id" ]; then
    id=$(grep '^endpoint_task_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  fi
  [ -n "$id" ] || return 1

  target=$(grep '^window=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  [ -n "$target" ] || return 1

  backend=$(grep '^backend=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  [ -n "$backend" ] || backend=tmux

  # A gone endpoint is NEVER working.
  fm_backend_target_exists "$backend" "$target" "fm-$id" >/dev/null 2>&1 || return 1

  log="$state_dir/$id.status"
  [ -f "$log" ] || return 1
  last=$(last_status_line "$log" 2>/dev/null || true)
  [ -n "$last" ] || return 1
  verb=$(status_verb_of_line "$last")
  [ -n "$verb" ] || return 1
  if is_terminal_verb "$verb"; then
    return 1
  fi

  return 0
}

# Return 0 if the given lane is provably working (active).
# A working lane must NOT be replaced.
lane_is_active() {
  local lane_id=$1
  # Resolve the state dir at CALL time (the same override lane_current_task
  # honours) so an isolated home never reads the live state directory.
  local state_dir="${FM_STATE_OVERRIDE:-$STATE}"
  local meta="$state_dir/$lane_id.meta"
  local slot_log="$state_dir/$lane_id.status"
  local status_log task_id task_log
  local target backend harness label

  [ -f "$meta" ] || return 1

  # The agent's own progress/done lines live in the TASK status log
  # (state/<task-id>.status).  The slot log (state/<lane-id>.status) holds
  # only this scheduler's own binding and wake events, so reading it alone
  # could never see a lane settle.  Resolve the task log exactly the way
  # lane_state does: task log first, slot log only as the fallback for a lane
  # that has no task log yet.
  task_id=$(lane_current_task "$lane_id" 2>/dev/null || true)
  task_log=""
  [ -n "$task_id" ] && task_log="$state_dir/$task_id.status"
  if [ -n "$task_log" ] && [ -f "$task_log" ]; then
    status_log="$task_log"
  else
    status_log="$slot_log"
  fi

  [ -f "$status_log" ] || return 1

  target=$(grep '^window=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  if [ -z "$target" ]; then
    return 1
  fi

  backend=$(grep '^backend=' "$meta" 2>/dev/null | cut -d= -f2- || echo 'tmux')

  # A dead pane is never active: the liveness gate stays BEFORE the verdict.
  if ! fm_backend_target_exists "$backend" "$target" "fm-$lane_id" >/dev/null 2>&1; then
    return 1
  fi

  harness=$(grep '^harness=' "$meta" 2>/dev/null | cut -d= -f2- || true)
  label="fm-$lane_id"

  local tail40 verdict
  tail40=$(fm_backend_capture "$backend" "$target" 40 "$label" 2>/dev/null || true)
  verdict=$(fm_busy_classify "$backend" "$target" "$harness" "$lane_id" "$state_dir" "$tail40")

  case "${verdict%% *}" in
    busy) return 0 ;;
  esac

  # The scheduler's own honest liveness rule - the same rule the worker-task
  # census uses, so the two censuses cannot disagree.
  if worker_task_is_working "$meta" "$task_id" "$state_dir"; then
    return 0
  fi

  local last state
  last=$(last_status_line "$status_log" 2>/dev/null || true)
  state=$(status_verb_of_line "$last")
  if is_terminal_verb "$state"; then
    return 1
  fi

  if [ -z "$state" ]; then
    return 1
  fi

  # The endpoint is live and the lane's last status verb is present and
  # non-terminal: the lane is working and must not be replaced.
  return 0
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
  # The lane's CURRENT state is the state its TASK reports. The agent appends
  # to state/<task-id>.status (its brief names that exact file); the slot log
  # state/lane-<N>.status holds this scheduler's own binding and wake events.
  # Reading the slot log alone could never see a lane settle, so a finished
  # lane was refilled by hand and the wave stalled. The task log is read first;
  # the slot log stays the fallback for a lane with no task log yet.
  local task_id task_log
  task_id=$(lane_current_task "$lane_id" 2>/dev/null || true)
  task_log=""
  [ -n "$task_id" ] && task_log="$STATE/$task_id.status"

  if [ -n "$task_log" ] && [ -f "$task_log" ]; then
    last_line=$(last_status_line "$task_log" 2>/dev/null || true)
    status_log="$task_log"
  else
    [ -f "$status_log" ] || { printf 'state: unknown · source: no-status-log'; return; }
    last_line=$(grep -v '^[[:space:]]*$' "$status_log" 2>/dev/null | tail -1 || true)
  fi

  # Read last non-empty status line
  if [ -z "$last_line" ]; then
    printf 'state: unknown · source: empty-status-log'
    return
  fi

  # Extract verb: the leading word of the last status line, after any leading
  # ISO-8601 timestamp. fm-classify-lib.sh owns that reading, so the same
  # "<verb>: <note>" line that lane_is_active() already understands is the
  # line understood here.
  local stripped
  stripped=$(printf '%s' "$last_line" \
    | sed -e 's/^\[[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:]\{8\}Z\] *//' \
          -e 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9:]\{8\}Z: *//')
  last_verb=$(status_line_verb "$stripped" 2>/dev/null || true)

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
# working.  Controller metas (kind=secondmate / kind=controller) are excluded
  # from the worker target; ship and scout kinds are real workers and count.
count_active_worker_tasks() {
  local count=0 meta id model verdict kind backend target harness
  local counted_ids=""
  # Resolve the state dir at CALL time so an isolated home never reads the
  # live state directory.
  local state_dir="${FM_STATE_OVERRIDE:-$STATE}"

  # The accepted models are derived from THIS scheduler's own configuration
  # (WORKER_MODEL, plus CHECKER_MODEL when it differs - the checker slot is a
  # worker too), never from a hardcoded list.  A hardcoded model list goes
  # stale the moment a model is retired: the old list still named the retired
  # M2.7 and therefore rejected every live worker, reading the census as 0.
  # Do NOT turn this back into a hardcoded model list.
  for meta in "$state_dir"/*.meta; do
    [ -f "$meta" ] || continue

    # Controller metas (kind=secondmate / kind=controller) carry the worker
    # model but are not workers.  ship and scout kinds ARE real workers and
    # must stay in the census.
    kind=$(grep '^kind=' "$meta" 2>/dev/null | cut -d= -f2- || true)
    case "$(printf '%s' "$kind" | tr '[:upper:]' '[:lower:]')" in
      secondmate|controller) continue ;;
    esac

    model=$(grep '^model=' "$meta" 2>/dev/null | cut -d= -f2- || true)
    [ -n "$model" ] || continue
    if [ "$model" != "$WORKER_MODEL" ]; then
      if [ -z "$CHECKER_MODEL" ] || [ "$CHECKER_MODEL" = "$WORKER_MODEL" ] \
        || [ "$model" != "$CHECKER_MODEL" ]; then
        continue
      fi
    fi

    id=$(grep '^endpoint_task_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)
    [ -n "$id" ] || continue

    # Each managed lane owns BOTH state/<lane-id>.meta and
    # state/<endpoint_task_id>.meta, and both carry the SAME
    # endpoint_task_id, so the census counts DISTINCT endpoint_task_id values
    # only - counting meta files counted every live lane twice.
    case " $counted_ids " in
      *" $id "*) continue ;;
    esac

    # The busy contract stays the primary signal whenever it can classify the
    # harness; worker_task_is_working is the honest fallback for the harnesses
    # it cannot classify (minimax-code, codex -> "unknown").
    if worker_task_is_working "$meta" "$id" "$state_dir"; then
      counted_ids="$counted_ids $id"
      count=$((count + 1))
      continue
    fi

    # The busy verdict is read through the LIVE classification, so a gone
    # endpoint is never counted - the same gate lane_is_active applies.  The
    # two censuses must not be able to disagree.
    backend=$(fm_backend_of_meta "$meta")
    target=$(fm_backend_target_of_meta "$meta")
    harness=$(fm_meta_get "$meta" harness)
    if [ -n "$target" ]; then
      verdict=$(fm_busy_classify_live "$backend" "$target" "$harness" "$id" "$state_dir" "fm-$id" 2>/dev/null || true)
      if [ "${verdict%% *}" = busy ]; then
        counted_ids="$counted_ids $id"
        count=$((count + 1))
      fi
    fi
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
  # Resolve the data dir at CALL time, the same way the census functions do,
  # so an isolated home (FM_DATA_OVERRIDE) never reads the live backlog.
  local data_dir="${FM_DATA_OVERRIDE:-$DATA}"
  local backlog="$data_dir/backlog.md"
  [ -f "$backlog" ] || { echo ''; return; }

  local state_dir="${FM_STATE_OVERRIDE:-$STATE}"
  # Rebuild the in-flight set HERE, not once per cycle. The set was built at
  # Step 0 of the cycle, BEFORE any lane in this cycle had a meta, and it was
  # never refreshed after a spawn - so a cycle that filled several empty slots
  # handed EVERY slot the same queued row (measured 2026-10-23 in a dry run of
  # the Luna half: six empty lanes, six times the same task). Rebuilding before
  # each selection makes each slot in one cycle take a different row. A spawn
  # writes state/<lane-key>.meta and state/<lane-key>.planning-id before
  # cmd_spawn returns, so the row just taken is in the set by the next
  # selection.
  build_inflight_tmp 2>/dev/null || true
  build_valid_projects_tmp 2>/dev/null || true

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
      while ((getline line < ("'"$state_dir"'/.always-four.inflight.tmp")) > 0) {
        in_flight[line] = 1
      }
      close("'"$state_dir"'/.always-four.inflight.tmp")
      while ((getline pname < ("'"$state_dir"'/.always-four.projects.tmp")) > 0) {
        project_ok[pname] = 1
      }
      close("'"$state_dir"'/.always-four.projects.tmp")
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

      # A Captain Call row is NOT lane work. The decision-hold lifecycle
      # creates one backlog row per unresolved Captain decision, marked
      # "(kind: captain)" and "(hold: ...)", and that row waits for the
      # Captain answer. Dispatching one to a lane burns a lane on work the
      # Captain must do, and mints a malformed lane key from a row id that is
      # already lane-key shaped. Skip it exactly like a blocked-by row.
      if (index($0, "(kind: captain)") > 0) next

      # Skip a row whose project is not a resolvable treehouse project. A row
      # naming a repo that is not a git checkout can never be spawned:
      # fm-spawn.sh fails with "could not resolve the shared Treehouse project
      # lock", the lane burns its attempts, and the whole half starves on one
      # unroutable row while routable rows sit queued. The row stays in the
      # backlog for the Captain to see; it is simply not dispatched.
      if (match($0, /\(repo: [^)]+\)/)) {
        repo_name = substr($0, RSTART + 7, RLENGTH - 8)
        if (length(repo_name) > 0 && !(repo_name in project_ok)) next
      }

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
# build_valid_projects_tmp: list the project names that actually resolve to a
# git checkout, so a queued row naming anything else is not dispatched into a
# lane that cannot possibly spawn it.
#
# The project names come from the row text "(repo: <name>)". fm-spawn.sh
# resolves a bare project name relative to the scheduler working directory,
# and treehouse can only make a worktree from a git checkout, so a name whose
# directory has no .git is not a project at all.
build_valid_projects_tmp() {
  local state_dir="${FM_STATE_OVERRIDE:-$STATE}"
  local tmp="$state_dir/.always-four.projects.tmp"
  : > "$tmp"
  local base="${FM_LANE_PROJECT_BASE:-$PWD}"
  local name dir
  for dir in "$base"/*; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    [ -e "$dir/.git" ] || continue
    printf '%s\n' "$name" >> "$tmp"
  done
  # A project may also be named as a path relative to the base (projects/<name>).
  for dir in "$base"/*/*; do
    [ -d "$dir" ] || continue
    [ -e "$dir/.git" ] || continue
    printf '%s\n' "${dir#"$base"/}" >> "$tmp"
  done
}

build_inflight_tmp() {
  # Resolve the state dir at CALL time, the same way the census functions do,
  # so an isolated home (FM_STATE_OVERRIDE) never reads the live state dir.
  local state_dir="${FM_STATE_OVERRIDE:-$STATE}"
  local tmp="$state_dir/.always-four.inflight.tmp"
  : > "$tmp"
  # Task metadata is keyed by task ID (not scheduler slot), so lane-only
  # scanning misses real in-flight work and allows duplicate respawns.  Include
  # every authoritative meta record, then retain slot fallback for test homes.
  #
  # BOTH loops write INTO the temp file. The first loop's output used to go
  # to this function's stdout instead, so the in-flight set never held the
  # task metas at all and a queued row could be dispatched twice.
  local meta task origin
  for meta in "$state_dir"/*.meta; do
    [ -f "$meta" ] || continue
    task=$(grep '^endpoint_task_id=' "$meta" 2>/dev/null | cut -d= -f2- || true)
    [ -n "$task" ] && printf '%s\n' "$task" >> "$tmp"
    # A minted lane key is NOT the backlog planning id, so the meta above
    # names the lane, not the queued row. The planning id a minted lane
    # serves is recorded in state/<lane-key>.planning-id; read it so the
    # queued row is not dispatched a second time.
    if [ -n "$task" ]; then
      origin=$(cat "$state_dir/$task.planning-id" 2>/dev/null || true)
      [ -n "$origin" ] && printf '%s\n' "$origin" >> "$tmp"
    fi
  done
  for lane_id in $(lane_ids); do
    task=$(lane_current_task "$lane_id")
    [ -n "$task" ] && printf '%s\n' "$task" >> "$tmp"
  done
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
    if fm_lock_acquire_wait "$qlock" 5 2>/dev/null; then
      printf '%s\t%d\tsignal\t%s\t%s\n' \
        "$(date +%s)" "0" "$wake_key" "$msg" >> "$q" 2>/dev/null || true
      fm_lock_release "$qlock" 2>/dev/null || true
    fi
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

  # Mint the lane key. The backlog planning id is NOT a lane key: fm-spawn.sh
  # enforces <harness>-<model>-<host>-<task> on its first positional argument
  # and refused every backlog dispatch with exit 5. The backlog row is not
  # rewritten; the key is minted from it.
  local lane_key
  lane_key=$(lane_key_for_task "$lane_id" "$task_id" "$model_arg") || {
    printf 'always-four: spawn BLOCKED — no compliant lane key for %s in %s\n' \
      "$task_id" "$lane_id" >&2
    record_rollback_evidence "$lane_id" "$task_id" "lane-key-mint-failed" \
      "no compliant <harness>-<model>-<host>-<task> key for $task_id"
    return 65
  }
  if ! prepare_lane_key_brief "$task_id" "$lane_key"; then
    printf 'always-four: spawn BLOCKED — no brief for lane key %s (%s)\n' \
      "$lane_key" "$task_id" >&2
    record_rollback_evidence "$lane_id" "$task_id" "lane-key-brief-missing" \
      "no brief at data/$lane_key/brief.md"
    return 65
  fi

  # Pass the explicitly guarded adapter so fm-spawn cannot silently resolve a
  # controller or pane-default harness for this worker/checker lane.
  local spawn_args=("$lane_key" "$project" --harness "$SCHEDULER_HARNESS")
  [ -n "$harness_arg" ] && spawn_args+=(--harness "$harness_arg")
  [ -n "$model_arg" ] && spawn_args+=(--model "$model_arg")
  [ -n "$effort_arg" ] && spawn_args+=(--effort "$effort_arg")

  "$SCRIPT_DIR/fm-spawn.sh" "${spawn_args[@]}" && spawn_rc=$? || spawn_rc=$?

  if [ "${spawn_rc:-0}" -eq 0 ]; then
    lane_reset_attempts "$lane_id"
    [ "$lane_key" != "$task_id" ] && record_lane_key_origin "$lane_key" "$task_id"
    record_lane_slot_binding "$lane_id" "$lane_key" || true
    emit_coordinator_wake replacement "$lane_id" "$task_id" "spawned ok lane_key=$lane_key"
    sync_gbrain
    printf 'always-four: spawned %s in %s (lane key %s)\n' "$task_id" "$lane_id" "$lane_key"
  else
    lane_inc_attempts "$lane_id"
    record_rollback_evidence "$lane_id" "$task_id" "spawn-failed" "rc=$spawn_rc model=$model_arg lane_key=$lane_key"
    emit_coordinator_wake replacement "$lane_id" "$task_id" "spawn FAILED rc=$spawn_rc lane_key=$lane_key"
    sync_gbrain
    printf 'always-four: spawn %s in %s FAILED (rc=%s, attempts=%s, lane key %s)\n' \
      "$task_id" "$lane_id" "$spawn_rc" "$(lane_attempts "$lane_id")" "$lane_key"
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
    # The bounded-attempt cap must apply to THIS path too. It was only
    # consulted in the terminal-lane replacement path, so an empty slot whose
    # spawn kept failing was retried every poll interval forever (measured:
    # lane-001 attempts=34 against a cap of 3) and the cap that exists to stop
    # exactly that never fired here. An empty slot that has exhausted its
    # attempts is reported as a stall and left empty for the operator, not
    # hammered.
    if lane_at_max_attempts "$lane_id"; then
      emit_coordinator_wake stall "$lane_id" "" "max attempts reached ($(lane_attempts "$lane_id")/$MAX_ATTEMPTS) - empty slot not refilled"
      continue
    fi
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

      # This lane has CLAIMED the row: mark it in flight for the rest of this
      # cycle so the next lane in the same cycle cannot pick the same row.
      printf '%s\n' "$eligible" >> "$STATE/.always-four.inflight.tmp"

      # Mint the lane key and resolve the project BEFORE the queued row is
      # moved: the row leaves the Queued section, and the project is read from
      # that row. The planning id is not a lane key, so fm-spawn.sh refused
      # every one of these dispatches with exit 5 and the slot stayed empty.
      local lane_key project
      lane_key=$(lane_key_for_task "$lane_id" "$eligible" "$(slot_model_for_lane "$lane_id")") || {
        printf 'always-four: replacement BLOCKED — no compliant lane key for %s\n' \
          "$eligible" >&2
        record_rollback_evidence "$lane_id" "$eligible" "lane-key-mint-failed" \
          "no compliant <harness>-<model>-<host>-<task> key for $eligible"
        emit_coordinator_wake route-blocked "$lane_id" "$eligible" "no compliant lane key"
        continue
      }
      project=$(backlog_task_to_project "$eligible" 2>/dev/null || true)
      [ -z "$project" ] && project="projects/$eligible"
      if ! prepare_lane_key_brief "$eligible" "$lane_key"; then
        printf 'always-four: replacement BLOCKED — no brief for lane key %s (%s)\n' \
          "$lane_key" "$eligible" >&2
        record_rollback_evidence "$lane_id" "$eligible" "lane-key-brief-missing" \
          "no brief at data/$lane_key/brief.md"
        emit_coordinator_wake route-blocked "$lane_id" "$eligible" "no brief for lane key"
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
      local spawn_args=("$lane_key" "$project" --harness "$SCHEDULER_HARNESS" --model "$slot_model")
      "$SCRIPT_DIR/fm-spawn.sh" "${spawn_args[@]}" && spawn_rc=$? || spawn_rc=$?

      if [ "${spawn_rc:-0}" -eq 0 ]; then
        lane_reset_attempts "$lane_id"
        [ "$lane_key" != "$eligible" ] && record_lane_key_origin "$lane_key" "$eligible"
        record_lane_slot_binding "$lane_id" "$lane_key" || true
        emit_coordinator_wake replacement "$lane_id" "$eligible" "spawned ok model=$slot_model lane_key=$lane_key"
        sync_gbrain
        printf 'always-four: replaced %s with %s in %s (model=%s, lane key %s)\n' \
          "${replace_lanes[$lane_id]}" "$eligible" "$lane_id" "$slot_model" "$lane_key"
      else
        lane_inc_attempts "$lane_id"
        record_rollback_evidence "$lane_id" "$eligible" "replacement-spawn-failed" \
          "rc=$spawn_rc model=$slot_model lane_key=$lane_key"
        emit_coordinator_wake replacement "$lane_id" "$eligible" \
          "spawn FAILED rc=$spawn_rc model=$slot_model lane_key=$lane_key"
        sync_gbrain
        printf 'always-four: replacement spawn of %s in %s FAILED (rc=%s, model=%s, attempts=%s/%s, lane key %s)\n' \
          "$eligible" "$lane_id" "$spawn_rc" "$slot_model" "$(lane_attempts "$lane_id")" "$MAX_ATTEMPTS" "$lane_key"
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
