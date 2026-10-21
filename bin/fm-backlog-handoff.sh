#!/usr/bin/env bash
# Hand already-identified, in-scope backlog items off from the main firstmate
# backlog to a secondmate's own home backlog. Use this when a secondmate is
# created (or whenever an existing queued item should become its domain's work)
# so the secondmate owns its queue from day one instead of the item staying
# stranded in the main backlog.
#
# Scope-matching is firstmate's JUDGMENT: you pass the task-id keys you have
# already judged in-scope for the secondmate. This script performs only the
# fleet-level validation that the backlog backend cannot know, then DELEGATES
# the actual item move to `tasks-axi mv`, the single owner of the backlog
# format. Delegating the move is the durability end-state: it removes the awk
# that used to re-implement block extraction and insertion here, so the format
# has exactly one parser and cannot drift out of sync (the body-orphaning class
# of bug fixed in PR #401 was exactly that drift).
#
# What this script still owns (never delegated):
#   - resolving the secondmate home from data/secondmates.md;
#   - proving the destination is a genuine seeded secondmate home
#     (.fm-secondmate-home marker, AGENTS.md + bin/), never a project clone, the
#     active home, or the firstmate repo;
#   - moving only `## Queued` items, refusing `## In flight` and historical
#     `## Done` records, which must stay with their home for pruning or
#     archiving;
#   - the multi-key classification and idempotent per-key reporting against
#     BOTH backlogs: a key the main backlog no longer holds is already done, a
#     key the main backlog still holds is handed off, and if any key matches
#     neither backlog nothing is moved.
#
# What `tasks-axi mv <id>... --to <dest>` owns: moving each full item BLOCK
# byte-exact (header, body lines, blank separators, and indented pseudo-headings
# such as `  ## Intent`), preserving destination section placement, and moving a
# whole connected set (a blocker and its dependents) atomically with blocked-by
# links preserved. It refuses a move that would strand a dependency across the
# two files; that error is surfaced verbatim and nothing is moved. It also
# refuses an id that already exists in the destination backlog, so a
# destination copy that has to be replaced is removed with `tasks-axi rm`
# before the current main copy is moved into its place.
#
# The desired end state of a handoff is that the item is in the secondmate's
# backlog and NOT in the main backlog, so every key is classified against BOTH
# backlogs and the copy that is in the main backlog is always the one that
# decides:
#   - the main backlog holds the key in `## Queued` and the destination does
#     not hold it at all: move it;
#   - the main backlog holds the key in `## Queued` and the destination holds a
#     copy that DIFFERS: that destination copy is stale, so it is replaced by
#     the current main copy and the main copy leaves the main backlog;
#   - the main backlog holds the key in `## Queued` and the destination holds
#     an IDENTICAL copy: the handoff is half done, so it is completed - the
#     item ends up out of the main backlog and retained in the destination;
#   - the main backlog does not hold the key and the destination does: the
#     handoff is already done, so it is reported and nothing moves;
#   - the main backlog holds the key in `## In flight` or `## Done`: refused,
#     whatever the destination holds.
# "Already present" used to mean only "the key is in the destination", so a
# destination holding an older revision of the item was reported as already
# handed off while the current main copy stayed in the main backlog and
# nothing moved at all, and a key held by both backlogs was never taken out of
# the main backlog at all. The destination copy is now compared with the main
# copy, item block by item block. The comparison ignores trailing whitespace,
# so a whitespace-only difference never reads as staleness while a genuinely
# different body always does.
#
# The ITEM BLOCK of a key is its header line plus every following line that is
# blank or indented (the body, the blank separators between paragraphs, and
# the indented pseudo-headings such as `  ## Intent`), stopping at the first
# line that is neither blank nor indented, which is the next item header or
# the next column-0 section heading. Only a column-0 `##` heading is a section
# boundary, so an indented `  ## Intent` stays body.
#
# Item bodies must use at least two leading spaces. The helper refuses a selected
# item with a single-space or tab-indented continuation rather than risk leaving
# it orphaned, because tasks-axi treats only two-or-more-space lines as body.
# The move needs compatible `tasks-axi` on PATH, including atomic multi-ID `mv`
# (introduced in 0.2.2). Bootstrap requires it fleet-wide, so this works
# everywhere; the `config/backlog-backend=manual` knob only governs firstmate's
# own hand-editing of its own backlog, not this validated helper. Idempotent:
# re-running converges. Atomic: on any move failure nothing moves.
# See AGENTS.md project management and task lifecycle.
# Usage: fm-backlog-handoff.sh <secondmate-id> <item-key>...
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
REG="$DATA/secondmates.md"
MAIN_BACKLOG="$DATA/backlog.md"
# shellcheck source=bin/fm-tasks-axi-lib.sh disable=SC1091
. "$SCRIPT_DIR/fm-tasks-axi-lib.sh"
# shellcheck source=bin/fm-secondmate-registry-lib.sh
. "$SCRIPT_DIR/fm-secondmate-registry-lib.sh"

[ $# -ge 2 ] || { echo "usage: fm-backlog-handoff.sh <secondmate-id> <item-key>..." >&2; exit 1; }
ID=$1
shift

secondmate_home() {
  local id=$1 home
  [ -f "$REG" ] || { echo "error: no secondmate registry at $REG" >&2; return 1; }
  home=$(secondmate_registry_field "$REG" "$id" home || true)
  [ -n "$home" ] || { echo "error: secondmate $id has no home in $REG" >&2; return 1; }
  printf '%s\n' "$home"
}

path_is_ancestor_of() {
  local ancestor=$1 path=$2
  [ -n "$ancestor" ] || return 1
  [ -n "$path" ] || return 1
  [ "$ancestor" != "$path" ] || return 1
  case "$path" in
    "$ancestor"/*) return 0 ;;
  esac
  return 1
}

resolved_existing_dir() {
  local path=$1
  [ -d "$path" ] || { echo "error: firstmate home does not exist or is not a directory: $path" >&2; return 1; }
  cd "$path" && pwd -P
}

validate_operational_dirs() {
  local abs_home=$1 abs_active_home=$2 abs_root=$3 name dir abs_dir
  for name in data state config projects; do
    dir="$abs_home/$name"
    if [ -L "$dir" ] && [ ! -e "$dir" ]; then
      echo "error: secondmate $name directory must resolve inside the secondmate home: $dir" >&2
      return 1
    fi
    if [ -d "$dir" ]; then
      abs_dir=$(cd "$dir" && pwd -P)
    elif [ -e "$dir" ]; then
      echo "error: secondmate $name path is not a directory: $dir" >&2
      return 1
    else
      abs_dir="$abs_home/$name"
    fi
    if ! path_is_ancestor_of "$abs_home" "$abs_dir"; then
      echo "error: secondmate $name directory must resolve inside the secondmate home: $dir" >&2
      return 1
    fi
    if [ "$abs_dir" = "$abs_active_home" ] || path_is_ancestor_of "$abs_active_home" "$abs_dir"; then
      echo "error: secondmate $name directory cannot be inside the active firstmate home: $dir" >&2
      return 1
    fi
    if [ "$abs_dir" = "$abs_root" ] || path_is_ancestor_of "$abs_root" "$abs_dir"; then
      echo "error: secondmate $name directory cannot be inside the firstmate repo: $dir" >&2
      return 1
    fi
  done
}

validate_secondmate_home() {
  local id=$1 home=$2 abs_home abs_active_home abs_root marker_id
  abs_home=$(resolved_existing_dir "$home") || return 1
  abs_active_home=$(resolved_existing_dir "$FM_HOME")
  abs_root=$(resolved_existing_dir "$FM_ROOT")
  if [ "$abs_home" = "/" ]; then
    echo "error: secondmate home cannot be the filesystem root: $home" >&2
    return 1
  fi
  if [ "$abs_home" = "$abs_active_home" ]; then
    echo "error: secondmate home cannot be the active firstmate home: $home" >&2
    return 1
  fi
  if [ "$abs_home" = "$abs_root" ]; then
    echo "error: secondmate home cannot be the firstmate repo: $home" >&2
    return 1
  fi
  if path_is_ancestor_of "$abs_active_home" "$abs_home"; then
    echo "error: secondmate home cannot be inside the active firstmate home: $home" >&2
    return 1
  fi
  if path_is_ancestor_of "$abs_root" "$abs_home"; then
    echo "error: secondmate home cannot be inside the firstmate repo: $home" >&2
    return 1
  fi
  if path_is_ancestor_of "$abs_home" "$abs_active_home"; then
    echo "error: secondmate home cannot be an ancestor of the active firstmate home: $home" >&2
    return 1
  fi
  if path_is_ancestor_of "$abs_home" "$abs_root"; then
    echo "error: secondmate home cannot be an ancestor of the firstmate repo: $home" >&2
    return 1
  fi
  validate_operational_dirs "$abs_home" "$abs_active_home" "$abs_root" || return 1
  if [ ! -f "$abs_home/.fm-secondmate-home" ]; then
    echo "error: firstmate home $home is not a seeded secondmate home" >&2
    return 1
  fi
  marker_id=$(cat "$abs_home/.fm-secondmate-home" 2>/dev/null || true)
  if [ "$marker_id" != "$id" ]; then
    echo "error: firstmate home $home is marked for secondmate ${marker_id:-unknown}, expected $id" >&2
    return 1
  fi
  if [ ! -f "$abs_home/AGENTS.md" ]; then
    echo "error: $home is not a firstmate home (missing AGENTS.md)" >&2
    return 1
  fi
  if [ ! -d "$abs_home/bin" ]; then
    echo "error: $home is not a firstmate home (missing bin/)" >&2
    return 1
  fi
  printf '%s\n' "$abs_home"
}

validate_backlog_file() {
  local label=$1 path=$2
  if [ -L "$path" ]; then
    echo "error: $label must not be a symlink: $path" >&2
    return 1
  fi
  if [ -e "$path" ] && [ ! -f "$path" ]; then
    echo "error: $label is not a regular file: $path" >&2
    return 1
  fi
}

# Classify a single key by the section it lives under (## In flight /
# ## Queued / ## Done), or return non-zero if no `- [ ] <key>` / `- [x] <key>`
# header exists in the file. This reads only section headings and item header
# lines - never item bodies - so it drives the fleet-level classification (in-
# flight refusal, already-present idempotency, missing-key abort) without
# re-implementing the block/body move semantics that tasks-axi mv owns.
backlog_key_section() {
  local file=$1 key=$2
  [ -f "$file" ] || return 1
  awk -v key="$key" '
    BEGIN { section = "## Queued" }
    /^##[[:space:]]+/ {
      section = $0
      sub(/^##[[:space:]]+/, "## ", section)
      sub(/[[:space:]]+$/, "", section)
      next
    }
    /^- \[[ x]\] / {
      rest = $0
      sub(/^- \[[ x]\] +/, "", rest)
      id = rest
      sub(/[ \t].*/, "", id)
      if (id == key) { print section; found = 1; exit }
    }
    END { exit found ? 0 : 1 }
  ' "$file"
}

backlog_key_noncanonical_body_lines() {
  local file=$1 key=$2
  awk -v key="$key" '
    /^- \[[ x]\] / {
      rest = $0
      sub(/^- \[[ x]\] +/, "", rest)
      id = rest
      sub(/[ \t].*/, "", id)
      if (capturing) exit
      if (id == key) { capturing = 1 }
      next
    }
    capturing && /^##[[:space:]]+/ { exit }
    capturing && /^[[:space:]]/ && !/^  / && /[^[:space:]]/ { print }
  ' "$file"
}

# The ITEM BLOCK of a key in a backlog file: its header line, then every
# following line that is blank or indented (the body, the blank separators
# between paragraphs, and the indented pseudo-headings such as `  ## Intent`),
# stopping at the first line that is neither blank nor indented, which is the
# next item header or the next column-0 section heading. Only a column-0 `##`
# heading is a section boundary, so an indented `  ## Intent` stays body.
backlog_item_block() {
  local file=$1 key=$2
  [ -f "$file" ] || return 1
  awk -v key="$key" '
    /^- \[[ x]\] / {
      rest = $0
      sub(/^- \[[ x]\] +/, "", rest)
      id = rest
      sub(/[ \t].*/, "", id)
      if (capturing) exit
      if (id == key) { print; capturing = 1; next }
      next
    }
    capturing && /^##[[:space:]]+/ { exit }
    capturing && /^([ \t].*)?$/ { print; next }
    capturing { exit }
  ' "$file"
}

# The comparison fingerprint of an item block: the same lines with trailing
# whitespace removed and trailing blank lines dropped. A whitespace-only
# difference between two copies of the same item must not read as staleness,
# while any real content difference does.
backlog_item_block_fingerprint() {
  local file=$1 key=$2
  backlog_item_block "$file" "$key" | awk '
    { sub(/[ \t]+$/, "") ; line[NR] = $0 }
    END {
      n = NR
      while (n > 0 && line[n] == "") n--
      for (i = 1; i <= n; i++) print line[i]
    }
  '
}

RAW_HOME=$(secondmate_home "$ID") || exit 1
[ -n "$RAW_HOME" ] || { echo "error: secondmate $ID has no home in $REG" >&2; exit 1; }
SUB_HOME=$(validate_secondmate_home "$ID" "$RAW_HOME") || exit 1
SUB_BACKLOG="$SUB_HOME/data/backlog.md"
validate_backlog_file "main backlog" "$MAIN_BACKLOG" || exit 1
validate_backlog_file "secondmate backlog" "$SUB_BACKLOG" || exit 1

# Classify every key against BOTH backlogs before changing anything. The copy
# that is in the main backlog decides: a key the main backlog no longer holds
# is already done, a key the main backlog still holds in `## Queued` is handed
# off (the destination copy is replaced when there is one), and a key the main
# backlog holds in `## In flight` or `## Done` is refused whatever the
# destination holds. Abort with no changes if any key matches neither backlog.
TO_MOVE=()
REPLACE=()
ALREADY=()
STALE=()
IDENTICAL=()
MISSING=()
IN_FLIGHT=()
DONE=()
NOT_QUEUED=()
CLASSIFIED_KEYS=$'\n'
for key in "$@"; do
  # A repeated key is classified once. tasks-axi ignores duplicate ids, and the
  # destination cleanup below must not try to remove the same copy twice.
  case "$CLASSIFIED_KEYS" in
    *$'\n'"$key"$'\n'*) continue ;;
  esac
  CLASSIFIED_KEYS="$CLASSIFIED_KEYS$key"$'\n'
  source_section=$(backlog_key_section "$MAIN_BACKLOG" "$key" 2>/dev/null || true)
  dest_section=$(backlog_key_section "$SUB_BACKLOG" "$key" 2>/dev/null || true)
  if [ -z "$source_section" ]; then
    # The main backlog does not hold the key. The destination holding it means
    # the handoff is already done; neither backlog holding it means the key
    # matches nothing.
    if [ -n "$dest_section" ]; then
      ALREADY+=("$key")
    else
      MISSING+=("$key")
    fi
    continue
  fi
  case "$source_section" in
    "## Queued")
      if [ -z "$dest_section" ]; then
        TO_MOVE+=("$key")
      else
        # The destination holds a copy. An identical copy means the handoff is
        # half done and must be completed; a differing copy means the
        # destination copy is stale. Both end with the current main copy in
        # the destination and no copy left in the main backlog.
        source_copy=$(backlog_item_block_fingerprint "$MAIN_BACKLOG" "$key")
        dest_copy=$(backlog_item_block_fingerprint "$SUB_BACKLOG" "$key")
        if [ "$source_copy" = "$dest_copy" ]; then
          IDENTICAL+=("$key")
        else
          STALE+=("$key")
        fi
        REPLACE+=("$key")
      fi
      ;;
    "## In flight") IN_FLIGHT+=("$key") ;;
    "## Done") DONE+=("$key") ;;
    *) NOT_QUEUED+=("$key") ;;
  esac
done

FAILED=0
if [ "${#IN_FLIGHT[@]}" -gt 0 ]; then
  echo "error: refusing to hand off in-flight backlog items: ${IN_FLIGHT[*]}" >&2
  FAILED=1
fi
if [ "${#DONE[@]}" -gt 0 ]; then
  echo "error: refusing to hand off Done (historical) backlog items: ${DONE[*]}; handoffs move in-scope queued work only - Done records stay with their home and are pruned/archived." >&2
  FAILED=1
fi
if [ "${#NOT_QUEUED[@]}" -gt 0 ]; then
  echo "error: refusing to hand off non-queued backlog items: ${NOT_QUEUED[*]}; handoffs move in-scope queued work only." >&2
  FAILED=1
fi
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "error: no backlog item matched these keys in $MAIN_BACKLOG: ${MISSING[*]}" >&2
  FAILED=1
fi
if [ "$FAILED" -ne 0 ]; then
  echo "       nothing was moved." >&2
  exit 1
fi

if [ "${#TO_MOVE[@]}" -eq 0 ] && [ "${#REPLACE[@]}" -eq 0 ]; then
  echo "nothing to move: ${ALREADY[*]:-no keys} already present in $SUB_BACKLOG"
  exit 0
fi

# Every key this run will move out of the main backlog: the keys the
# destination does not hold at all, plus the keys whose destination copy is
# replaced by the current main copy. They all travel in one atomic
# `tasks-axi mv` call, so a connected set (a blocker and its dependents) moves
# together.
MOVE_KEYS=()
if [ "${#TO_MOVE[@]}" -gt 0 ]; then
  MOVE_KEYS+=("${TO_MOVE[@]}")
fi
if [ "${#REPLACE[@]}" -gt 0 ]; then
  MOVE_KEYS+=("${REPLACE[@]}")
fi

FAILED=0
for key in "${MOVE_KEYS[@]}"; do
  while IFS= read -r line; do
    printf 'error: refusing to hand off %s: non-2-space continuation line: %s\n' \
      "$key" "$line" >&2
    FAILED=1
  done < <(backlog_key_noncanonical_body_lines "$MAIN_BACKLOG" "$key")
done
if [ "$FAILED" -ne 0 ]; then
  echo "       nothing was moved." >&2
  exit 1
fi

if ! fm_tasks_axi_compatible; then
  echo "error: tasks-axi with atomic multi-ID mv support (0.2.2+) is required to move backlog items" >&2
  exit 1
fi

# Seed the destination with firstmate's standard three-section scaffold when it
# does not exist yet, so the moved item lands under the right section. (Left to
# create the file itself, tasks-axi mv writes its own `# Backlog` title format,
# which is not firstmate's home-backlog convention.)
mkdir -p "$SUB_HOME/data"
SUB_CREATED=0
if [ ! -f "$SUB_BACKLOG" ]; then
  printf '## In flight\n\n## Queued\n\n## Done\n' > "$SUB_BACKLOG"
  SUB_CREATED=1
fi

# A destination copy that has to be replaced is not a completed handoff: the
# destination holds a copy of the item while the main backlog still owns it.
# `tasks-axi mv` refuses to write an id that already exists in the
# destination, so the destination copy is removed first and the current main
# copy is moved into its place. The destination is backed up byte-exact before
# that happens and restored on any failure, so the handoff stays atomic: on a
# failure nothing moves and the destination is exactly as it was.
#
# `tasks-axi rm` refuses to remove a blocker while an active dependent is still
# in the same file, so the removals are retried until no more progress is
# made: the dependent goes first, then the blocker it was holding up.
#
# SUB_BACKUP_RESTORE says whether the exit trap may put the backup back. It is
# 1 while the destination is knowingly short of a copy and the move has not
# run yet, and 0 once the move call is under way, because from that moment the
# move's own failure branch restores explicitly and an interrupted move either
# completed or left the item in the source for the next run.
SUB_BACKUP=
SUB_BACKUP_RESTORE=0
restore_sub_backup_on_exit() {
  if [ "$SUB_BACKUP_RESTORE" -eq 1 ] && [ -n "$SUB_BACKUP" ] && [ -f "$SUB_BACKUP" ]; then
    cp "$SUB_BACKUP" "$SUB_BACKLOG" 2>/dev/null || true
  fi
  if [ -n "$SUB_BACKUP" ] && [ -f "$SUB_BACKUP" ]; then
    rm -f "$SUB_BACKUP"
  fi
}
trap restore_sub_backup_on_exit EXIT

if [ "${#REPLACE[@]}" -gt 0 ]; then
  SUB_BACKUP=$(mktemp "${TMPDIR:-/tmp}/fm-backlog-handoff-backup.XXXXXX") || SUB_BACKUP=
  if [ -z "$SUB_BACKUP" ]; then
    echo "error: could not create a backup of $SUB_BACKLOG; nothing was moved." >&2
    exit 1
  fi
  if ! cp "$SUB_BACKLOG" "$SUB_BACKUP"; then
    rm -f "$SUB_BACKUP"
    SUB_BACKUP=
    echo "error: could not back up $SUB_BACKLOG; nothing was moved." >&2
    exit 1
  fi
  SUB_BACKUP_RESTORE=1
  PENDING_KEYS=("${REPLACE[@]}")
  LAST_RM_ERROR=""
  while [ "${#PENDING_KEYS[@]}" -gt 0 ]; do
    PROGRESS=0
    REMAINING_KEYS=()
    for key in "${PENDING_KEYS[@]}"; do
      if RM_OUT=$(tasks-axi rm "$key" --file "$SUB_BACKLOG" 2>&1); then
        PROGRESS=1
      else
        REMAINING_KEYS+=("$key")
        LAST_RM_ERROR="$RM_OUT"
      fi
    done
    PENDING_KEYS=(${REMAINING_KEYS[@]+"${REMAINING_KEYS[@]}"})
    if [ "$PROGRESS" -eq 0 ]; then
      cp "$SUB_BACKUP" "$SUB_BACKLOG" 2>/dev/null || true
      rm -f "$SUB_BACKUP"
      SUB_BACKUP=
      SUB_BACKUP_RESTORE=0
      if [ -n "$LAST_RM_ERROR" ]; then
        printf '%s\n' "$LAST_RM_ERROR" >&2
      fi
      echo "error: tasks-axi rm failed; nothing was moved." >&2
      exit 1
    fi
  done
fi

# Delegate the move to tasks-axi. Passing the whole in-scope set to one call is a
# single atomic transaction, so a connected set (blocker + dependents) moves
# together and, on any failure, neither backlog's content changes - the only
# cleanup is a scaffold we just created, or the byte-exact destination backup
# taken above for a stale copy that was removed. tasks-axi writes both its
# success and error output to stdout, so capture it and surface it only on
# failure.
SUB_BACKUP_RESTORE=0
if ! MV_OUT=$(tasks-axi mv "${MOVE_KEYS[@]}" --file "$MAIN_BACKLOG" --to "$SUB_BACKLOG" 2>&1); then
  if [ "$SUB_CREATED" -eq 1 ]; then
    rm -f "$SUB_BACKLOG"
  elif [ -n "$SUB_BACKUP" ] && [ -f "$SUB_BACKUP" ]; then
    cp "$SUB_BACKUP" "$SUB_BACKLOG" 2>/dev/null || true
  fi
  if [ -n "$SUB_BACKUP" ] && [ -f "$SUB_BACKUP" ]; then
    rm -f "$SUB_BACKUP"
  fi
  SUB_BACKUP=
  if [ -n "$MV_OUT" ]; then
    printf '%s\n' "$MV_OUT" >&2
  fi
  echo "error: tasks-axi mv failed; nothing was moved." >&2
  exit 1
fi

if [ -n "$SUB_BACKUP" ] && [ -f "$SUB_BACKUP" ]; then
  rm -f "$SUB_BACKUP"
fi
SUB_BACKUP=

echo "handed off ${#MOVE_KEYS[@]} item(s) to $ID: ${MOVE_KEYS[*]}"
echo "  into $SUB_BACKLOG"
if [ "${#STALE[@]}" -gt 0 ]; then
  echo "  replaced a stale destination copy: ${STALE[*]}"
fi
if [ "${#IDENTICAL[@]}" -gt 0 ]; then
  echo "  completed a half-done handoff (destination copy already current): ${IDENTICAL[*]}"
fi
if [ "${#ALREADY[@]}" -gt 0 ]; then
  echo "  already present (skipped): ${ALREADY[*]}"
fi
