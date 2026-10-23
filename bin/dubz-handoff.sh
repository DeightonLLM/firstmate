#!/usr/bin/env bash
# dubz-handoff — a real message channel between the fleet and the Captain.
#
# Purpose: the Captain talks to an external team (the P.K. team) by hand, so the
# fleet needs a place to hand him finished, copy-pasteable messages, a way to
# know what he has already forwarded, and an audit trail. This is that place.
#
# Design rules (do not break them):
#   * One writer per file. A message body is immutable once written; a change is
#     a NEW message that carries `reply-to:`.
#   * Every write is atomic: content goes to a .part file, then rename(2).
#   * Never prompt. Every command is non-interactive and takes flags only.
#   * Never delete. `consume` and `send` MOVE a message into an archive folder.
#   * index.tsv is a cache. `index` rebuilds it from the folders, so a corrupted
#     index is never a data-loss event.
#
# Usage:
#   dubz-handoff.sh post   --dir inbox|outbox --title T --to X --from Y \
#                           [--reply-to ID] --body-file PATH
#   dubz-handoff.sh list   [--dir inbox|outbox|sent|consumed|legacy] [--status S]
#   dubz-handoff.sh read   ID
#   dubz-handoff.sh send   ID        # Captain forwarded it onward -> sent/
#   dubz-handoff.sh consume ID       # fleet picked it up        -> consumed/
#   dubz-handoff.sh index             # rebuild index.tsv from the folders
#   dubz-handoff.sh doctor            # layout, perms, drift, stale messages
set -uo pipefail

ROOT="${DUBZ_HANDOFF_ROOT:-/root/dubz-handoff}"
BIN_DIR="$ROOT/bin"
INBOX="$ROOT/inbox"
OUTBOX="$ROOT/outbox"
SENT="$ROOT/sent"
CONSUMED="$ROOT/consumed"
LEGACY="$ROOT/legacy"
TEMPLATES="$ROOT/templates"
LOG="$ROOT/log/actions.log"
INDEX="$ROOT/index.tsv"
LOCK="$ROOT/.index.lock"

SUBDIRS=("$INBOX" "$OUTBOX" "$SENT" "$CONSUMED" "$LEGACY" "$TEMPLATES")

die() { printf 'dubz-handoff: %s\n' "$*" >&2; exit 1; }
note() { printf '%s\n' "$*"; }

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }
stamp_utc() { date -u +%Y%m%dT%H%M%SZ; }

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-48
}

rand4() {
  if [ -r /dev/urandom ]; then
    od -An -N2 -tx1 /dev/urandom | tr -d ' \n' | cut -c1-4
  else
    printf '%04d' "$(( ($$ + $(date -u +%s) ) % 65536 ))"
  fi
}

ensure_layout() {
  local d
  for d in "$ROOT" "$BIN_DIR" "$INBOX" "$OUTBOX" "$SENT" "$CONSUMED" "$LEGACY" "$TEMPLATES" "$(dirname "$LOG")"; do
    [ -d "$d" ] || mkdir -p "$d" || die "cannot create $d"
  done
  [ -f "$INDEX" ] || : > "$INDEX"
  [ -f "$LOG" ] || : > "$LOG"
  chmod 700 "$ROOT" 2>/dev/null || true
  chmod 750 "$BIN_DIR" "$INBOX" "$OUTBOX" "$SENT" "$CONSUMED" "$LEGACY" "$TEMPLATES" 2>/dev/null || true
}

log_action() {
  local verb=$1 detail=$2
  printf '%s\t%s\t%s\n' "$(now_utc)" "$verb" "$detail" >> "$LOG"
}

# ---------------------------------------------------------------- post ----
cmd_post() {
  local dir="" title="" to="" from="" reply_to="" body_file="" id=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) dir=${2:-}; shift 2 ;;
      --title) title=${2:-}; shift 2 ;;
      --to) to=${2:-}; shift 2 ;;
      --from) from=${2:-}; shift 2 ;;
      --reply-to) reply_to=${2:-}; shift 2 ;;
      --body-file) body_file=${2:-}; shift 2 ;;
      --id) id=${2:-}; shift 2 ;;
      *) die "unknown flag for post: $1" ;;
    esac
  done
  [ -n "$dir" ] || die "post needs --dir (inbox or outbox)"
  case "$dir" in
    inbox|outbox) ;;
    *) die "--dir must be inbox or outbox (use send/consume to move a message afterwards)" ;;
  esac
  [ -n "$title" ] || die "post needs --title"
  [ -n "$to" ] || die "post needs --to"
  [ -n "$from" ] || die "post needs --from"
  [ -f "$body_file" ] || die "body file not found: $body_file"

  local target_dir="$ROOT/$dir"
  [ -d "$target_dir" ] || mkdir -p "$target_dir"

  if [ -z "$id" ]; then
    id="msg-$(stamp_utc)-$(slugify "$title")-$(rand4)"
  fi
  local final="$target_dir/$id.md"
  [ -e "$final" ] && die "message already exists: $final"

  local body_sha
  body_sha=$(sha256sum "$body_file" | cut -d' ' -f1)

  local part="$target_dir/.${id}.part"
  {
    printf -- '---\n'
    printf 'id: %s\n' "$id"
    printf 'posted: %s\n' "$(now_utc)"
    printf 'posted-by: %s\n' "$from"
    printf 'to: %s\n' "$to"
    printf 'subject: %s\n' "$title"
    printf 'status: new\n'
    printf 'reply-to: %s\n' "${reply_to:-none}"
    printf 'body-sha256: %s\n' "$body_sha"
    printf -- '---\n\n'
    cat "$body_file"
  } > "$part" || { rm -f "$part"; die "could not stage message"; }
  chmod 640 "$part" 2>/dev/null || true
  mv -f "$part" "$final" || { rm -f "$part"; die "could not commit message"; }

  index_add "$id" "$dir" "new" "$title" "$final"
  log_action post "$id dir=$dir to=$to"
  note "$id"
  note "$final"
}

# ---------------------------------------------------------------- index ---
index_add() {  # id dir status title file
  local id=$1 dir=$2 status=$3 title=$4 file=$5
  local lock_fd
  exec {lock_fd}>>"$LOCK" 2>/dev/null || true
  flock -w 10 "$LOCK" 2>/dev/null || true
  {
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$dir" "$status" "$(now_utc)" "$title" "$file"
  } >> "$INDEX"
  [ -n "${lock_fd:-}" ] && exec {lock_fd}>&- 2>/dev/null
  return 0
}

index_set_status() {  # id status
  local id=$1 status=$2
  local tmp="$INDEX.tmp.$$"
  [ -f "$INDEX" ] || return 0
  awk -F'\t' -v OFS='\t' -v id="$id" -v st="$status" \
    'BEGIN{done=0} $1==id && !done {$3=st; done=1} {print}' "$INDEX" > "$tmp" 2>/dev/null \
    && mv -f "$tmp" "$INDEX"
  return 0
}

cmd_index() {
  local tmp="$INDEX.tmp.$$"
  : > "$tmp"
  local d id
  for d in inbox outbox sent consumed; do
    local dir="$ROOT/$d"
    [ -d "$dir" ] || continue
    for f in "$dir"/*.md; do
      [ -f "$f" ] || continue
      id=$(basename "$f" .md)
      local title status posted
      title=$(awk -F': ' '/^subject: /{sub(/^subject: /,""); print; exit}' "$f")
      status=$(awk -F': ' '/^status: /{sub(/^status: /,""); print; exit}' "$f")
      posted=$(awk -F': ' '/^posted: /{sub(/^posted: /,""); print; exit}' "$f")
      [ -n "$status" ] || status=new
      [ -n "$posted" ] || posted=unknown
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$d" "$status" "$posted" "$title" "$f" >> "$tmp"
    done
  done
  mv -f "$tmp" "$INDEX"
  log_action index "rebuilt $INDEX"
  note "rebuilt $INDEX"
}

# ----------------------------------------------------------------- list ---
cmd_list() {
  local dir="" status=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir) dir=${2:-}; shift 2 ;;
      --status) status=${2:-}; shift 2 ;;
      *) die "unknown flag for list: $1" ;;
    esac
  done
  [ -f "$INDEX" ] || cmd_index >/dev/null
  local line
  printf 'ID\tDIR\tSTATUS\tPOSTED\tTITLE\n'
  while IFS=$'\t' read -r id d st posted title file; do
    [ "${id:-}" = "ID" ] && continue
    [ -n "$id" ] || continue
    if [ -n "$dir" ] && [ "$d" != "$dir" ]; then continue; fi
    if [ -n "$status" ] && [ "$st" != "$status" ]; then continue; fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$d" "$st" "$posted" "$title"
  done < "$INDEX"
  unset line
}

# ----------------------------------------------------------------- read ---
cmd_read() {
  local id=${1:-}
  [ -n "$id" ] || die "read needs a message id"
  local d
  for d in inbox outbox sent consumed legacy; do
    if [ -f "$ROOT/$d/$id.md" ]; then
      cat "$ROOT/$d/$id.md"
      return 0
    fi
  done
  die "no such message: $id"
}

# ------------------------------------------------------------ send/consume
cmd_send() {
  local id=${1:-}
  [ -n "$id" ] || die "send needs a message id"
  [ -f "$INBOX/$id.md" ] || die "not a pending inbox message: $id"
  mv -f "$INBOX/$id.md" "$SENT/$id.md" || die "could not move to sent/"
  index_set_status "$id" "sent"
  log_action send "$id"
  note "$id -> sent"
}

cmd_consume() {
  local id=${1:-}
  [ -n "$id" ] || die "consume needs a message id"
  [ -f "$OUTBOX/$id.md" ] || die "not a pending outbox message: $id"
  mv -f "$OUTBOX/$id.md" "$CONSUMED/$id.md" || die "could not move to consumed/"
  index_set_status "$id" "consumed"
  log_action consume "$id"
  note "$id -> consumed"
}

# --------------------------------------------------------------- doctor ---
cmd_doctor() {
  local problems=0 d
  note "== layout =="
  for d in "$ROOT" "$INBOX" "$OUTBOX" "$SENT" "$CONSUMED" "$LEGACY" "$TEMPLATES"; do
    if [ -d "$d" ]; then
      note "ok   dir  $d"
    else
      note "MISS dir  $d"
      problems=$((problems + 1))
    fi
  done
  for f in "$INDEX" "$LOG"; do
    if [ -f "$f" ]; then note "ok   file $f"; else note "MISS file $f"; problems=$((problems + 1)); fi
  done

  note ""
  note "== staged .part leftovers (a crash mid-write) =="
  local leftovers
  leftovers=$(find "$ROOT" -maxdepth 2 -name ".*.part" 2>/dev/null | head -20)
  if [ -n "$leftovers" ]; then
    printf '%s\n' "$leftovers"
    problems=$((problems + 1))
  else
    note "none"
  fi

  note ""
  note "== index vs folders =="
  local tmp="$ROOT/.doctor-index.$$"
  cmd_index >/dev/null 2>&1
  [ -f "$INDEX" ] && cp -f "$INDEX" "$tmp" 2>/dev/null
  local id d st posted title file missing=0
  while IFS=$'\t' read -r id d st posted title file; do
    [ -n "$id" ] || continue
    [ "$id" = "ID" ] && continue
    if [ ! -f "$file" ]; then
      note "MISS file for $id ($file)"
      missing=$((missing + 1))
      problems=$((problems + 1))
    fi
  done < "$tmp"
  [ "$missing" -eq 0 ] && note "every indexed message has a file"
  rm -f "$tmp" 2>/dev/null

  note ""
  note "== pending age =="
  local old
  old=$(find "$INBOX" "$OUTBOX" -maxdepth 1 -name "*.md" -mtime +2 2>/dev/null | head -20)
  if [ -n "$old" ]; then
    printf '%s\n' "$old"
    note "these have been waiting more than 48 hours"
  else
    note "nothing pending for more than 48 hours"
  fi

  note ""
  if [ "$problems" -eq 0 ]; then
    note "doctor: PASS"
    exit 0
  fi
  note "doctor: FAIL ($problems problem(s))"
  exit 1
}

# ------------------------------------------------------------------ main ---
main() {
  local cmd=${1:-}
  [ $# -gt 0 ] && shift
  case "$cmd" in
    post) ensure_layout; cmd_post "$@" ;;
    list) ensure_layout; cmd_list "$@" ;;
    read) ensure_layout; cmd_read "$@" ;;
    send) ensure_layout; cmd_send "$@" ;;
    consume) ensure_layout; cmd_consume "$@" ;;
    index) ensure_layout; cmd_index "$@" ;;
    doctor) ensure_layout; cmd_doctor "$@" ;;
    ""|-h|--help|help) sed -n '2,25p' "$0" ;;
    *) die "unknown command: $cmd (try --help)" ;;
  esac
}

main "$@"
