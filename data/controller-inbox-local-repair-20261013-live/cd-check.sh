#!/usr/bin/env bash
# Poll the approved local Controller reply directory while this Firstmate home
# is away. Report only filenames and digests; the owning Firstmate reads the
# message and acknowledges its exact bytes after handling it.
set -u

FM_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
INBOX=/home/hd2admin/kun-agent-workspace/data/controller-inbox-local-repair-20261013-live/cd-inbox2
CONTRACT="$STATE/.afk-contract"
HANDLED="$STATE/.controller-inbox-handled"

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

is_handled() {
  local target="$1" hash="$2"
  [[ -f "$HANDLED" && ! -L "$HANDLED" ]] || return 1
  grep -Fqx -- "$hash$(printf '\t')$target" "$HANDLED"
}

ack_message() {
  local name="$1" expected="$2" path actual tmp
  valid_name "$name" || { printf 'refused: invalid Controller message filename\n' >&2; return 2; }
  [[ "$expected" =~ ^[a-f0-9]{64}$ ]] || { printf 'refused: invalid Controller message digest\n' >&2; return 2; }
  path="$INBOX/$name"
  [[ -f "$path" && ! -L "$path" ]] || { printf 'refused: Controller message is unavailable\n' >&2; return 1; }
  actual=$(file_hash "$path") || { printf 'refused: could not verify Controller message\n' >&2; return 1; }
  [[ "$actual" = "$expected" ]] || { printf 'refused: Controller message changed after it was read\n' >&2; return 1; }
  if [[ -e "$HANDLED" || -L "$HANDLED" ]]; then
    [[ -f "$HANDLED" && ! -L "$HANDLED" ]] || { printf 'refused: handled-message ledger is unsafe\n' >&2; return 1; }
    if grep -Fqx -- "$expected$(printf '\t')$name" "$HANDLED"; then
      printf 'already-acknowledged: %s\n' "$name"
      return 0
    fi
  fi
  tmp=$(mktemp "$STATE/.controller-inbox-handled.XXXXXX") || return 1
  if [[ -f "$HANDLED" ]] && ! cat -- "$HANDLED" > "$tmp"; then rm -f -- "$tmp"; return 1; fi
  printf '%s\t%s\n' "$expected" "$name" >> "$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$HANDLED" || { rm -f -- "$tmp"; return 1; }
  printf 'acknowledged: %s sha256=%s\n' "$name" "$expected"
}

case "${1:-}" in
  --ack)
    [[ "$#" -eq 3 ]] || { printf 'usage: controller-inbox.check.sh --ack <filename> <sha256>\n' >&2; exit 2; }
    ack_message "$2" "$3"
    exit $?
    ;;
  '') ;;
  *) printf 'usage: controller-inbox.check.sh [--ack <filename> <sha256>]\n' >&2; exit 2 ;;
esac

[[ -d "$STATE" && ! -L "$STATE" ]] || fail 'Firstmate state directory is unavailable'
[[ -f "$STATE/.afk" && ! -L "$STATE/.afk" ]] || exit 0
[[ -d "$INBOX" && ! -L "$INBOX" ]] || fail 'approved reply directory is unavailable'
# Defect 3 fix: prefer CONTRACT (entered_epoch schema) but fall back to legacy
# state/.afk epoch when CONTRACT is absent — no .afk-contract producer exists in
# this home, yet the legacy .afk flag correctly gates away-mode polling.
# Without the fallback the poll hard-errors even though away mode is genuinely
# established; the mtime filter protects against pre-away messages regardless.
if [[ -f "$CONTRACT" && ! -L "$CONTRACT" ]]; then
  entered=$(awk -F ': ' '$1 == "entered_epoch" { print $2; exit }' "$CONTRACT")
  [[ "$entered" =~ ^[0-9]+$ ]] || fail 'confirmed away timestamp is invalid'
else
  # Legacy fallback: .afk contains the epoch as its first numeric token
  entered=$(awk 'BEGIN{fa=1} NF && $1~/^[0-9]+$/ && fa{print $1; fa=0}' "$STATE/.afk")
  [[ "$entered" =~ ^[0-9]+$ ]] || fail 'confirmed away timestamp is invalid'
fi

while IFS= read -r -d '' name; do
  valid_name "$name" || continue
  path="$INBOX/$name"
  [[ -f "$path" && ! -L "$path" ]] || continue
  modified=$(stat -c '%Y' -- "$path" 2>/dev/null) || { fail "cannot read timestamp for $name"; }
  [[ "$modified" =~ ^[0-9]+$ ]] || { fail "invalid timestamp for $name"; }
  (( modified >= entered )) || continue
  hash=$(file_hash "$path") || { fail "cannot hash $name"; }
  is_handled "$name" "$hash" || printf 'controller inbox update: %s sha256=%s\n' "$name" "$hash"
done < <(find "$INBOX" -maxdepth 1 -type f -name '*.md' -printf '%f\0' 2>/dev/null)
