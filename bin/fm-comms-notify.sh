#!/usr/bin/env bash
# fm-comms-notify.sh - immediate guarded communication notification after
# durable file delivery.
#
# Usage:
#   fm-comms-notify.sh notify --route <route> [--file <file>] [--content <text>]
#                             [--sha <sha>] [--summary <summary>] [--corr <corr>]
#                             [--target <target>] [--machine <machine>]
#   fm-comms-notify.sh drain [--route <route>]
#   fm-comms-notify.sh status [--route <route>]
#   fm-comms-notify.sh --help
#
# CONTRACT:
# 1. Immediate guarded notification: after a message or reply file is durably
#    delivered on disk (Controller -> secondmate or secondmate -> Controller),
#    this helper notifies the recipient agent pane directly, eliminating the
#    5-minute polling delay without operator relay.
# 2. Target verification: resolves recipient identity live (via Herdr agent/pane
#    queries and secondmates.md registry), never hardcoding stale pane IDs.
# 3. Guarded submission: checks recipient agent status before prompting.
#    - idle / interactive: submits notification atomically via `herdr agent prompt`.
#    - working / blocked: defers cleanly into a durable pending queue.
#      Never interrupts, sends Ctrl-C, sends Escape, or overwrites drafts.
# 4. Failure preservation: if notification fails (network drop, timeout), the
#    already-delivered file on disk is preserved intact for fallback poll.
# 5. Content-keyed dedup: prevents duplicate prompt turns across sync paths
#    (e.g. to-brandon-compute/ and controller-replies/) and across repeated polls.
# 6. Drain/resumption: pending deferred notifications are delivered as soon as
#    the recipient returns to idle.
#
# THE PROMPT IS BOUNDED, AND ONLY A PROVEN-IDLE RECIPIENT IS PROMPTED.
# Measured 2026-10-21 on the Controller: `herdr agent list` returned an EMPTY
# list ({"id":"cli:agent:list","result":{"agents":[],"type":"agent_list"}}) and
# the pane path reported agent_status "unknown". The old gate only deferred on
# "working" or "blocked", and only deferred on ready_val=false, so a status of
# "unknown" fell straight through to the PROMPT branch. The prompt was then
# never accepted, because the pane's real state was unknown, and
# `herdr agent prompt` blocked forever.
#
# That single fall-through is what wedged the fleet: bin/fm-comms-ingest.sh
# called this script while HOLDING the comms receipts lock, so one unresponsive
# pane became an unbounded comms outage - every later scan piled up behind the
# stuck lock holder.
#
# Two rules follow, and both are load-bearing:
#   1. A recipient whose state cannot be read is NOT a recipient proven idle.
#      Only an explicit "idle" may be prompted; "unknown", an absent status,
#      and anything unrecognised DEFER into the durable pending queue.
#   2. The prompt call itself is bounded by a timeout, so even a correct gate
#      cannot be defeated by a pane that stops responding mid-call.
# Deferring is always safe: the message file is already on disk, so a deferred
# notification costs latency, never delivery.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-${STATE:-$FM_HOME/state}}"
DATA="${FM_DATA_OVERRIDE:-${DATA:-$FM_HOME/data}}"
REG="$DATA/secondmates.md"
LEDGER="$STATE/comms-notify-ledger.tsv"
PENDING_BASE="$STATE/comms-pending-notify"

if [ -f "$SCRIPT_DIR/fm-secondmate-registry-lib.sh" ]; then
  # shellcheck source=bin/fm-secondmate-registry-lib.sh
  . "$SCRIPT_DIR/fm-secondmate-registry-lib.sh"
fi

# The single owner of bounded command execution. The prompt below is run
# through it so a pane that never answers cannot hold this script (and, when
# this script is called from the comms ingest, the receipts lock) forever.
if [ -f "$SCRIPT_DIR/fm-timeout-lib.sh" ]; then
  # shellcheck source=bin/fm-timeout-lib.sh
  . "$SCRIPT_DIR/fm-timeout-lib.sh"
fi

# How long the prompt submission may take before it is abandoned. The reply
# file is already durable on disk, so an abandoned prompt costs a notification,
# never a delivery.
FM_COMMS_NOTIFY_TIMEOUT_S="${FM_COMMS_NOTIFY_TIMEOUT_S:-20}"
case "$FM_COMMS_NOTIFY_TIMEOUT_S" in
  '' | *[!0-9]*) FM_COMMS_NOTIFY_TIMEOUT_S=20 ;;
esac

usage() {
  sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

compute_sha() { # <content> <file>
  local content=${1:-} file=${2:-}
  if [ -n "$content" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      printf '%s' "$content" | sha256sum | awk '{print $1}'
    else
      printf '%s' "$content" | shasum -a 256 | awk '{print $1}'
    fi
  elif [ -n "$file" ] && [ -f "$file" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum -- "$file" 2>/dev/null | awk '{print $1}'
    else
      shasum -a 256 -- "$file" 2>/dev/null | awk '{print $1}'
    fi
  elif [ -n "$file" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      printf '%s' "$file" | sha256sum | awk '{print $1}'
    else
      printf '%s' "$file" | shasum -a 256 | awk '{print $1}'
    fi
  else
    printf ''
  fi
}

resolve_live_agent() { # <machine> <hint>
  local machine=${1:-} hint=${2:-}
  local -a herdr_cmd=(herdr)
  [ -z "$machine" ] || herdr_cmd=(herdr --machine "$machine")

  local agent_out
  if ! agent_out=$("${herdr_cmd[@]}" agent list 2>/dev/null); then
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    # A row's identity is its `.name` only when that field is populated. This
    # Herdr version reports `"name": null` and identifies agents by `.pane_id`,
    # so a `.name`-only selector emits the literal text "null"; jq -r renders it
    # as a non-empty string, and it was accepted as a real recipient, which
    # queued every remote notification against a target that cannot exist.
    # `ident` prefers a populated name and otherwise falls back to the pane id.
    local ident_def
    # A jq program, not a shell string: it must not be expanded by the shell.
    # shellcheck disable=SC2016
    ident_def='def ident: (.name // "") as $n | if $n == "" or $n == "null" then (.pane_id // "") else $n end;'
    local matched
    matched=$(printf '%s' "$agent_out" | jq -r "$ident_def"'
      .result.agents[]? | ident | select(. == $h)
    ' --arg h "$hint" 2>/dev/null | head -1)
    if [ -n "$matched" ] && [ "$matched" != "null" ]; then
      printf '%s' "$matched"
      return 0
    fi
    # If no exact identity match, select first active non-protected agent
    matched=$(printf '%s' "$agent_out" | jq -r "$ident_def"'
      .result.agents[]? | select(.label // "" | test("protected"; "i") | not) | ident | select(. != "")
    ' 2>/dev/null | head -1)
    if [ -n "$matched" ] && [ "$matched" != "null" ]; then
      printf '%s' "$matched"
      return 0
    fi
  fi

  # Fallback to pane list
  local pane_out
  if pane_out=$("${herdr_cmd[@]}" pane list 2>/dev/null); then
    if command -v jq >/dev/null 2>&1; then
      local pane_id
      pane_id=$(printf '%s' "$pane_out" | jq -r '
        .result.panes[]? | select(.label // "" | test("protected"; "i") | not) | .pane_id
      ' 2>/dev/null | head -1)
      if [ -n "$pane_id" ]; then
        printf '%s' "$pane_id"
        return 0
      fi
    fi
  fi
  return 1
}

check_target_safety() { # <machine> <target>
  local machine=${1:-} target=$2
  local -a herdr_cmd=(herdr)
  [ -z "$machine" ] || herdr_cmd=(herdr --machine "$machine")

  local agent_out
  if agent_out=$("${herdr_cmd[@]}" agent list 2>/dev/null); then
    if command -v jq >/dev/null 2>&1; then
      local is_protected
      is_protected=$(printf '%s' "$agent_out" | jq -r --arg t "$target" '
        .result.agents[]? | select(.name == $t or .pane_id == $t) |
        if (.label // "" | test("protected"; "i")) then "yes" else "no" end
      ' 2>/dev/null | head -1)
      if [ "$is_protected" = "yes" ]; then
        printf 'error: target %s is protected; refusing notification\n' "$target" >&2
        return 1
      fi
    fi
  fi
  return 0
}

get_agent_status() { # <machine> <target> -> prints "<status> <ready>"
  local machine=${1:-} target=$2
  local -a herdr_cmd=(herdr)
  [ -z "$machine" ] || herdr_cmd=(herdr --machine "$machine")

  local agent_out
  if agent_out=$("${herdr_cmd[@]}" agent list 2>/dev/null); then
    if command -v jq >/dev/null 2>&1; then
      local status ready
      status=$(printf '%s' "$agent_out" | jq -r --arg t "$target" '
        .result.agents[]? | select(.name == $t or .pane_id == $t) | .agent_status
      ' 2>/dev/null | head -1)
      ready=$(printf '%s' "$agent_out" | jq -r --arg t "$target" '
        .result.agents[]? | select(.name == $t or .pane_id == $t) | .interactive_ready
      ' 2>/dev/null | head -1)
      if [ -n "$status" ]; then
        printf '%s %s\n' "$status" "${ready:-true}"
        return 0
      fi
    fi
  fi

  local pane_out
  if pane_out=$("${herdr_cmd[@]}" pane list 2>/dev/null); then
    if command -v jq >/dev/null 2>&1; then
      local status
      status=$(printf '%s' "$pane_out" | jq -r --arg t "$target" '
        .result.panes[]? | select(.pane_id == $t) | .agent_status
      ' 2>/dev/null | head -1)
      if [ -n "$status" ]; then
        printf '%s true\n' "$status"
        return 0
      fi
    fi
  fi
  printf 'unknown false\n'
}

# defer_notification <route> <machine> <target> <file> <sha> <summary> <content> <corr> <reason>
# Record the notification in the durable pending queue instead of prompting.
# Deferring is always safe: the message file is already on disk, so a deferred
# notification costs latency, never delivery. The pending entry is drained by
# `fm-comms-notify.sh drain` once the recipient is back to idle.
defer_notification() {
  local route=$1 machine=$2 target=$3 file=$4 sha=$5 summary=$6 content=$7 corr=$8 reason=$9
  local pending_dir="$PENDING_BASE/$route"
  mkdir -p "$pending_dir"
  cat > "$pending_dir/$sha.pending" <<EOF
route=$route
machine=$machine
target=$target
file=$file
sha=$sha
summary=$summary
content=$content
corr=$corr
timestamp=$(date +%s)
EOF
  printf 'deferred: %s is %s (recorded pending notification)\n' "$target" "$reason"
  return 0
}

cmd_notify() {
  local route="" file="" content="" sha="" summary="" corr="" opt_target="" opt_machine=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --route) route="$2"; shift 2 ;;
      --file) file="$2"; shift 2 ;;
      --content) content="$2"; shift 2 ;;
      --sha) sha="$2"; shift 2 ;;
      --summary) summary="$2"; shift 2 ;;
      --corr) corr="$2"; shift 2 ;;
      --target) opt_target="$2"; shift 2 ;;
      --machine) opt_machine="$2"; shift 2 ;;
      -h|--help) usage ;;
      *) die "unknown option: $1" ;;
    esac
  done

  [ -n "$route" ] || die "--route is required"

  if [ -z "$sha" ]; then
    sha=$(compute_sha "$content" "$file")
  fi
  [ -n "$sha" ] || die "could not compute or verify message sha"

  # Dedup against notification ledger
  mkdir -p "$STATE"
  if [ -f "$LEDGER" ]; then
    if grep -qF "$sha"$'\t'"$route"$'\t' "$LEDGER" 2>/dev/null; then
      printf 'already-notified: %s (%s)\n' "${file:-unknown}" "$sha"
      return 0
    fi
  fi

  local machine="" target=""
  case "$route" in
    controller|parent)
      machine=""
      if [ -n "$opt_target" ]; then
        target="$opt_target"
      elif [ -n "${FM_COMMS_CONTROLLER_TARGET:-}" ]; then
        target="$FM_COMMS_CONTROLLER_TARGET"
      else
        target=$(resolve_live_agent "" "controller" 2>/dev/null || true)
      fi
      ;;
    *)
      if [ -n "$opt_machine" ]; then
        machine="$opt_machine"
      elif [ -f "$REG" ] && secondmate_registry_line_for_id "$REG" "$route" 2>/dev/null; then
        if [ "${SECONDMATE_REGISTRY_REMOTE:-0}" -eq 1 ]; then
          machine="$SECONDMATE_REGISTRY_HOST"
        else
          machine=""
        fi
      elif [ -n "$opt_target" ]; then
        machine=""
      else
        die "unknown route or identity: $route (not found in secondmates registry)"
      fi

      if [ -n "$opt_target" ]; then
        target="$opt_target"
      elif [ -n "${FM_COMMS_TARGET:-}" ]; then
        target="$FM_COMMS_TARGET"
      else
        target=$(resolve_live_agent "$machine" "$route" 2>/dev/null || true)
      fi
      ;;
  esac

  [ -n "$target" ] || die "unknown recipient identity for route '$route' (no live agent found)"

  check_target_safety "$machine" "$target" || exit 1

  # Check recipient state
  local st_line st_val ready_val
  st_line=$(get_agent_status "$machine" "$target")
  st_val=$(printf '%s' "$st_line" | awk '{print $1}')
  ready_val=$(printf '%s' "$st_line" | awk '{print $2}')

  if [ -z "$summary" ] && [ -n "$content" ]; then
    summary=$(printf '%s' "$content" | head -1 | cut -c1-100)
  fi

  # Recipient state gate.
  #
  # ONLY a recipient PROVEN idle may be prompted. The measured 2026-10-21
  # failure was a fall-through: `herdr agent list` returned an empty list and
  # the pane path reported agent_status "unknown", so st_val matched neither
  # "working" nor "blocked" and ready_val was not "false" - and the code went
  # straight to the prompt branch. The prompt was then never accepted and
  # `herdr agent prompt` blocked forever, holding the caller's receipts lock
  # with it.
  #
  # A recipient whose state cannot be read is NOT a recipient proven idle,
  # so every status that is not an explicit "idle" defers. Deferring records
  # the notification in the durable pending queue; the message file is
  # already on disk, so this costs latency and never delivery.
  local notify_reason=""
  case "$st_val" in
    idle) notify_reason="" ;;
    working | blocked) notify_reason="$st_val" ;;
    *) notify_reason="status unknown (not proven idle)" ;;
  esac

  if [ -n "$notify_reason" ]; then
    defer_notification "$route" "$machine" "$target" "$file" "$sha" \
      "$summary" "$content" "$corr" "$notify_reason"
    return 0
  fi

  if [ "$ready_val" = "false" ]; then
    defer_notification "$route" "$machine" "$target" "$file" "$sha" \
      "$summary" "$content" "$corr" "not interactively ready"
    return 0
  fi

  # A bounded prompt needs the bounded-execution helper. Without it there is
  # no safe way to prompt, so defer rather than risk an unbounded call.
  if ! command -v fm_run_timed >/dev/null 2>&1; then
    defer_notification "$route" "$machine" "$target" "$file" "$sha" \
      "$summary" "$content" "$corr" "the bounded-execution helper is unavailable"
    return 0
  fi

  # Recipient is idle and ready: immediate prompt submission
  local prompt_text
  if [ -n "$summary" ]; then
    prompt_text="Inbound communication waiting: $file ${corr:+[$corr]} | $summary"
  elif [ -n "$corr" ]; then
    prompt_text="Inbound communication waiting: $file [$corr]"
  else
    prompt_text="Inbound communication waiting: $file ($sha)"
  fi

  local -a herdr_cmd=(herdr)
  [ -z "$machine" ] || herdr_cmd=(herdr --machine "$machine")

  local prompt_out prompt_rc=0
  # REMOTE PROMPTS ARE REFUSED BY DEFAULT.
  # Measured 2026-10-16: `herdr --machine <remote> agent prompt` silently fell
  # back to the LOCAL machine when the remote target was not ready. On a host
  # whose only local agent pane is the Controller's own, that means outbound
  # secondmate text is delivered into the Controller's own session as if it were
  # inbound - a live instruction-injection surface, not just a lost message.
  # Delivering to a remote pane therefore requires an explicit opt-in, so the
  # unsafe path cannot be taken by an ordinary notification. The durable file
  # channel is unaffected and is what remote secondmates actually read.
  if [ -n "$machine" ] && [ "${FM_COMMS_ALLOW_REMOTE_PROMPT:-0}" != "1" ]; then
    printf 'notice: remote pane prompt refused for route %s (set FM_COMMS_ALLOW_REMOTE_PROMPT=1 to override); file preserved on disk\n' "$route" >&2
    return 0
  fi

  # No --wait here. `--wait` requires the recipient to show working/blocked
  # within 5000ms of submission, which a cold remote agent pane cannot do, so
  # the caller timeout expired and a message that HAD been submitted was
  # reported as never delivered. Delivery only needs the submission accepted;
  # `herdr agent prompt` already refuses a blocked agent before sending any
  # input, which is the safety property this step actually needs.
  # The prompt is BOUNDED. `herdr agent prompt` blocks until the submission is
  # accepted, and a pane whose real state is unknown never accepts it. Without
  # this bound the call waits forever, and when the caller is the comms ingest
  # it waits forever while HOLDING the receipts lock - which is exactly how
  # one unresponsive pane became a fleet-wide comms outage on 2026-10-21.
  if prompt_out=$(fm_run_timed "$FM_COMMS_NOTIFY_TIMEOUT_S" \
    "${herdr_cmd[@]}" agent prompt "$target" "$prompt_text" 2>&1); then
    printf '%s\t%s\t%s\t%s\tnotified\t%s\n' "$sha" "$route" "$file" "$(date +%s)" "$target" >> "$LEDGER"
    printf 'notified: %s (%s)\n' "$target" "$file"
    return 0
  else
    prompt_rc=$?
    printf 'notice: notification failed to reach %s; file preserved on disk\n' "$target" >&2
    [ -z "$prompt_out" ] || printf '%s\n' "$prompt_out" >&2
    if fm_timed_out "$prompt_rc"; then
      printf 'notice: the notification prompt exceeded its %ss bound and was abandoned; the reply file is preserved for the next poll\n' \
        "$FM_COMMS_NOTIFY_TIMEOUT_S" >&2
    fi
    return "$prompt_rc"
  fi
}

cmd_drain() {
  local route=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --route) route="$2"; shift 2 ;;
      -h|--help) usage ;;
      *) die "unknown option: $1" ;;
    esac
  done

  [ -d "$PENDING_BASE" ] || return 0

  local route_dir
  for route_dir in "$PENDING_BASE"/*; do
    [ -d "$route_dir" ] || continue
    local r_name
    r_name=$(basename "$route_dir")
    [ -z "$route" ] || [ "$route" = "$r_name" ] || continue

    local p_file prompt_out
    for p_file in "$route_dir"/*.pending; do
      [ -f "$p_file" ] || continue
      local p_route="" p_machine="" p_target="" p_file_name="" p_sha="" p_summary="" p_content="" p_corr=""
      while IFS='=' read -r k v; do
        case "$k" in
          route) p_route="$v" ;;
          machine) p_machine="$v" ;;
          target) p_target="$v" ;;
          file) p_file_name="$v" ;;
          sha) p_sha="$v" ;;
          summary) p_summary="$v" ;;
          content) p_content="$v" ;;
          corr) p_corr="$v" ;;
        esac
      done < "$p_file"
      [ -n "$p_summary" ] || p_summary="$p_content"

      # Re-resolve or re-check target status
      local st_line st_val ready_val notify_reason=""
      st_line=$(get_agent_status "$p_machine" "$p_target")
      st_val=$(printf '%s' "$st_line" | awk '{print $1}')
      ready_val=$(printf '%s' "$st_line" | awk '{print $2}')

      # Same gate as cmd_notify: ONLY a recipient PROVEN idle may be prompted.
      # The old drain gate deferred only on "working" or "blocked", so a status
      # of "unknown" - exactly what `herdr agent list` returning an empty list
      # produces - fell straight through to the prompt branch, and the prompt
      # was never accepted. A recipient whose state cannot be read is not a
      # recipient proven idle, so every status that is not an explicit "idle"
      # leaves the pending entry in place. The pending file is durable and the
      # message file is already on disk, so this costs latency and never
      # delivery.
      local notify_reason=""
      case "$st_val" in
        idle) notify_reason="" ;;
        working | blocked) notify_reason="$st_val" ;;
        *) notify_reason="status unknown (not proven idle)" ;;
      esac

      if [ -z "$notify_reason" ] && [ "$ready_val" = "false" ]; then
        notify_reason="not interactively ready"
      fi

      if [ -z "$notify_reason" ] && ! command -v fm_run_timed >/dev/null 2>&1; then
        notify_reason="the bounded-execution helper is unavailable"
      fi

      if [ -z "$notify_reason" ]; then
        local prompt_text
        if [ -n "$p_summary" ]; then
          prompt_text="Inbound communication waiting: $p_file_name ${p_corr:+[$p_corr]} | $p_summary"
        elif [ -n "$p_corr" ]; then
          prompt_text="Inbound communication waiting: $p_file_name [$p_corr]"
        else
          prompt_text="Inbound communication waiting: $p_file_name ($p_sha)"
        fi

        local -a herdr_cmd=(herdr)
        [ -z "$p_machine" ] || herdr_cmd=(herdr --machine "$p_machine")

        # BOUNDED for the same reason as cmd_notify: `herdr agent prompt`
        # blocks until the submission is accepted, and a pane whose real state
        # is unknown never accepts it. A drain that blocks forever strands
        # every pending notification behind it.
        if prompt_out=$(fm_run_timed "$FM_COMMS_NOTIFY_TIMEOUT_S" \
          "${herdr_cmd[@]}" agent prompt "$p_target" "$prompt_text" 2>&1); then
          printf '%s\t%s\t%s\t%s\tnotified\t%s\n' "$p_sha" "$p_route" "$p_file_name" "$(date +%s)" "$p_target" >> "$LEDGER"
          rm -f -- "$p_file"
          printf 'drained: %s (%s)\n' "$p_target" "$p_file_name"
        else
          printf 'notice: the drained notification to %s was not accepted; the pending entry is preserved\n' "$p_target" >&2
        fi
      fi
    done
  done
}

cmd_status() {
  printf 'LEDGER: %s\n' "$LEDGER"
  if [ -f "$LEDGER" ]; then
    cat "$LEDGER"
  else
    printf '(empty)\n'
  fi
  printf 'PENDING NOTIFICATIONS:\n'
  if [ -d "$PENDING_BASE" ]; then
    find "$PENDING_BASE" -type f -name '*.pending' 2>/dev/null || true
  else
    printf '(none)\n'
  fi
}

case "${1:-}" in
  notify) shift; cmd_notify "$@" ;;
  drain)  shift; cmd_drain "$@" ;;
  status) shift; cmd_status "$@" ;;
  -h|--help|help) usage ;;
  *) usage ;;
esac
