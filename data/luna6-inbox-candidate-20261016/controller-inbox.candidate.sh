#!/usr/bin/env bash
# Poll the documented Controller reply directories and report unseen messages.
# The owning Firstmate reads the message and acknowledges its exact bytes after
# handling it, using --ack.
#
# Works whether or not the Captain is present: automatic receipt must not depend
# on away mode. 2026-10-14: the poll previously exited silently unless state/.afk
# existed, so with the Captain present it never reported anything. That was
# verified as the real cause, not assumed.
#
# All documented inbound routes are watched, not two. Controller writes to more
# than one exchange path, and watching only the pair first noticed meant a reply
# landing in the authoritative home's inbox would never have been picked up here.
# Content-hash dedup is what makes watching five paths cheap: a message present in
# three of them is reported and acknowledged exactly once.
#
# /home/hd2admin/kun-agent-workspace/data/luna6-inbox-candidate-20261016/inbox-brandon is retained despite being the folder an earlier
# repair identified as the WRONG inbox. It is stale as of 2026-09-27, but it is a
# real route Controller has used, and dropping it from the watch list would mean a
# message there is invisible rather than merely old.
#
# Protections preserved from the previous implementation:
#   - filename allowlist, and refusal of symlinked inbox, file, or ledger
#   - the message is re-hashed at ack time and refused if it changed after read
#   - the handled ledger is written atomically at mode 0600
#   - any error exits 0 so a broken poll can never wedge the watcher
# Report only filenames and digests; never message content.
set -u

FM_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
HANDLED="$STATE/.controller-inbox-handled"
WATERMARK="$STATE/.controller-inbox-watermark"
OUTBOUND_LEDGER="$STATE/.controller-inbox-outbound"
NOTIFIED="$STATE/.controller-inbox-notified"
INITIALIZED="$STATE/.controller-inbox-initialized"

INBOXES=(
  "/home/hd2admin/kun-agent-workspace/data/luna6-inbox-candidate-20261016/inbox-controller-replies"
  "$FM_HOME/inbox-home"
  "/home/hd2admin/kun-agent-workspace/data/luna6-inbox-candidate-20261016/inbox-deighton"
  "/home/hd2admin/kun-agent-workspace/data/luna6-inbox-candidate-20261016/inbox-firstmate"
  "/home/hd2admin/kun-agent-workspace/data/luna6-inbox-candidate-20261016/inbox-brandon"
)

fail() {
  printf 'controller inbox poll error: %s\n' "$1"
  exit 0
}

valid_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+\.md$ ]]
}

file_hash() {
  local output
  output=$(sha256sum -- "$1" 2>/dev/null) || return 1
  printf '%s\n' "${output%% *}"
}

# locate: resolve a message name to a real regular file across both inbox paths.
# A name may exist in both; the first real one wins and the content hash makes
# the duplicate irrelevant.
locate() {  # <name>
  local name=$1 inbox path
  for inbox in "${INBOXES[@]}"; do
    [[ -d "$inbox" && ! -L "$inbox" ]] || continue
    path="$inbox/$name"
    [[ -f "$path" && ! -L "$path" ]] || continue
    printf '%s\n' "$path"
    return 0
  done
  return 1
}

# locate_with_hash: resolve a message name to a real regular file whose bytes
# match the expected hash.  Used by --ack when the same basename exists with
# different bytes in multiple routes so that each distinct content item can be
# acknowledged by its exact digest.
locate_with_hash() {  # <name> <expected_sha256>
  local name=$1 expected=$2 inbox path actual
  for inbox in "${INBOXES[@]}"; do
    [[ -d "$inbox" && ! -L "$inbox" ]] || continue
    path="$inbox/$name"
    [[ -f "$path" && ! -L "$path" ]] || continue
    actual=$(file_hash "$path") || continue
    [[ "$actual" = "$expected" ]] || continue
    printf '%s\n' "$path"
    return 0
  done
  return 1
}

is_handled() {  # <sha256>
  local hash=$1
  [[ -f "$HANDLED" && ! -L "$HANDLED" ]] || return 1
  grep -Fq -- "$hash" "$HANDLED"
}

# is_outbound: true when this hash is one this home SENT to Controller.
# /home/hd2admin/kun-agent-workspace/data/luna6-inbox-candidate-20261016/inbox-controller-replies is a bidirectional exchange directory, so an
# outbound copy sitting there is not an inbound message and must never be
# reported as a reply. Authorship is decided by the outbound ledger written by
# bin/fm-outbound.sh, not by the message prose.
is_outbound() {  # <sha256>
  local hash=$1
  [[ -f "$OUTBOUND_LEDGER" && ! -L "$OUTBOUND_LEDGER" ]] || return 1
  grep -Fqx -- "$hash" "$OUTBOUND_LEDGER"
}

# record_handled: append a hash. Ledger is keyed by content hash alone, so the
# same message under either directory, or renamed, is acknowledged once.
record_handled() {  # <sha256>
  local hash=$1 tmp
  tmp=$(mktemp "$STATE/.controller-inbox-handled.XXXXXX") || return 1
  if [[ -f "$HANDLED" ]] && ! cat -- "$HANDLED" > "$tmp"; then rm -f -- "$tmp"; return 1; fi
  printf '%s\n' "$hash" >> "$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$HANDLED" || { rm -f -- "$tmp"; return 1; }
}

ack_message() {  # <name> <sha256>
  local name=$1 expected=$2 path actual
  valid_name "$name" || { printf 'refused: invalid Controller message filename\n' >&2; return 2; }
  [[ "$expected" =~ ^[a-f0-9]{64}$ ]] || { printf 'refused: invalid Controller message digest\n' >&2; return 2; }
  # First: try to find the file with this name whose content matches the expected
  # hash.  This resolves F1: when the same basename appears with different bytes
  # across two routes, each distinct content item can be acknowledged by its exact
  # digest rather than being confined to the first-matching route.
  if path=$(locate_with_hash "$name" "$expected"); then
    # Found the file with matching hash.
    if is_handled "$expected"; then
      printf 'already-acknowledged: %s sha256=%s\n' "$name" "$expected"
      return 0
    fi
    record_handled "$expected" || { printf 'refused: could not record acknowledgement\n' >&2; return 1; }
    printf 'acknowledged: %s sha256=%s\n' "$name" "$expected"
    return 0
  fi
  # No file with this name has the expected hash.
  # Check whether the file exists (any route) but with different bytes: that means
  # the message was modified after it was read.
  if path=$(locate "$name"); then
    printf 'refused: Controller message changed after it was read\n' >&2
    return 1
  fi
  printf 'refused: Controller message is unavailable\n' >&2
  return 1
}

case "${1:-}" in
  --ack)
    [[ "$#" -eq 3 ]] || { printf 'usage: controller-inbox.check.sh [--pending | --ack <filename> <sha256>]\n' >&2; exit 2; }
    ack_message "$2" "$3"
    exit $?
    ;;
  --pending) [[ "$#" -eq 1 ]] || { printf 'usage: controller-inbox.check.sh --pending\n' >&2; exit 2; } ;;
  '') ;;
  *) printf 'usage: controller-inbox.check.sh [--pending | --ack <filename> <sha256>]\n' >&2; exit 2 ;;
esac

[[ -d "$STATE" && ! -L "$STATE" ]] || fail 'Firstmate state directory is unavailable'
for ledger in "$HANDLED" "$WATERMARK" "$OUTBOUND_LEDGER" "$NOTIFIED" "$INITIALIZED"; do
  [[ ! -L "$ledger" ]] || fail 'candidate inbox ledger is a symlink'
done

if [[ "${1:-}" == "--pending" ]]; then
  [[ -f "$INITIALIZED" && ! -L "$INITIALIZED" ]] || { printf 'controller inbox migration blocked: initialization record missing; owner decision required before pending inspection\n'; exit 3; }
  declare -A pending_hashes=()
  for inbox in "${INBOXES[@]}"; do
    [[ -d "$inbox" && ! -L "$inbox" ]] || continue
    while IFS= read -r -d '' name; do
      valid_name "$name" || continue
      path="$inbox/$name"
      [[ -f "$path" && ! -L "$path" ]] || continue
      hash=$(file_hash "$path") || fail "cannot hash $name"
      [[ -z "${pending_hashes[$hash]+x}" ]] || continue
      { is_handled "$hash" || is_outbound "$hash"; } && continue
      pending_hashes[$hash]="$name"
    done < <(find "$inbox" -maxdepth 1 -type f -name '*.md' -printf '%f\0' 2>/dev/null)
  done
  for hash in "${!pending_hashes[@]}"; do
    printf 'pending: %s sha256=%s\n' "${pending_hashes[$hash]}" "$hash"
  done
  exit 0
fi

# Watermark: report messages that arrived since the last sweep. On the very first
# run there is no watermark, so the poll seeds it to now and discloses how many
# pre-existing messages it did NOT surface, rather than firing a storm of model
# calls for mail that predates automatic reception.
now=$(date +%s)
if [[ -f "$WATERMARK" && ! -L "$WATERMARK" ]]; then
  if [[ ! -f "$INITIALIZED" || -L "$INITIALIZED" ]]; then
    printf 'controller inbox migration blocked: existing watermark lacks candidate initialization record; owner decision required; no inbox or ledger changes made\n'
    exit 3
  fi
  since=$(cat -- "$WATERMARK" 2>/dev/null)
  [[ "$since" =~ ^[0-9]+$ ]] || fail 'watermark is invalid'
else
  # Exclude historical mail by content identity, count it once across mirrored routes,
  # and never confuse exclusion with a handled acknowledgement.
  pre=0
  : > "$NOTIFIED" || fail 'cannot create candidate notification ledger'
  declare -A initial_hashes=()
  for inbox in "${INBOXES[@]}"; do
    [[ -d "$inbox" && ! -L "$inbox" ]] || continue
    while IFS= read -r -d '' name; do
      valid_name "$name" || continue
      path="$inbox/$name"
      [[ -f "$path" && ! -L "$path" ]] || continue
      hash=$(file_hash "$path") || fail "cannot hash $name"
      [[ -z "${initial_hashes[$hash]+x}" ]] || continue
      { is_handled "$hash" || is_outbound "$hash"; } && continue
      initial_hashes[$hash]=1
      printf '%s\n' "$hash" >> "$NOTIFIED" || fail 'cannot record historical exclusion'
      pre=$((pre + 1))
    done < <(find "$inbox" -maxdepth 1 -type f -name '*.md' -printf '%f\0' 2>/dev/null)
  done
  printf '%s\n' "$now" > "$WATERMARK" || fail 'cannot initialize watermark'
  printf 'candidate\n' > "$INITIALIZED" || fail 'cannot record candidate initialization'
  chmod 0600 "$WATERMARK" "$NOTIFIED" "$INITIALIZED" || fail 'cannot secure candidate initialization records'
  printf 'controller inbox poll seeded: %s pre-existing message(s) excluded from notifications; no messages marked handled\n' "$pre"
  exit 0
fi

# Persisted notification identity is separate from exact-byte acknowledgement:
# mirrored copies cannot repeat a routine notification before acknowledgement.
emitted=$(mktemp "$STATE/.controller-inbox-notified.XXXXXX") || fail 'cannot create notification ledger temporary file'
if [[ -f "$NOTIFIED" ]]; then cat -- "$NOTIFIED" > "$emitted" || fail 'cannot copy notification ledger'; fi

for inbox in "${INBOXES[@]}"; do
  [[ -d "$inbox" && ! -L "$inbox" ]] || continue
  while IFS= read -r -d '' name; do
    valid_name "$name" || continue
    path=$(locate "$name") || continue
    hash=$(file_hash "$path") || fail "cannot hash $name"
    grep -Fqx -- "$hash" "$emitted" && continue
    { is_handled "$hash" || is_outbound "$hash"; } && continue
    printf 'controller inbox update: %s sha256=%s\n' "$name" "$hash"
    printf '%s\n' "$hash" >> "$emitted"
  done < <(find "$inbox" -maxdepth 1 -type f -name '*.md' -printf '%f\0' 2>/dev/null)
done

mv -f -- "$emitted" "$NOTIFIED" || fail 'cannot publish notification ledger'
printf '%s\n' "$now" > "$WATERMARK" || fail 'cannot update watermark'
chmod 0600 "$WATERMARK" "$NOTIFIED" || fail 'cannot secure candidate ledgers'
exit 0