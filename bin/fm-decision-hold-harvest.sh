#!/usr/bin/env bash
# fm-decision-hold-harvest.sh - scheduler-side harvest of lane decision holds.
#
# The decision-hold lifecycle has exactly two writers, and this script is the
# second one:
#
#   - The lane, inside its OWN worktree. A lane registers an unresolved captain
#     decision with `bin/fm-decision-hold.sh hold`; that hold lands in the
#     lane's own backlog and the lane's own state, never in a shared home. The
#     lane also writes its completion attestation into its own state.
#
#   - The scheduler, which owns the half's state directory and its backlog.
#     This script is the single-writer action that moves a lane's hold from the
#     lane's worktree into the half that owns the originating work:
#
#       1. seed     - give the lane's worktree its own copy of the lane
#                     identity (state/<id>.meta) so the lane's own ownership
#                     test can find the origin it is working on. The seed is
#                     create-once: the lane owns the file afterwards and
#                     appends its completion attestation to it.
#       2. harvest  - read the lane's captain-held rows and register them in
#                     the half's authoritative backlog, and record each
#                     harvested hold in the half's state directory.
#       3. attest   - merge the lane's completion attestation into the half's
#                     metadata for that origin.
#       4. transfer - close the duplicate live status decision in the half,
#                     now that the hold is durable in the half's backlog.
#
# ONE WRITER PER PATH. The lane writes only inside its own worktree. This
# script writes only inside the half's own state directory and backlog. No
# lane ever writes into a half's state directory.
#
# SLOT OWNERSHIP. Worktrees come from a shared pool and a slot is reused, so
# several lane identities can point at one worktree path. The slot belongs to
# the lane with the newest spawn, and only that lane is seeded. A hold is
# harvested only when its identity belongs to a lane of THIS half that used
# this slot, so a slot another half used can never leak into this half.
#
# Usage:
#   fm-decision-hold-harvest.sh [--dry-run]
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
BACKLOG="$DATA/backlog.md"
HOLD_DIR="$STATE/decision-holds"
TRASH="${FM_TRASH_BIN:-/home/hd2admin/.minimax/bin/mavis-trash}"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

usage() {
  awk '
    NR == 1 { next }
    /^#/ { sub(/^# ?/, ""); print; next }
    { exit }
  ' "$0"
}

fail() {
  printf 'fm-decision-hold-harvest: %s\n' "$*" >&2
  exit 1
}

meta_value() {  # <meta> <key>
  grep "^$2=" "$1" 2>/dev/null | tail -1 | cut -d= -f2- || true
}

now_utc() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

tasks_at() {  # <backlog> <tasks-axi args...>
  local backlog=$1
  shift
  tasks-axi "$@" --file="$backlog"
}

show_field() {  # <show-output> <field>
  local output=$1 field=$2
  printf '%s\n' "$output" | sed -n "s/^  $field: //p" | head -1
}

write_atomic() {  # <path> <content>
  local path=$1 content=$2
  if [ "$DRY_RUN" = 1 ]; then
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$content" > "$path.new"
  mv "$path.new" "$path"
}

# Seed the lane's own worktree with the lane's identity so the lane's own
# ownership test in bin/fm-decision-hold.sh can find the origin it owns. The
# seed is create-once: the lane appends its completion attestation to the file
# afterwards, and the scheduler must never rewrite it.
seed_lane_state() {  # <id> <meta> <worktree>
  local id=$1 meta=$2 worktree=$3 seed
  seed="$worktree/state/$id.meta"
  if [ -f "$seed" ]; then
    return 0
  fi
  if [ ! -f "$meta" ]; then
    return 0
  fi
  write_atomic "$seed" "$(cat "$meta"; printf 'half_state=%s\nhalf_data=%s\n' "$STATE" "$DATA")"
  printf 'seeded %s\n' "$id"
}

# A reused slot must not keep a previous owner's identity: a stale seed would
# still satisfy the ownership test for an origin this lane does not own.
retire_stale_seeds() {  # <worktree> <owner-id> <space-separated-ids>
  local worktree=$1 owner=$2 ids=$3 id seed
  for id in $ids; do
    if [ "$id" = "$owner" ]; then
      continue
    fi
    seed="$worktree/state/$id.meta"
    [ -f "$seed" ] || continue
    if [ "$DRY_RUN" = 1 ]; then
      printf 'would retire stale seed %s\n' "$id"
      continue
    fi
    if [ -x "$TRASH" ]; then
      "$TRASH" -- "$seed" >/dev/null 2>&1 || rm -f "$seed"
    else
      rm -f "$seed"
    fi
    printf 'retired stale seed %s\n' "$id"
  done
}

# Harvest the lane's captain-held rows into the half's authoritative backlog and
# record each harvested hold in the half's state directory. Only holds whose
# identity belongs to a lane of this half that used this slot are harvested.
harvest_lane_holds() {  # <worktree> <space-separated-ids>
  local worktree=$1 ids=$2 backlog id row show state held kind hold_kind
  local title repo reason body changed
  backlog="$worktree/data/backlog.md"
  if [ ! -f "$backlog" ]; then
    return 0
  fi
  # Cheap pre-filter: a slot with no captain hold never needs tasks-axi.
  if ! grep -Fq '(hold-kind: captain)' "$backlog"; then
    return 0
  fi
  rows=$(tasks_at "$backlog" list --kind captain 2>/dev/null |
    awk -F',' '/^  [^ ]/ { print $1 }' | sed '/^$/d') || return 0
  for row in $rows; do
    # An existing harvest record means the hold is already in the half's
    # backlog, so the steady state costs one list call per slot.
    if [ -f "$HOLD_DIR/$row.hold" ]; then
      continue
    fi
    matched=''
    for id in $ids; do
      case "$row" in
        "$id"-decision-*) matched=1 ;;
      esac
    done
    if [ -z "$matched" ]; then
      continue
    fi
    show=$(tasks_at "$backlog" show "$row" --full 2>/dev/null) || continue
    state=$(show_field "$show" state)
    held=$(show_field "$show" held)
    kind=$(show_field "$show" kind)
    hold_kind=$(show_field "$show" hold_kind)
    [ "$state" = queued ] || continue
    [ "$held" = yes ] || continue
    [ "$kind" = captain ] || continue
    [ "$hold_kind" = captain ] || continue
    title=$(show_field "$show" title)
    repo=$(show_field "$show" repo)
    reason=$(show_field "$show" hold_reason)
    body=$(show_field "$show" body)
    [ -n "$title" ] || title="$row"
    [ -n "$repo" ] || repo=firstmate
    changed=0
    if ! tasks_at "$BACKLOG" show "$row" --full >/dev/null 2>&1; then
      if [ "$DRY_RUN" = 1 ]; then
        printf 'would add %s to the half backlog\n' "$row"
        changed=1
      else
        tasks_at "$BACKLOG" add "$row" "$title" --kind captain --repo "$repo" --body "$body" >/dev/null \
          || fail "could not register harvested captain hold $row in $BACKLOG"
        tasks_at "$BACKLOG" hold "$row" --reason "$reason" --kind captain >/dev/null \
          || fail "could not activate harvested captain hold $row in $BACKLOG"
        changed=1
      fi
    fi
    if [ ! -f "$HOLD_DIR/$row.hold" ]; then
      write_atomic "$HOLD_DIR/$row.hold" "$(printf 'id=%s\ntitle=%s\nrepo=%s\nreason=%s\nstate=%s\nheld=%s\nkind=%s\nhold_kind=%s\nharvested_at=%s\nbody=%s' \
        "$row" "$title" "$repo" "$reason" "$state" "$held" "$kind" "$hold_kind" "$(now_utc)" "$body")"
      changed=1
    fi
    if [ "$changed" = 1 ]; then
      printf 'harvested %s\n' "$row"
    fi
  done
}

# Merge the lane's completion attestation into the half's metadata for the same
# origin, so the half's own read-only verify gate sees the reviewed inventory.
merge_attestation() {  # <id> <worktree>
  local id=$1 worktree=$2 seed reviewed keys half_meta
  seed="$worktree/state/$id.meta"
  half_meta="$STATE/$id.meta"
  if [ ! -f "$seed" ] || [ ! -f "$half_meta" ]; then
    return 0
  fi
  reviewed=$(meta_value "$seed" decisions_reviewed)
  [ "$reviewed" = 1 ] || return 0
  keys=$(meta_value "$seed" decision_keys)
  if [ "$(meta_value "$half_meta" decisions_reviewed)" != 1 ] ||
     [ "$(meta_value "$half_meta" decision_keys)" != "$keys" ]; then
    if [ "$DRY_RUN" = 1 ]; then
      printf 'would attest %s in %s\n' "$id" "$half_meta"
      return 0
    fi
    printf 'decisions_reviewed=1\ndecision_keys=%s\n' "$keys" >> "$half_meta"
    printf 'attested %s\n' "$id"
  fi
}

# Close the duplicate live status decision in the half now that the hold is
# durable in the half's backlog. The half's status file is the scheduler's file.
transfer_status_decisions() {  # <id> <worktree>
  local id=$1 worktree=$2 seed keys half_status key
  seed="$worktree/state/$id.meta"
  half_status="$STATE/$id.status"
  if [ ! -f "$seed" ] || [ ! -f "$half_status" ]; then
    return 0
  fi
  keys=$(meta_value "$seed" decision_keys)
  [ -n "$keys" ] || return 0
  for key in $(printf '%s\n' "$keys" | tr ',' ' '); do
    [ -n "$key" ] || continue
    if grep -Fq "captain-held [key=$key]" "$half_status"; then
      continue
    fi
    if ! grep -Fq "needs-decision [key=$key]" "$half_status"; then
      continue
    fi
    if [ "$DRY_RUN" = 1 ]; then
      printf 'would transfer %s/%s\n' "$id" "$key"
      continue
    fi
    printf 'captain-held [key=%s]: tracked by %s\n' "$key" "$id-decision-$key" >> "$half_status"
    printf 'transferred %s/%s\n' "$id" "$key"
  done
}

harvest_home() {
  local meta id worktree spawned owner
  declare -A slot_ids=()
  declare -A slot_owner=()
  declare -A slot_spawn=()
  if [ ! -d "$STATE" ]; then
    return 0
  fi
  # Pass 1: index this half's lanes by the worktree slot they used. The lane
  # with the newest spawn owns the slot; the scheduler's own lane-slot
  # bookkeeping has no spawn stamp and never owns one.
  for meta in "$STATE"/*.meta; do
    [ -f "$meta" ] || continue
    id=$(basename "$meta" .meta)
    worktree=$(meta_value "$meta" worktree)
    [ -n "$worktree" ] || continue
    spawned=$(meta_value "$meta" spawned_at)
    [ -n "$spawned" ] || continue
    [ -d "$worktree" ] || continue
    slot_ids[$worktree]="${slot_ids[$worktree]:-} $id"
    if [ -z "${slot_spawn[$worktree]:-}" ] || [ "$spawned" -gt "${slot_spawn[$worktree]}" ]; then
      slot_spawn[$worktree]=$spawned
      slot_owner[$worktree]=$id
    fi
  done
  # Pass 2: seed the slot owner and harvest that slot's holds.
  for worktree in "${!slot_owner[@]}"; do
    owner=${slot_owner[$worktree]}
    seed_lane_state "$owner" "$STATE/$owner.meta" "$worktree"
    retire_stale_seeds "$worktree" "$owner" "${slot_ids[$worktree]}"
    harvest_lane_holds "$worktree" "${slot_ids[$worktree]}"
    for id in ${slot_ids[$worktree]}; do
      merge_attestation "$id" "$worktree"
      transfer_status_decisions "$id" "$worktree"
    done
  done
}

case "${1:-}" in
  -h|--help) usage ;;
  "") harvest_home ;;
  --dry-run) harvest_home ;;
  *) usage >&2; exit 2 ;;
esac
