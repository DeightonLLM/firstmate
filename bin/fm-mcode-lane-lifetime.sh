#!/usr/bin/env bash
# fm-mcode-lane-lifetime.sh - bound the LIFETIME of an MCode lane process.
#
# Why this exists. A minimax-code lane is ONE Node process that keeps its
# session's history, turn diffs and compaction checkpoints live for as long as
# that process lives. On 2026-10-23 a board lane died of a Node/V8 old-space
# OOM after 65.0 hours of uptime, having retained ~50 MB of session JSON
# (3385 message rows, 765 turn-diff rows) in that single lifetime. The crash
# forensics are data/mcode-m3.1f-controller-oomforensics/report.md; they are
# the reason this file exists and they are not repeated here.
#
# A heap cap alone only converts a 65-hour OOM into a shorter one, so the
# CAPACITY half (bin/fm-spawn.sh's --max-old-space-size) and this LIFETIME
# half ship together. This file is the lifetime half.
#
# THE SIGNAL - durable state that already exists, read in place. No new
# telemetry channel is invented, and nothing is written to the store:
#
#   the MCode runtime store, <MINIMAX_DATA_DIR>/v2/sqlite/runtime-state.sqlite
#     local_runtime_sessions           one row per session. workspace_dir is the
#                                      lane's worktree; the most recently
#                                      updated row for that worktree is the
#                                      lane's CURRENT session.
#     local_runtime_message_rows       the retained messages. LENGTH(data_json)
#                                      is the volume the process must hold.
#     local_runtime_turn_diff_journal  the retained turn diffs (before_json,
#                                      after_json, paths_json): the second
#                                      growth term, and the bigger one.
#   the compaction counter: message rows whose JSON kind is "compaction"
#                                      (they carry metadata.compactionId), one
#                                      per compaction cycle the runtime kept.
#   the mid-turn state: local_runtime_turn_ingress rows whose status is
#                                      "accepted" - a turn the runtime has
#                                      accepted and not yet completed IS a turn
#                                      in flight. Measured on this host: a live
#                                      working lane carries 1, an idle lane 0.
#   the lane's own record: state/<task-id>.meta in this home (worktree,
#                                      harness, kind, backend).
#
# THE THRESHOLDS, and why these numbers:
#
#   retained bytes over budget -> recycle.
#     Measured: the crashed lane retained 49.8 MB (27.34 MB of message rows +
#     22.48 MB of turn-diff journal) when its heap reached ~1.9 GB, while a
#     healthy 83-hour lane retained 9.0 MB and a healthy 1.7-hour lane 5.3 MB.
#     The MCode heap cap in bin/fm-spawn.sh is --max-old-space-size=1024, whose
#     EFFECTIVE V8 ceiling measures 1072 MB. Fitting the measured retained ->
#     heap points puts the retained volume at which a capped lane reaches its
#     ceiling at roughly 27 MB. The threshold is 16 MB: about 1.8x the largest
#     healthy lane ever observed, and roughly half the volume at which the cap
#     would bite. The lane is retired long before the heap ceiling, not at it.
#
#   compaction cycles over budget -> recycle.
#     Measured: the crashed session recorded 14 compaction cycles, a healthy
#     83-hour lane recorded 3, and a live 1.7-hour lane recorded 1. The
#     threshold of 8 sits above every healthy lane observed and below the
#     crashed lane, so a lane that churns compactions without growing its byte
#     volume as fast is still caught.
#
# THE ACTION. Recycle means: relaunch the lane in the SAME worktree with the
# same brief plus a progress note, through the repo's own control plane
# (bin/fm-control.sh <id> relaunch --note ...). That is the sanctioned
# lifecycle verb: it replaces the agent process transactionally, keeps the
# worktree, keeps every uncommitted change, and hands the replacement the
# brief on disk instead of the old session's retained history - which is
# exactly the thing that has to stop accumulating.
#
# THE SAFETY GUARDS. Every one of them fails closed, and all of them must
# pass before anything is recycled:
#   * the lane must be a minimax-code lane of THIS home;
#   * a secondmate is never recycled here - a secondmate home's lifecycle
#     belongs to bin/fm-secondmate-provisioning.sh, not to this rule;
#   * the lane must not be mid-turn. The runtime's own durable turn-lifecycle
#     state is read FIRST - an accepted-but-not-completed turn IS a turn in
#     flight - and the backend's native agent state is the second, independent
#     read. A busy native verdict refuses the recycle even when the store says
#     idle. Only a proven idle verdict lets a recycle proceed; busy, unknown
#     and dead all refuse;
#   * the worktree must hold LANDED work. bin/fm-teardown.sh --probe-landed-work
#     runs this repo's COMPLETE landed-work guard - the same
#     validate_worktree_teardown_safety the destructive teardown path runs -
#     so this rule reuses the one test instead of writing a second, weaker one.
#     A verdict of unlanded OR unknown refuses the recycle.
#
# Usage:
#   fm-mcode-lane-lifetime.sh --budget <task-id>    the threshold decision alone
#   fm-mcode-lane-lifetime.sh --check <task-id>      budget + every safety guard
#   fm-mcode-lane-lifetime.sh --sweep                --check every mcode lane
#   fm-mcode-lane-lifetime.sh --recycle <task-id>    recycle, only if --check
#                                                     says recycle
#
# Output (stdout), one stable line per lane:
#   LANE_LIFETIME: <task-id> verdict=recycle|keep reason=<token> \
#     session=<id> retained_bytes=<n> msg_bytes=<n> journal_bytes=<n> \
#     compactions=<n> threshold_bytes=<n> threshold_compactions=<n>
#
# Environment (all optional):
#   FM_MCODE_RUNTIME_DB                override the runtime store path
#   FM_MCODE_LANE_MAX_RETAINED_BYTES   default 16777216 (16 MiB)
#   FM_MCODE_LANE_MAX_COMPACTIONS      default 8
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"

# shellcheck source=bin/fm-backend.sh
. "$SCRIPT_DIR/fm-backend.sh"
# shellcheck source=bin/fm-busy-lib.sh
. "$SCRIPT_DIR/fm-busy-lib.sh"

MCODE_LANE_MAX_RETAINED_BYTES=${FM_MCODE_LANE_MAX_RETAINED_BYTES:-16777216}
MCODE_LANE_MAX_COMPACTIONS=${FM_MCODE_LANE_MAX_COMPACTIONS:-8}

usage() {
  sed -n '2,90p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

# --- the durable signal ------------------------------------------------------

# The MCode runtime store. Overridable so a test can point the rule at a
# fixture store; the default is the real one.
runtime_store_path() {
  printf '%s' "${FM_MCODE_RUNTIME_DB:-${MINIMAX_DATA_DIR:-${HOME:-/root}/.minimax}/v2/sqlite/runtime-state.sqlite}"
}

# sql_escape: make a value safe as a single-quoted SQL literal.
sql_escape() {
  printf '%s' "${1-}" | sed "s/'/''/g"
}

# sanitize_uint: a plain unsigned integer, or 0. Every number that reaches an
# arithmetic expression goes through this, so a malformed read can never become
# a bitwise surprise or a negative threshold.
sanitize_uint() {
  case "${1-}" in
    ''|*[!0-9]*) printf '0' ;;
    *) printf '%s' "$1" ;;
  esac
}

# store_query: run one read-only query against the runtime store. Prints
# nothing and returns non-zero when the store cannot be read at all - the
# caller then refuses rather than guessing a lane's budget. Columns are
# space-separated so a caller can read them as positional fields.
store_query() {  # <sql>
  local db
  db=$(runtime_store_path)
  [ -f "$db" ] || return 1
  command -v sqlite3 >/dev/null 2>&1 || return 1
  sqlite3 -readonly -cmd ".timeout 5000" -separator ' ' "$db" "$1" 2>/dev/null
}

# lane_session_id: the lane's CURRENT session, resolved from durable state.
# The lane's worktree is the join key: state/<id>.meta records it, and the
# runtime store's session rows carry the same path. The most recently updated
# row for that worktree is the live one.
lane_session_id() {  # <worktree>
  local wt sid
  wt=$(sql_escape "${1-}")
  [ -n "$wt" ] || return 1
  sid=$(store_query "
    SELECT session_id FROM local_runtime_sessions
     WHERE workspace_dir = '$wt'
     ORDER BY updated_at_ms DESC, created_at_ms DESC
     LIMIT 1;") || return 1
  sid=$(printf '%s' "$sid" | tr -d '[:space:]')
  [ -n "$sid" ] || return 1
  printf '%s' "$sid"
}

# lane_metrics: the retained volume of one session, in bytes, plus its
# compaction count. Prints "<msg_bytes> <journal_bytes> <compactions>".
lane_metrics() {  # <session-id>
  local sid out
  sid=$(sql_escape "${1-}")
  [ -n "$sid" ] || return 1
  out=$(store_query "
    SELECT
      COALESCE((SELECT SUM(LENGTH(data_json)) FROM local_runtime_message_rows WHERE session_id = '$sid'), 0),
      COALESCE((SELECT SUM(LENGTH(before_json) + LENGTH(after_json) + LENGTH(paths_json))
                  FROM local_runtime_turn_diff_journal WHERE session_id = '$sid'), 0),
      COALESCE((SELECT SUM(CASE WHEN json_valid(data_json)
                                THEN CASE WHEN json_extract(data_json, '\$.kind') = 'compaction' THEN 1 ELSE 0 END
                                ELSE 0 END)
                  FROM local_runtime_message_rows WHERE session_id = '$sid'), 0);") || return 1
  [ -n "$out" ] || return 1
  printf '%s' "$out"
}

# --- the lane's own record ----------------------------------------------------

meta_value() {  # <meta-file> <key>
  [ -f "${1-}" ] || return 1
  grep "^${2-}=" "$1" 2>/dev/null | tail -1 | cut -d= -f2-
}

# lane_budget: the threshold decision alone, with no fleet interaction.
# Prints "<verdict> <reason> <session> <msg_bytes> <journal_bytes> <compactions>".
#   verdict is recycle when the lane is over budget, keep when it is within it.
lane_budget() {  # <task-id>
  local id=$1 meta wt sid metrics msg_bytes journal_bytes compactions retained
  meta="$STATE/$id.meta"
  if [ ! -f "$meta" ]; then
    printf 'keep no-meta 0 0 0 0'
    return 0
  fi
  wt=$(meta_value "$meta" worktree)
  if [ -z "$wt" ]; then
    printf 'keep no-worktree 0 0 0 0'
    return 0
  fi
  if ! sid=$(lane_session_id "$wt"); then
    printf 'keep no-session 0 0 0 0'
    return 0
  fi
  if ! metrics=$(lane_metrics "$sid"); then
    printf 'keep signal-unavailable 0 0 0 0'
    return 0
  fi
  # shellcheck disable=SC2086
  set -- $metrics
  msg_bytes=$(sanitize_uint "${1:-0}")
  journal_bytes=$(sanitize_uint "${2:-0}")
  compactions=$(sanitize_uint "${3:-0}")
  retained=$(( msg_bytes + journal_bytes ))
  if [ "$retained" -gt "$MCODE_LANE_MAX_RETAINED_BYTES" ]; then
    printf 'recycle retained-bytes-over-budget %s %s %s %s' \
      "$sid" "$msg_bytes" "$journal_bytes" "$compactions"
    return 0
  fi
  if [ "$compactions" -gt "$MCODE_LANE_MAX_COMPACTIONS" ]; then
    printf 'recycle compactions-over-budget %s %s %s %s' \
      "$sid" "$msg_bytes" "$journal_bytes" "$compactions"
    return 0
  fi
  printf 'keep within-budget %s %s %s %s' \
    "$sid" "$msg_bytes" "$journal_bytes" "$compactions"
}

# --- the safety guards --------------------------------------------------------

# lane_open_turns: how many turns the runtime has ACCEPTED but not yet
# completed for this session. A turn the runtime has accepted and not
# completed IS a turn in flight, and the runtime records it durably in
# local_runtime_turn_ingress - the same table the crash forensics read. This
# is the mid-turn signal, and it needs no live pane and no new telemetry.
# Measured on this host: a live working lane carries 1 accepted turn, an idle
# lane carries 0, and a lane whose process died mid-turn keeps its accepted
# row, which is the conservative direction.
lane_open_turns() {  # <session-id>
  local sid out
  sid=$(sql_escape "${1-}")
  [ -n "$sid" ] || return 1
  out=$(store_query "
    SELECT COUNT(*) FROM local_runtime_turn_ingress
     WHERE session_id = '$sid' AND status = 'accepted';") || return 1
  out=$(printf '%s' "$out" | tr -d '[:space:]')
  case "$out" in
    ''|*[!0-9]*) return 1 ;;
  esac
  printf '%s' "$out"
}

# lane_mid_turn_verdict: is this lane provably NOT mid-turn?
# The durable turn-lifecycle state is read FIRST: it is exact and it needs no
# pane. The backend's native agent state is the SECOND, independent read, and
# a busy native verdict refuses the recycle even when the store says idle.
# Prints one of: idle | mid-turn | unknown.
lane_mid_turn_verdict() {  # <backend> <target> <session-id>
  local backend=$1 target=$2 sid=$3 open native
  if ! open=$(lane_open_turns "$sid"); then
    printf 'unknown turn-state-unavailable'
    return 0
  fi
  if [ "$open" -gt 0 ]; then
    printf 'mid-turn open-turn'
    return 0
  fi
  native=$(fm_backend_busy_state "$backend" "$target" 2>/dev/null || true)
  case "$native" in
    busy) printf 'mid-turn native-agent-state'; return 0 ;;
  esac
  printf 'idle'
}

# lane_landed_work_verdict: has this lane's work landed?
# Delegates to bin/fm-teardown.sh --probe-landed-work, which runs this repo's
# complete landed-work guard without touching anything. Prints one of:
# landed | unlanded | unknown.
lane_landed_work_verdict() {  # <task-id>
  local id=$1 out rc
  out=$(FM_HOME="$FM_HOME" "$FM_ROOT/bin/fm-teardown.sh" "$id" --probe-landed-work 2>/dev/null)
  rc=$?
  case "$out" in
    *'verdict=landed'*) printf 'landed'; return 0 ;;
    *'verdict=unlanded'*) printf 'unlanded'; return 0 ;;
  esac
  case "$rc" in
    0) printf 'landed'; return 0 ;;
    1) printf 'unlanded'; return 0 ;;
  esac
  printf 'unknown'
}

# lane_check: the full decision - the budget AND every safety guard.
# Prints "<verdict> <reason> <session> <msg_bytes> <journal_bytes> <compactions>".
lane_check() {  # <task-id>
  local id=$1 meta harness kind backend target budget verdict reason sid msg journal comps
  local mid_turn landed
  meta="$STATE/$id.meta"
  if [ ! -f "$meta" ]; then
    printf 'keep no-meta 0 0 0 0'
    return 0
  fi
  harness=$(meta_value "$meta" harness)
  kind=$(meta_value "$meta" kind)
  [ -n "$kind" ] || kind=ship
  if [ "$harness" != minimax-code ]; then
    printf 'keep not-an-mcode-lane 0 0 0 0'
    return 0
  fi
  if [ "$kind" = secondmate ]; then
    printf 'keep secondmate-lifecycle 0 0 0 0'
    return 0
  fi
  budget=$(lane_budget "$id")
  # shellcheck disable=SC2086
  set -- $budget
  verdict=${1:-keep}
  reason=${2:-unknown}
  sid=${3:-0}
  msg=$(sanitize_uint "${4:-0}")
  journal=$(sanitize_uint "${5:-0}")
  comps=$(sanitize_uint "${6:-0}")
  if [ "$verdict" != recycle ]; then
    printf '%s %s %s %s %s %s' "$verdict" "$reason" "$sid" "$msg" "$journal" "$comps"
    return 0
  fi
  # Over budget: every guard must pass before a recycle is permitted.
  backend=$(fm_backend_of_meta "$meta")
  target=$(fm_backend_target_of_meta "$meta")
  if [ -z "$backend" ] || [ -z "$target" ]; then
    printf 'keep no-endpoint %s %s %s %s' "$sid" "$msg" "$journal" "$comps"
    return 0
  fi
  # A lane whose endpoint is proven gone has no process to recycle: the
  # stuck-crewmate-recovery path owns a dead lane, not this rule.
  endpoint_state=$(fm_backend_agent_state "$backend" "$target" 2>/dev/null || true)
  case "$endpoint_state" in
    dead|missing)
      printf 'keep endpoint-dead %s %s %s %s' "$sid" "$msg" "$journal" "$comps"
      return 0
      ;;
  esac
  mid_turn=$(lane_mid_turn_verdict "$backend" "$target" "$sid")
  case "$mid_turn" in
    mid-turn*)
      printf 'keep mid-turn %s %s %s %s' "$sid" "$msg" "$journal" "$comps"
      return 0
      ;;
    unknown*)
      printf 'keep busy-state-unknown %s %s %s %s' "$sid" "$msg" "$journal" "$comps"
      return 0
      ;;
  esac
  landed=$(lane_landed_work_verdict "$id")
  case "$landed" in
    landed) : ;;
    unlanded)
      printf 'keep unlanded-work %s %s %s %s' "$sid" "$msg" "$journal" "$comps"
      return 0
      ;;
    *)
      printf 'keep landed-work-unknown %s %s %s %s' "$sid" "$msg" "$journal" "$comps"
      return 0
      ;;
  esac
  printf 'recycle %s %s %s %s %s' "$reason" "$sid" "$msg" "$journal" "$comps"
}

# --- reporting ----------------------------------------------------------------

emit_lane() {  # <task-id> <verdict> <reason> <session> <msg> <journal> <compactions>
  printf 'LANE_LIFETIME: %s verdict=%s reason=%s session=%s retained_bytes=%s msg_bytes=%s journal_bytes=%s compactions=%s threshold_bytes=%s threshold_compactions=%s\n' \
    "$1" "$2" "$3" "$4" "$(( $5 + $6 ))" "$5" "$6" "$7" \
    "$MCODE_LANE_MAX_RETAINED_BYTES" "$MCODE_LANE_MAX_COMPACTIONS"
}

report_check() {  # <task-id>
  local id=$1 out verdict reason sid msg journal comps
  out=$(lane_check "$id")
  # shellcheck disable=SC2086
  set -- $out
  verdict=${1:-keep}
  reason=${2:-unknown}
  sid=${3:-0}
  msg=${4:-0}
  journal=${5:-0}
  comps=${6:-0}
  emit_lane "$id" "$verdict" "$reason" "$sid" "$msg" "$journal" "$comps"
  [ "$verdict" = recycle ]
}

report_budget() {  # <task-id>
  local id=$1 out verdict reason sid msg journal comps
  out=$(lane_budget "$id")
  # shellcheck disable=SC2086
  set -- $out
  verdict=${1:-keep}
  reason=${2:-unknown}
  sid=${3:-0}
  msg=$(sanitize_uint "${4:-0}")
  journal=$(sanitize_uint "${5:-0}")
  comps=$(sanitize_uint "${6:-0}")
  emit_lane "$id" "$verdict" "$reason" "$sid" "$msg" "$journal" "$comps"
}

# --- the action ---------------------------------------------------------------

# recycle_lane: replace the lane's agent process with a fresh one, in the same
# worktree, with the brief plus a progress note. The control plane owns the
# transaction; this script only decides WHEN.
recycle_lane() {  # <task-id>
  local id=$1 out verdict reason sid msg journal comps retained note rc
  out=$(lane_check "$id")
  # shellcheck disable=SC2086
  set -- $out
  verdict=${1:-keep}
  reason=${2:-unknown}
  sid=${3:-0}
  msg=$(sanitize_uint "${4:-0}")
  journal=$(sanitize_uint "${5:-0}")
  comps=$(sanitize_uint "${6:-0}")
  retained=$(( msg + journal ))
  emit_lane "$id" "$verdict" "$reason" "$sid" "$msg" "$journal" "$comps"
  if [ "$verdict" != recycle ]; then
    printf 'LANE_RECYCLE: %s refused reason=%s\n' "$id" "$reason"
    return 1
  fi
  note="Recycled by bin/fm-mcode-lane-lifetime.sh: this lane's session retained ${retained} bytes of history (${msg} bytes of message rows, ${journal} bytes of turn-diff journal) across ${comps} compaction cycles, over the ${MCODE_LANE_MAX_RETAINED_BYTES}-byte lifetime budget. The previous agent process has been replaced so it can no longer grow. The worktree and every uncommitted change are preserved, and you start from a fresh session: re-read the brief, then continue the work."
  FM_HOME="$FM_HOME" "$FM_ROOT/bin/fm-control.sh" "$id" relaunch --note "$note"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    printf 'LANE_RECYCLE: %s recycled reason=%s\n' "$id" "$reason"
    return 0
  fi
  printf 'LANE_RECYCLE: %s refused reason=control-plane-refused rc=%s\n' "$id" "$rc"
  return "$rc"
}

# --- entry point --------------------------------------------------------------

[ "$#" -ge 1 ] || usage
MODE=$1
shift || true

case "$MODE" in
  --budget)
    [ "$#" -ge 1 ] || usage
    report_budget "$1" || true
    ;;
  --check)
    [ "$#" -ge 1 ] || usage
    report_check "$1" || true
    ;;
  --recycle)
    [ "$#" -ge 1 ] || usage
    # The exit status is the verdict: a refused recycle exits non-zero, so a
    # caller driving this in a loop can tell a refusal from a recycle.
    recycle_lane "$1"
    exit $?
    ;;
  --sweep)
    found=0
    for meta in "$STATE"/*.meta; do
      [ -e "$meta" ] || continue
      [ -L "$meta" ] && continue
      id=$(basename "$meta" .meta)
      [ "$(meta_value "$meta" harness)" = minimax-code ] || continue
      found=1
      report_check "$id" || true
    done
    [ "$found" = 1 ] || printf 'LANE_LIFETIME: none verdict=keep reason=no-mcode-lanes\n'
    ;;
  --help|-h)
    usage
    ;;
  *)
    echo "error: unknown mode '$MODE'" >&2
    usage
    ;;
esac
