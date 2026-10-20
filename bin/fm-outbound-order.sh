#!/usr/bin/env bash
# fm-outbound-order.sh - deliver one explicitly selected work order to Brandon compute.
# Usage:
#   fm-outbound-order.sh deliver <order-id> <local-order-file>
#   fm-outbound-order.sh verify <order-id>
#
# Uses the fixed SSH alias brandon-compute.
# The remote inbox is ~/to-brandon-compute/inbox; this command creates its
# directories when missing, publishes without overwriting different bytes, and
# records a remote SHA-256 receipt only after verifying the published file.
# Local receipts live in $FM_HOME/state/outbound-orders/<order-id>.receipt and
# distinguish queued, transferred, and accepted. A transfer is not acceptance.
# The recipient accepts an order by atomically creating
# ~/to-brandon-compute/accepted/<order-id>.ack with exactly these two lines:
#   order_id=<order-id>
#   sha256=<verified-order-sha256>
# `verify` checks the remote order, remote checksum receipt, and optional ack.
set -euo pipefail

SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
FM_HOME=${FM_HOME:-${FM_ROOT_OVERRIDE:-$SCRIPT_ROOT}}

usage() {
  cat <<'EOF'
Usage:
  fm-outbound-order.sh deliver <order-id> <local-order-file>
  fm-outbound-order.sh verify <order-id>

The order ID is 1-64 ASCII letters, digits, underscores, or hyphens and starts
with a letter or digit. The fixed SSH target is brandon-compute. Remote files
are placed under ~/to-brandon-compute/.

`deliver` records queued before transport and reports transferred only after the
remote inbox file and its SHA-256 receipt match the selected bytes. Repeating an
identical delivery is safe; a different existing order is never overwritten.
`verify` re-reads remote bytes and the receipt. It reports accepted only when a
matching remote worker acknowledgement exists; transfer alone is not acceptance.

A recipient acknowledgement is an exact two-line file at
~/to-brandon-compute/accepted/<order-id>.ack:
  order_id=<order-id>
  sha256=<verified-order-sha256>
EOF
}

die() {
  printf 'fm-outbound-order: %s\n' "$*" >&2
  exit 1
}

usage_error() {
  usage >&2
  exit 2
}

validate_id() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]] \
    || die "unsafe order id; use 1-64 letters, digits, underscores, or hyphens"
}

sha256_file() {
  local output
  if command -v sha256sum >/dev/null 2>&1; then
    output=$(sha256sum "$1") || return 1
  elif command -v shasum >/dev/null 2>&1; then
    output=$(shasum -a 256 "$1") || return 1
  else
    die "sha256sum or shasum is required"
  fi
  printf '%s\n' "${output%% *}"
}

prepare_local_state() {
  local home=${FM_HOME:-} state_dir receipt_dir
  [[ "$home" = /* && -d "$home" && ! -L "$home" ]] \
    || die "FM_HOME must be an existing absolute non-symlink directory"
  state_dir="$home/state"
  receipt_dir="$home/state/outbound-orders"
  [[ ! -L "$state_dir" ]] || die "state directory must not be a symlink"
  if [[ -e "$state_dir" && ! -d "$state_dir" ]]; then
    die "state path exists and is not a directory"
  fi
  mkdir -p "$state_dir"
  [[ -d "$state_dir" && ! -L "$state_dir" ]] \
    || die "state directory is unsafe"
  [[ ! -L "$receipt_dir" ]] || die "outbound receipt directory must not be a symlink"
  if [[ -e "$receipt_dir" && ! -d "$receipt_dir" ]]; then
    die "outbound receipt path exists and is not a directory"
  fi
  (umask 077 && mkdir -p "$receipt_dir")
  chmod 700 "$receipt_dir"
  RECEIPT_DIR=$receipt_dir
}

read_receipt() {
  local path=$1 line1 line2 line3 line4 extra
  [[ -f "$path" && ! -L "$path" ]] || return 1
  {
    IFS= read -r line1 || return 1
    IFS= read -r line2 || return 1
    IFS= read -r line3 || return 1
    IFS= read -r line4 || return 1
    if IFS= read -r extra; then
      return 1
    fi
  } < "$path"
  [[ "$line1" = 'version=1' ]] || return 1
  [[ "$line2" = "order_id=$ORDER_ID" ]] || return 1
  RECEIPT_SHA=${line3#sha256=}
  [[ "$line3" = "sha256=$RECEIPT_SHA" && "$RECEIPT_SHA" =~ ^[0-9a-f]{64}$ ]] || return 1
  RECEIPT_STATE=${line4#state=}
  [[ "$line4" = "state=$RECEIPT_STATE" ]] || return 1
  case "$RECEIPT_STATE" in
    queued|transferred|accepted) ;;
    *) return 1 ;;
  esac
}

write_receipt() {
  local state=$1 temp
  case "$state" in
    queued|transferred|accepted) ;;
    *) die "internal error: invalid receipt state" ;;
  esac
  temp=$(mktemp "$RECEIPT_DIR/.${ORDER_ID}.XXXXXX") \
    || die "could not create a temporary local receipt"
  if ! {
    printf 'version=1\norder_id=%s\nsha256=%s\nstate=%s\n' \
      "$ORDER_ID" "$ORDER_SHA" "$state" > "$temp" \
      && chmod 600 "$temp" \
      && mv -f "$temp" "$RECEIPT_FILE"
  }; then
    rm -f "$temp"
    die "could not persist the local delivery receipt"
  fi
  RECEIPT_STATE=$state
}

remote_exec() {
  ssh -T -o BatchMode=yes "$TARGET" bash -s -- "$@" <<'REMOTE'
set -eu

fail() {
  printf 'fm-outbound-order remote: %s\n' "$*" >&2
  exit 1
}

id=${2:-}
expected=${3:-}
stage=${4:-}
case "$id" in
  ''|*[!A-Za-z0-9_-]*) fail 'unsafe order id' ;;
esac
case "$expected" in
  *[!0-9a-f]*|'') fail 'invalid expected checksum' ;;
esac
[ "${#expected}" -eq 64 ] || fail 'invalid expected checksum'

home=${HOME:-}
case "$home" in
  /*) ;;
  *) fail 'remote home is not absolute' ;;
esac
[ -d "$home" ] && [ ! -L "$home" ] || fail 'remote home is not a safe directory'
root="$home/to-brandon-compute"
inbox="$root/inbox"
receipts="$root/receipts"
accepted="$root/accepted"
order="$inbox/$id.order"
receipt="$receipts/$id.sha256"
ack="$accepted/$id.ack"

ensure_dir() {
  path=$1
  if [ -L "$path" ] || { [ -e "$path" ] && [ ! -d "$path" ]; }; then
    fail 'remote destination contains an unsafe path component'
  fi
  [ -d "$path" ] || mkdir "$path" || fail 'could not create remote destination directory'
  [ -d "$path" ] && [ ! -L "$path" ] || fail 'remote destination is not a safe directory'
}

file_sha256() {
  sha256sum "$1" | awk '{print $1}'
}

check_receipt() {
  [ -f "$receipt" ] && [ ! -L "$receipt" ] || fail 'remote checksum receipt is missing or unsafe'
  actual=$(cat "$receipt")
  [ "$actual" = "$expected" ] || fail 'remote checksum receipt mismatch'
}

case "${1:-}" in
  prepare)
    ensure_dir "$root"
    ensure_dir "$inbox"
    ensure_dir "$receipts"
    ensure_dir "$accepted"
    case "$stage" in
      ".$id.$expected."[0-9]*.[0-9]*.upload) ;;
      *) fail 'unsafe temporary upload path' ;;
    esac
    [ ! -e "$inbox/$stage" ] && [ ! -L "$inbox/$stage" ] \
      || fail 'temporary upload path already exists'
    printf 'ready\n'
    ;;
  cleanup)
    case "$stage" in
      ".$id.$expected."[0-9]*.[0-9]*.upload) ;;
      *) fail 'unsafe temporary upload path' ;;
    esac
    path="$inbox/$stage"
    [ ! -L "$path" ] || fail 'unsafe temporary upload path'
    [ ! -e "$path" ] || rm -f "$path"
    printf 'cleaned\n'
    ;;
  commit)
    case "$stage" in
      ".$id.$expected."[0-9]*.[0-9]*.upload) ;;
      *) fail 'unsafe temporary upload path' ;;
    esac
    staged="$inbox/$stage"
    [ -f "$staged" ] && [ ! -L "$staged" ] || fail 'uploaded file is missing or unsafe'
    staged_sha=$(file_sha256 "$staged") || fail 'could not checksum uploaded file'
    [ "$staged_sha" = "$expected" ] || {
      rm -f "$staged"
      fail 'uploaded checksum mismatch'
    }
    if [ -e "$order" ] || [ -L "$order" ]; then
      [ -f "$order" ] && [ ! -L "$order" ] || fail 'remote order path is not a regular file'
      order_sha=$(file_sha256 "$order") || fail 'could not checksum existing remote order'
      [ "$order_sha" = "$expected" ] || {
        rm -f "$staged"
        fail 'destination checksum mismatch'
      }
      rm -f "$staged"
    else
      if ln "$staged" "$order" 2>/dev/null; then
        rm -f "$staged"
      else
        [ -f "$order" ] && [ ! -L "$order" ] || fail 'could not publish remote order without overwrite'
        order_sha=$(file_sha256 "$order") || fail 'could not checksum competing remote order'
        [ "$order_sha" = "$expected" ] || fail 'destination checksum mismatch'
        rm -f "$staged"
      fi
    fi
    if [ -e "$receipt" ] || [ -L "$receipt" ]; then
      check_receipt
    else
      receipt_tmp="$receipts/.$id.$expected.$$.receipt"
      [ ! -e "$receipt_tmp" ] && [ ! -L "$receipt_tmp" ] || fail 'temporary receipt path already exists'
      printf '%s\n' "$expected" > "$receipt_tmp"
      chmod 600 "$receipt_tmp"
      if ln "$receipt_tmp" "$receipt" 2>/dev/null; then
        rm -f "$receipt_tmp"
      else
        rm -f "$receipt_tmp"
        check_receipt
      fi
    fi
    printf 'committed %s\n' "$expected"
    ;;
  verify)
    if [ ! -e "$order" ] && [ ! -L "$order" ] && [ ! -e "$receipt" ] && [ ! -L "$receipt" ]; then
      printf 'queued %s\n' "$expected"
      exit 0
    fi
    [ -f "$order" ] && [ ! -L "$order" ] || fail 'remote inbox order is missing or unsafe'
    order_sha=$(file_sha256 "$order") || fail 'could not checksum remote order'
    [ "$order_sha" = "$expected" ] || fail 'remote inbox checksum mismatch'
    check_receipt
    ack_state=transferred
    ack_warning=
    if [ -e "$ack" ] || [ -L "$ack" ]; then
      if [ -f "$ack" ] && [ ! -L "$ack" ] \
        && printf 'order_id=%s\nsha256=%s\n' "$id" "$expected" | cmp -s - "$ack"; then
        ack_state=accepted
      else
        ack_warning=invalid-worker-ack
      fi
    fi
    printf '%s %s %s\n' "$ack_state" "$expected" "$ack_warning"
    ;;
  *)
    fail 'unknown remote operation'
    ;;
esac
REMOTE
}

read_remote_state() {
  local result state digest warning extra
  if ! result=$(remote_exec verify "$ORDER_ID" "$ORDER_SHA" -); then
    die "remote verification failed; local receipt remains $RECEIPT_STATE"
  fi
  [[ "$result" != *$'\n'* ]] || die "remote verification returned multiple result lines"
  IFS=' ' read -r state digest warning extra <<< "$result"
  [[ -z "$extra" ]] || die "remote verification returned extra result fields"
  [[ "$digest" = "$ORDER_SHA" ]] || die "remote verification returned an invalid checksum"
  case "$state" in
    queued|transferred|accepted) ;;
    *) die "remote verification returned an invalid state" ;;
  esac
  case "$warning" in
    ''|invalid-worker-ack) ;;
    *) die "remote verification returned an invalid warning" ;;
  esac
  REMOTE_STATE=$state
  REMOTE_WARNING=$warning
}

deliver() {
  local source=$1 source_dir source_base source_abs stage prepare_result
  [[ -f "$source" && ! -L "$source" && -r "$source" ]] \
    || die "selected order must be a readable regular non-symlink file"
  source_dir=$(cd "$(dirname "$source")" && pwd -P) \
    || die "could not resolve selected order directory"
  source_base=$(basename "$source")
  source_abs="$source_dir/$source_base"
  SNAPSHOT_FILE=$(mktemp "${TMPDIR:-/tmp}/fm-outbound-order.XXXXXX") \
    || die "could not create a private order snapshot"
  trap 'if [ -n "${SNAPSHOT_FILE:-}" ]; then rm -f "$SNAPSHOT_FILE"; fi' EXIT
  if ! cat "$source_abs" > "$SNAPSHOT_FILE" || ! chmod 600 "$SNAPSHOT_FILE"; then
    rm -f "$SNAPSHOT_FILE"
    die "could not snapshot selected order"
  fi
  ORDER_SHA=$(sha256_file "$SNAPSHOT_FILE") || die "could not checksum selected order"
  [[ "$ORDER_SHA" =~ ^[0-9a-f]{64}$ ]] || die "checksum tool returned an invalid SHA-256"
  RECEIPT_FILE="$RECEIPT_DIR/$ORDER_ID.receipt"
  if [[ -e "$RECEIPT_FILE" || -L "$RECEIPT_FILE" ]]; then
    read_receipt "$RECEIPT_FILE" || die "local receipt is invalid or unsafe"
    [[ "$RECEIPT_SHA" = "$ORDER_SHA" ]] \
      || die "order ID is already bound to a different checksum; refusing reuse"
  else
    RECEIPT_STATE=queued
    write_receipt queued
  fi

  stage=".$ORDER_ID.$ORDER_SHA.$$.${RANDOM}.upload"
  if ! prepare_result=$(remote_exec prepare "$ORDER_ID" "$ORDER_SHA" "$stage"); then
    die "remote inbox preparation failed; local receipt remains $RECEIPT_STATE"
  fi
  [[ "$prepare_result" = ready ]] || die "remote inbox preparation returned an invalid receipt"
  if ! scp -B -- "$SNAPSHOT_FILE" "$TARGET:~/to-brandon-compute/inbox/$stage"; then
    remote_exec cleanup "$ORDER_ID" "$ORDER_SHA" "$stage" >/dev/null 2>&1 || :
    die "transport failed; local receipt remains $RECEIPT_STATE"
  fi
  if ! remote_exec commit "$ORDER_ID" "$ORDER_SHA" "$stage" >/dev/null; then
    die "remote delivery failed; local receipt remains $RECEIPT_STATE"
  fi
  read_remote_state
  [[ "$REMOTE_STATE" = transferred || "$REMOTE_STATE" = accepted ]] \
    || die "remote file was not verified; local receipt remains $RECEIPT_STATE"
  write_receipt "$REMOTE_STATE"
  if [[ -n "$REMOTE_WARNING" ]]; then
    printf 'state=%s order_id=%s sha256=%s evidence=remote-inbox+sha256-receipt warning=%s\n' \
      "$REMOTE_STATE" "$ORDER_ID" "$ORDER_SHA" "$REMOTE_WARNING"
  else
    printf 'state=%s order_id=%s sha256=%s evidence=remote-inbox+sha256-receipt\n' \
      "$REMOTE_STATE" "$ORDER_ID" "$ORDER_SHA"
  fi
}

verify() {
  RECEIPT_FILE="$RECEIPT_DIR/$ORDER_ID.receipt"
  read_receipt "$RECEIPT_FILE" || die "no valid local queued receipt for order '$ORDER_ID'"
  ORDER_SHA=$RECEIPT_SHA
  read_remote_state
  write_receipt "$REMOTE_STATE"
  case "$REMOTE_STATE" in
    queued) evidence=remote-inbox-missing-or-unreceived ;;
    transferred) evidence=remote-inbox+sha256-receipt ;;
    accepted) evidence=remote-inbox+sha256-receipt+worker-ack ;;
  esac
  if [[ -n "$REMOTE_WARNING" ]]; then
    printf 'state=%s order_id=%s sha256=%s evidence=%s warning=%s\n' \
      "$REMOTE_STATE" "$ORDER_ID" "$ORDER_SHA" "$evidence" "$REMOTE_WARNING"
  else
    printf 'state=%s order_id=%s sha256=%s evidence=%s\n' \
      "$REMOTE_STATE" "$ORDER_ID" "$ORDER_SHA" "$evidence"
  fi
}

main() {
  local command=${1:-}
  if [ "$#" -gt 0 ]; then
    shift
  fi
  case "$command" in
    --help|-h)
      [ "$#" -eq 0 ] || usage_error
      usage
      ;;
    deliver)
      [ "$#" -eq 2 ] || usage_error
      ORDER_ID=$1
      validate_id "$ORDER_ID"
      TARGET=brandon-compute
      prepare_local_state
      deliver "$2"
      ;;
    verify)
      [ "$#" -eq 1 ] || usage_error
      ORDER_ID=$1
      validate_id "$ORDER_ID"
      TARGET=brandon-compute
      prepare_local_state
      verify
      ;;
    *) usage_error ;;
  esac
}

main "$@"
