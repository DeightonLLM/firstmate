#!/usr/bin/env bash
# fm-next-board-chat.sh - the live board's Lavish ticket chat controller.
#
# The Captain's board is published by bin/fm-next-board-publish.py into
# data/next-board-publish/index.html. The board is also a conversation
# surface: a message the Captain writes there has to reach the agent as a
# wake, and the agent's answer has to land back where the Captain can see it.
#
# This script owns the Lavish half of that conversation. The pattern is the one
# the repo already uses in bin/lane-todo-dash.sh and bin/fm-lavish-enforcement.sh:
# lavish-axi opens the surface, and bin/fm-procevent-lavish.sh owns the poll's
# lifecycle, so a comment the Captain writes in the Lavish Conversation panel
# returns to the agent as a `procevent lavish <source-id> <sequence>` wake
# through the durable wake queue.
#
# The contract is docs/next-board-token-and-chat-contract.md, Contract B. That
# document is owned by the firstmate and is not edited here.
#
# Usage:
#   fm-next-board-chat.sh review            open or resume the session, arm the
#                                           chat-back source, record the session
#   fm-next-board-chat.sh reply [options]   deliver an agent reply into the
#                                           session and leave a board copy
#   fm-next-board-chat.sh end               end the session, retire the source
#   fm-next-board-chat.sh status            report the session and source truth
#   fm-next-board-chat.sh --help
#
# reply options:
#   --file PATH    take the reply body from PATH
#   --ticket ID    label the reply with a ticket id
#   -              read the reply body from stdin
#   MESSAGE        the reply body as one argument
#
# Truthfulness rules this script keeps:
#   * The artifact is the published board itself. Lavish keys a session on the
#     artifact's realpath, so the artifact is never copied, moved, symlinked
#     or re-pathed to run a session, and the source id is always derived from
#     the realpath the adapter derives it from.
#   * A session URL is only ever what lavish-axi actually returned. There is
#     no fallback URL, no synthesized session id, and no invented state.
#   * `status` reports what the tooling says, including "no session".
#   * Every command fails closed with a clear message instead of half-acting.
#   * Nothing is deleted by hand: the source is retired through the repo's own
#     procevent tooling, and the session record is marked, not removed.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# The repo root. The script lives in bin/ in the checkout and in
# data/next-board-publish/ in the installed runtime copy, so the root is
# derived from the script's own location rather than assumed.
resolve_root() {
  if [ -n "${FM_ROOT_OVERRIDE:-}" ]; then
    printf '%s\n' "$FM_ROOT_OVERRIDE"
    return 0
  fi
  case "${SELF_DIR##*/}" in
    next-board-publish) (cd "$SELF_DIR/../.." && pwd -P) ;;
    *) (cd "$SELF_DIR/.." && pwd -P) ;;
  esac
}

FM_ROOT="$(resolve_root)"
FM_HOME="${FM_HOME:-$FM_ROOT}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
export FM_HOME
export FM_STATE_OVERRIDE="$STATE"
export FM_ROOT_OVERRIDE="$FM_ROOT"

ADAPTER="$FM_ROOT/bin/fm-procevent-lavish.sh"
PROCEVENT="$FM_ROOT/bin/fm-procevent.sh"
SESSION_FILE="$STATE/next-board-session.json"
FEEDBACK_DIR="$STATE/next-board-feedback"
REPLIES_DIR="$FEEDBACK_DIR/replies"
SESSION_SCHEMA="firstmate-next-board-session/v1"

# The repo's own libraries own the wake queue, the claim files, the inbox
# layout, and the pid identity checks. This script never re-derives them.
if [ ! -f "$FM_ROOT/bin/fm-wake-lib.sh" ] || [ -L "$FM_ROOT/bin/fm-wake-lib.sh" ]; then
  printf 'error: missing required library: %s\n' "$FM_ROOT/bin/fm-wake-lib.sh" >&2
  exit 1
fi
# shellcheck source=bin/fm-wake-lib.sh
. "$FM_ROOT/bin/fm-wake-lib.sh"
if [ ! -f "$FM_ROOT/bin/fm-pr-lib.sh" ] || [ -L "$FM_ROOT/bin/fm-pr-lib.sh" ]; then
  printf 'error: missing required library: %s\n' "$FM_ROOT/bin/fm-pr-lib.sh" >&2
  exit 1
fi
# shellcheck source=bin/fm-pr-lib.sh
. "$FM_ROOT/bin/fm-pr-lib.sh"
if [ ! -f "$FM_ROOT/bin/fm-procevent-lib.sh" ] || [ -L "$FM_ROOT/bin/fm-procevent-lib.sh" ]; then
  printf 'error: missing required library: %s\n' "$FM_ROOT/bin/fm-procevent-lib.sh" >&2
  exit 1
fi
# shellcheck source=bin/fm-procevent-lib.sh
. "$FM_ROOT/bin/fm-procevent-lib.sh"

TMPDIR_SELF=""

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
fm-next-board-chat.sh - the live board's Lavish ticket chat controller

Usage:
  fm-next-board-chat.sh review            open or resume the Lavish session on
                                          the published board, arm the chat-back
                                          source, and record the session
  fm-next-board-chat.sh reply [options]   deliver an agent reply into the
                                          session and leave a board copy
  fm-next-board-chat.sh end               end the session and retire the source
  fm-next-board-chat.sh status            report the session and source truth
  fm-next-board-chat.sh --help            show this help

reply options:
  --file PATH    take the reply body from PATH
  --ticket ID    label the reply with a ticket id
  -              read the reply body from stdin
  MESSAGE        the reply body as one argument

The artifact is the published board itself:
  <repo>/data/next-board-publish/index.html
Its realpath is the Lavish source identity, so it is never copied, moved or
re-pathed to run a session. Override it with NEXT_BOARD_ARTIFACT only to point
at a different published board.

State:
  <state>/next-board-session.json            the recorded session
  <state>/next-board-feedback/replies/       the agent's own replies

review runs `lavish-axi <artifact>` and then `bin/fm-procevent-lavish.sh arm
<artifact>`, so a comment the Captain writes returns to the agent as a
`procevent lavish <source-id> <sequence>` wake. reply runs `lavish-axi reply
<artifact> --agent-reply-file <path>`. end runs `lavish-axi end <artifact>` and
then retires the registered source through the repo's own procevent tooling.
USAGE
}

# --- small helpers ----------------------------------------------------------

now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

now_stamp() {
  date -u +%Y%m%dT%H%M%SZ
}

file_mtime() {  # <path>
  stat -c %Y -- "$1" 2>/dev/null || stat -f %m -- "$1" 2>/dev/null
}

file_iso_time() {  # <path>
  local epoch
  epoch="$(file_mtime "$1")" || return 1
  case "$epoch" in
    ''|*[!0-9]*) return 1 ;;
  esac
  date -u -d "@$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
    || date -u -r "$epoch" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null
}

slugify() {  # <text>
  printf '%s' "$1" | LC_ALL=C tr -c 'A-Za-z0-9._-' '-' | sed -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//'
}

# JSON string escaping for the session record. Control characters are removed
# first so the result is always valid JSON.
json_escape() {
  local s
  s="$(printf '%s' "$1" | LC_ALL=C tr -d '\000-\010\013\014\016-\037')"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

json_string() {  # <value> -> a JSON string, or null when the value is empty
  if [ -z "$1" ]; then
    printf 'null'
    return 0
  fi
  printf '"%s"' "$(json_escape "$1")"
}

json_number_or_null() {  # <value>
  case "$1" in
    ''|*[!0-9]*) printf 'null' ;;
    *) printf '%s' "$1" ;;
  esac
}

json_bool() {  # <true|false>
  case "$1" in
    true) printf 'true' ;;
    *) printf 'false' ;;
  esac
}

# --- the artifact -----------------------------------------------------------

# The published board. One canonical path per home; the realpath is what
# Lavish keys the session on, so the path is never rewritten.
#
# The board belongs to the HOME. It is never taken from another home's
# checkout: the checkout root (FM_ROOT) can belong to a different home than
# FM_HOME, and a session keyed on that board would talk to the wrong home's
# surface. A home with no board of its own gets no board, not a neighbour's.
resolve_artifact() {
  if [ -n "${NEXT_BOARD_ARTIFACT:-}" ]; then
    printf '%s\n' "$NEXT_BOARD_ARTIFACT"
    return 0
  fi
  # The installed runtime copy sits beside the board it serves, so the board
  # next to this script counts - but only when that script lives inside the
  # home that is asking.
  if [ -f "$SELF_DIR/index.html" ]; then
    case "$SELF_DIR" in
      "$FM_HOME"|"$FM_HOME"/*)
        printf '%s\n' "$SELF_DIR/index.html"
        return 0
        ;;
    esac
  fi
  printf '%s\n' "$FM_HOME/data/next-board-publish/index.html"
}

artifact_realpath() {  # <artifact>
  perl -MCwd=realpath -e '$p = realpath($ARGV[0]); defined($p) or exit 1; print "$p\n"' "$1" 2>/dev/null
}

require_artifact() {  # <artifact>
  if [ ! -f "$1" ]; then
    die "no published board artifact at $1; the board publisher writes it (bin/fm-next-board-publish.py)"
  fi
}

require_lavish() {
  command -v lavish-axi >/dev/null 2>&1 \
    || die "lavish-axi is not installed"
}

require_adapter() {
  if [ ! -f "$ADAPTER" ] || [ -L "$ADAPTER" ]; then
    die "missing the Lavish process-to-event adapter: $ADAPTER"
  fi
}

# --- the session record -----------------------------------------------------

# Read one field from the recorded session. The file is written by this script
# in a fixed, one-field-per-line shape, so the read stays exact and never
# guesses a value it cannot see.
session_value() {  # <field>
  [ -f "$SESSION_FILE" ] || return 1
  awk -v field="$1" '
    BEGIN { pattern = "^[[:space:]]*\"" field "\":" }
    $0 ~ pattern {
      line = $0
      sub(pattern, "", line)
      sub(/^[[:space:]]+/, "", line)
      sub(/,$/, "", line)
      if (line == "null") { print ""; exit }
      if (line ~ /^".*"$/) {
        line = substr(line, 2, length(line) - 2)
        gsub(/\\"/, "\"", line)
        gsub(/\\\\/, "\\", line)
      }
      print line
      exit
    }
  ' "$SESSION_FILE"
}

# Write the session record. Every value is either what the tooling returned or
# null; nothing here is invented.
write_session() {  # <opened_at> <source_id> <session_id> <url> <artifact> <armed> <poll_pid> <last_result_at> <pending_results> <ended_at>
  local opened_at="$1" source_id="$2" session_id="$3" url="$4" artifact="$5" armed="$6"
  local poll_pid="$7" last_result_at="$8" pending_results="$9" ended_at="${10}"
  local tmp
  umask 077
  mkdir -p -- "$STATE" || return 1
  tmp="$(umask 077; mktemp "$STATE/.next-board-session.XXXXXX")" || return 1
  {
    printf '{\n'
    printf '  "schema": "%s",\n' "$SESSION_SCHEMA"
    printf '  "opened_at": %s,\n' "$(json_string "$opened_at")"
    printf '  "source_id": %s,\n' "$(json_string "$source_id")"
    printf '  "session_id": %s,\n' "$(json_string "$session_id")"
    printf '  "url": %s,\n' "$(json_string "$url")"
    printf '  "artifact": %s,\n' "$(json_string "$artifact")"
    printf '  "armed": %s,\n' "$(json_bool "$armed")"
    printf '  "poll_pid": %s,\n' "$(json_number_or_null "$poll_pid")"
    printf '  "last_result_at": %s,\n' "$(json_string "$last_result_at")"
    printf '  "pending_results": %s,\n' "$(json_number_or_null "$pending_results")"
    printf '  "ended_at": %s,\n' "$(json_string "$ended_at")"
    printf '  "updated_at": %s\n' "$(json_string "$(now_iso)")"
    printf '}\n'
  } > "$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$SESSION_FILE" || { rm -f -- "$tmp"; return 1; }
  return 0
}

# --- the source -------------------------------------------------------------

source_id_for() {  # <artifact>
  [ -f "$ADAPTER" ] || return 1
  "$ADAPTER" source-id "$1" 2>/dev/null
}

procevent_owner() {  # <source-id>
  local id="$1"
  [ -f "$PROCEVENT" ] || return 0
  bash "$PROCEVENT" list 2>/dev/null | awk -v id="$id" '$1 == id { print $3; exit }'
}

runner_pid() {  # <source-id>
  local id="$1" reg file
  reg="$(fm_procevent_registry_dir "$STATE")"
  file="$reg/$id.runner"
  [ -f "$file" ] && [ ! -L "$file" ] || return 0
  head -n 1 -- "$file" 2>/dev/null | tr -d '[:space:]'
}

pending_result_count() {  # <source-id>
  local id="$1" count=0 result
  while IFS= read -r result; do
    [ -n "$result" ] || continue
    case "${result##*/}" in
      "$id".*) count=$((count + 1)) ;;
    esac
  done < <(fm_procevent_pending "$STATE")
  printf '%s\n' "$count"
}

# The newest captured result for this source, and the newest one the agent has
# already been handed. Both are read from the durable inbox, so a restart
# between capture and handling still shows the truth.
result_times() {  # <source-id>
  local id="$1" inbox file base seq newest_seq="" newest_at="" delivered_seq="" delivered_at=""
  inbox="$(fm_procevent_inbox_dir "$STATE")"
  [ -d "$inbox" ] || { printf '%s\t%s\t%s\t%s\n' "" "" "" ""; return 0; }
  for file in "$inbox/$id".*.result; do
    [ -f "$file" ] && [ ! -L "$file" ] || continue
    base="${file%.result}"
    seq="${base##*.}"
    case "$seq" in ''|*[!0-9]*) continue ;; esac
    if [ -z "$newest_seq" ] || [ "$seq" -gt "$newest_seq" ]; then
      newest_seq="$seq"
      newest_at="$(file_iso_time "$file" || true)"
    fi
    if [ -f "${file%.result}.handled" ] && { [ -z "$delivered_seq" ] || [ "$seq" -gt "$delivered_seq" ]; }; then
      delivered_seq="$seq"
      delivered_at="$(file_iso_time "${file%.result}.handled" || true)"
    fi
  done
  printf '%s\t%s\t%s\t%s\n' "$newest_seq" "$newest_at" "$delivered_seq" "$delivered_at"
}

# --- lavish calls -----------------------------------------------------------

run_lavish_open() {  # <artifact> -> the tool's own output
  local artifact="$1" out rc
  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout 120 lavish-axi "$artifact" 2>&1)"
    rc=$?
  else
    out="$(lavish-axi "$artifact" 2>&1)"
    rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    [ -z "$out" ] || printf '%s\n' "$out" >&2
    printf 'error: lavish-axi could not open the board session (exit %s)\n' "$rc" >&2
    return 1
  fi
  printf '%s\n' "$out"
  return 0
}

run_lavish_reply() {  # <artifact> <body-file>
  local artifact="$1" body="$2" out rc
  out="$(lavish-axi reply "$artifact" --agent-reply-file "$body" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    [ -z "$out" ] || printf '%s\n' "$out" >&2
    printf 'error: lavish-axi did not accept the reply (exit %s)\n' "$rc" >&2
    return 1
  fi
  [ -z "$out" ] || printf '%s\n' "$out"
  return 0
}

run_lavish_end() {  # <artifact>
  local artifact="$1" out rc
  out="$(lavish-axi end "$artifact" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    [ -z "$out" ] || printf '%s\n' "$out" >&2
    printf 'error: lavish-axi could not end the board session (exit %s)\n' "$rc" >&2
    return 1
  fi
  [ -z "$out" ] || printf '%s\n' "$out"
  return 0
}

# --- the commands -----------------------------------------------------------

cmd_review() {
  local artifact output session_id url source_id arm_output poll_pid pending last_at opened_at real
  artifact="$(resolve_artifact)"
  require_artifact "$artifact"
  require_lavish
  require_adapter
  real="$(artifact_realpath "$artifact")" \
    || die "cannot resolve the board artifact path: $artifact"

  output="$(run_lavish_open "$artifact")" || return 1
  session_id="$(printf '%s\n' "$output" | parse_session_id)"
  url="$(printf '%s\n' "$output" | parse_session_url)"

  arm_output="$("$ADAPTER" arm "$artifact" 2>&1)" || {
    printf '%s\n' "$arm_output" >&2
    die "could not arm the chat-back source"
  }
  source_id="$(printf '%s\n' "$arm_output" | sed -n 's/^armed:[[:space:]]*//p' | head -1)"
  [ -n "$source_id" ] || source_id="$(source_id_for "$artifact")"

  poll_pid="$(runner_pid "$source_id")"
  pending="$(pending_result_count "$source_id")"
  last_at="$(result_times "$source_id" | cut -f2)"
  opened_at="$(now_iso)"

  write_session "$opened_at" "$source_id" "$session_id" "$url" "$real" "true" \
    "$poll_pid" "$last_at" "$pending" "" \
    || die "cannot record the session"

  printf 'opened: %s\n' "${url:-session opened, lavish-axi returned no URL}"
  printf 'session id: %s\n' "${session_id:-none}"
  printf 'source id: %s\n' "${source_id:-unknown}"
  printf 'artifact: %s\n' "$real"
  printf 'armed: true\n'
  return 0
}

cmd_reply() {
  local artifact body_file ticket="" source="" message="" tmpdir output
  artifact="$(resolve_artifact)"
  require_artifact "$artifact"
  require_lavish

  if [ ! -f "$SESSION_FILE" ]; then
    die "no board chat session is recorded; run review first"
  fi
  if [ -n "$(session_value ended_at || true)" ]; then
    die "the board chat session was ended at $(session_value ended_at); run review to open a new one"
  fi

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --file)
        [ "$#" -ge 2 ] || die "--file needs a path"
        source="file:$2"
        shift 2
        ;;
      --ticket)
        [ "$#" -ge 2 ] || die "--ticket needs a ticket id"
        ticket="$2"
        shift 2
        ;;
      -)
        source="stdin"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        message="$*"
        shift
        break
        ;;
    esac
  done

  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/fm-next-board-chat.XXXXXX")" \
    || die "cannot create a temporary directory for the reply body"
  TMPDIR_SELF="$tmpdir"
  # shellcheck disable=SC2329 # Invoked by the EXIT trap below, not by name.
  trap 'purge_tmp' EXIT
  body_file="$tmpdir/body.md"
  umask 077
  case "$source" in
    file:*)
      source="${source#file:}"
      if [ ! -f "$source" ] || [ -L "$source" ]; then
        die "the reply body is not a readable regular file: $source"
      fi
      cat -- "$source" > "$body_file" || die "cannot read the reply body: $source"
      ;;
    stdin)
      cat > "$body_file" || die "cannot read the reply body from stdin"
      ;;
    *)
      printf '%s\n' "$message" > "$body_file" || die "cannot write the reply body"
      ;;
  esac
  if [ ! -s "$body_file" ]; then
    die "the reply body is empty"
  fi

  output="$(run_lavish_reply "$artifact" "$body_file")" || return 1
  [ -z "$output" ] || printf '%s\n' "$output"

  write_reply_copy "$body_file" "$ticket" || return 1
  printf 'delivered: %s\n' "$artifact"
  printf 'reply copy: %s\n' "$REPLY_COPY_PATH"
  return 0
}

# The board copy of the agent's reply. The shape mirrors the inbound feedback
# file exactly - the same heading, the same metadata lines, the same quoted
# body - so the board renders an inbound message and an agent reply with one
# reader. The directory and the `- Source:` line say which is which.
REPLY_COPY_PATH=""
write_reply_copy() {  # <body-file> <ticket>
  local body="$1" ticket="$2" stamp slug dest tmp
  REPLY_COPY_PATH=""
  umask 077
  mkdir -p -- "$REPLIES_DIR" || die "cannot create the reply directory: $REPLIES_DIR"
  chmod 700 -- "$REPLIES_DIR" 2>/dev/null || true
  stamp="$(now_stamp)"
  slug="reply"
  if [ -n "$ticket" ]; then
    slug="reply-$(slugify "$ticket")"
  fi
  dest="$REPLIES_DIR/$stamp-$slug.md"
  tmp="$(umask 077; mktemp "$REPLIES_DIR/.reply.XXXXXX")" || die "cannot stage the reply copy"
  {
    printf '# Board reply\n\n'
    printf -- '- Timestamp: %s\n' "$(now_iso)"
    printf -- '- Ticket: %s\n' "${ticket:-none}"
    printf -- '- Source: agent\n\n'
    printf '## Comment\n\n'
    while IFS= read -r line || [ -n "$line" ]; do
      printf '> %s\n' "$line"
    done < "$body"
  } > "$tmp" || { rm -f -- "$tmp"; die "cannot write the reply copy"; }
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; die "cannot secure the reply copy"; }
  mv -f -- "$tmp" "$dest" || { rm -f -- "$tmp"; die "cannot publish the reply copy"; }
  REPLY_COPY_PATH="$dest"
  return 0
}

cmd_end() {
  local artifact source_id retire_output ended rc=0
  artifact="$(resolve_artifact)"
  require_artifact "$artifact"
  require_lavish
  require_adapter

  if [ -f "$SESSION_FILE" ]; then
    if ! run_lavish_end "$artifact"; then
      rc=1
    fi
  else
    printf 'no board chat session is recorded; nothing to end\n'
  fi

  # Retire the registered source through the repo's own procevent tooling. The
  # source id is derived from the board artifact, so this can never touch
  # another board's or another session's registration.
  source_id="$(source_id_for "$artifact" || true)"
  if [ -n "$source_id" ]; then
    retire_output="$("$ADAPTER" retire "$artifact" 2>&1)" || {
      printf '%s\n' "$retire_output" >&2
      die "could not retire the registered source"
    }
    printf '%s\n' "$retire_output"
  fi

  if [ -f "$SESSION_FILE" ]; then
    mark_session_ended
  fi
  return "$rc"
}

mark_session_ended() {
  local opened_at source_id session_id url artifact armed poll_pid last_at pending ended
  opened_at="$(session_value opened_at || true)"
  source_id="$(session_value source_id || true)"
  session_id="$(session_value session_id || true)"
  url="$(session_value url || true)"
  artifact="$(session_value artifact || true)"
  armed="$(session_value armed || true)"
  poll_pid="$(session_value poll_pid || true)"
  last_at="$(session_value last_result_at || true)"
  pending="$(session_value pending_results || true)"
  ended="$(now_iso)"
  write_session "$opened_at" "$source_id" "$session_id" "$url" "$artifact" "false" \
    "" "$last_at" "$pending" "$ended" \
    || die "cannot record the ended session"
}

cmd_status() {
  local artifact source_id session_id url owner poll_pid pending times newest_seq newest_at delivered_seq delivered_at
  local has_session=false ended opened_at armed
  artifact="$(resolve_artifact)"

  if [ -f "$SESSION_FILE" ]; then
    has_session=true
    session_id="$(session_value session_id || true)"
    url="$(session_value url || true)"
    opened_at="$(session_value opened_at || true)"
    ended="$(session_value ended_at || true)"
    armed="$(session_value armed || true)"
  else
    session_id=""
    url=""
    opened_at=""
    ended=""
    armed=""
  fi

  if [ -f "$artifact" ]; then
    source_id="$(source_id_for "$artifact" || true)"
  else
    source_id=""
  fi

  owner=""
  poll_pid=""
  pending=0
  if [ -n "$source_id" ]; then
    owner="$(procevent_owner "$source_id")"
    poll_pid="$(runner_pid "$source_id")"
    pending="$(pending_result_count "$source_id")"
  fi
  times="$(result_times "${source_id:-none}")"
  newest_seq="$(printf '%s\n' "$times" | cut -f1)"
  newest_at="$(printf '%s\n' "$times" | cut -f2)"
  delivered_seq="$(printf '%s\n' "$times" | cut -f3)"
  delivered_at="$(printf '%s\n' "$times" | cut -f4)"

  printf 'source id: %s\n' "${source_id:-unknown}"
  printf 'artifact: %s\n' "$artifact"
  if [ "$has_session" = false ]; then
    printf 'session: none\n'
  elif [ -n "$ended" ]; then
    printf 'session: ended\n'
  else
    printf 'session: open\n'
  fi
  printf 'session id: %s\n' "${session_id:-none}"
  printf 'session url: %s\n' "${url:-none}"
  printf 'armed: %s\n' "${armed:-false}"
  printf 'poll runner: %s\n' "$(runner_state "$owner" "$poll_pid")"
  printf 'pending results: %s\n' "$pending"
  if [ -n "$delivered_seq" ]; then
    printf 'last delivery: %s (seq %s)\n' "${delivered_at:-unknown}" "$delivered_seq"
  else
    printf 'last delivery: none\n'
  fi
  if [ -n "$newest_seq" ]; then
    printf 'last result: %s (seq %s)\n' "${newest_at:-unknown}" "$newest_seq"
  else
    printf 'last result: none\n'
  fi
  if [ -n "$opened_at" ]; then
    printf 'opened at: %s\n' "$opened_at"
  fi
  if [ -n "$ended" ]; then
    printf 'ended at: %s\n' "$ended"
  fi
  return 0
}

runner_state() {  # <owner> <poll-pid>
  local owner="$1" pid="$2"
  case "$owner" in
    live)
      if [ -n "$pid" ]; then
        printf 'alive (pid %s)\n' "$pid"
      else
        printf 'alive\n'
      fi
      ;;
    none) printf 'not running\n' ;;
    orphaned) printf 'orphaned (leader gone, poll group still alive)\n' ;;
    uncertain) printf 'uncertain\n' ;;
    '') printf 'not registered\n' ;;
    *) printf '%s\n' "$owner" ;;
  esac
}

# --- parsers ----------------------------------------------------------------

parse_session_url() {
  local url
  url="$(grep -oE 'https?://[^[:space:]"<>)]+/session/[A-Za-z0-9_-]+' | head -1)"
  [ -n "$url" ] || return 0
  url="${url%,}"
  url="${url%.}"
  url="${url%;}"
  url="${url%:}"
  printf '%s\n' "$url"
}

parse_session_id() {
  local id
  id="$(grep -oE '/session/[A-Za-z0-9_-]+' | head -1 | sed 's|^/session/||')"
  if [ -z "$id" ]; then
    id="$(grep -oiE 'session[_ -]?id[[:space:]]*[:=][[:space:]]*[A-Za-z0-9_-]+' | head -1 \
      | sed -E 's/.*[:=][[:space:]]*//')"
  fi
  printf '%s\n' "$id"
}

# --- scratch ----------------------------------------------------------------

purge_tmp() {
  if [ -n "${TMPDIR_SELF:-}" ] && [ -d "$TMPDIR_SELF" ]; then
    if command -v fm_purge_scratch >/dev/null 2>&1; then
      fm_purge_scratch "$TMPDIR_SELF" 2>/dev/null || true
    else
      rm -rf -- "$TMPDIR_SELF" 2>/dev/null || true
    fi
    TMPDIR_SELF=""
  fi
}

# --- dispatch ---------------------------------------------------------------

case "${1:-}" in
  review) shift; cmd_review "$@" ;;
  reply)  shift; cmd_reply "$@" ;;
  end)    shift; cmd_end "$@" ;;
  status) shift; cmd_status "$@" ;;
  --help|-h|help) usage ;;
  '') usage; exit 2 ;;
  *) printf 'error: unknown command: %s\n' "$1" >&2; usage; exit 2 ;;
esac
