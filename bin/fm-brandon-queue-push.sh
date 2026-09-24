#!/usr/bin/env bash
# fm-brandon-queue-push.sh — deterministic controller queue publisher.
#
# Copies bounded message files from the local controller queue to the Brandon
# compute inbox over the pinned brandon-compute SSH coordinate, verifies the
# remote SHA256 before an atomic final rename, and records idempotent local
# receipts. Queue messages are never modified or deleted; on any failure the
# remote staging copy is removed best-effort and nothing lands in the inbox.
#
# Usage:
#   fm-brandon-queue-push.sh [--queue DIR] [--inbox DIR] [--state DIR]
#                            [--host NAME] [--ssh CMD] [--scp CMD]
#                            [--dry-run] [--help]
# Defaults:
#   --queue /root/agent-work/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute
#   --inbox /home/hd2admin/brandon-inbox
#   --state /root/agent-work/deightonllm-firstmate/state/brandon-queue-push
#   --host  brandon-compute   (pinned via ~/.ssh/config: UserKnownHostsFile +
#                              IdentityFile, IdentitiesOnly, BatchMode)
# Exit codes:
#   0 success (pushed and/or skipped)   2 usage/unsafe option path
#   3 pinned SSH identity missing       4 unsafe queue entry
#   5 remote hash mismatch              1 transport/other failure
# Receipts: one file per pushed message under --state, named
#   <sha256>.<basename>.receipt — a matching receipt makes a re-run skip.
set -euo pipefail
umask 077

DEFAULT_QUEUE=/root/agent-work/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute
DEFAULT_INBOX=/home/hd2admin/brandon-inbox
DEFAULT_STATE=/root/agent-work/deightonllm-firstmate/state/brandon-queue-push

QUEUE=$DEFAULT_QUEUE
INBOX=$DEFAULT_INBOX
STATE=$DEFAULT_STATE
HOST=brandon-compute
SSH_BIN=ssh
SCP_BIN=scp
DRY_RUN=0

usage() { awk 'NR>1 && /^set -euo pipefail$/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0; }

die() { # exit-code message
  echo "fm-brandon-queue-push: $2" >&2
  exit "$1"
}

need_safe_path() { # value label
  case "$1" in
    /*) ;;
    *) die 2 "$2 must be an absolute path" ;;
  esac
  case "$1" in
    *[!A-Za-z0-9/._-]*) die 2 "$2 contains unsafe characters: $1" ;;
  esac
  case "$1" in
    */..*|*../*) die 2 "$2 must not contain '..' segments" ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --queue) QUEUE=${2:?}; shift 2 ;;
    --inbox) INBOX=${2:?}; shift 2 ;;
    --state) STATE=${2:?}; shift 2 ;;
    --host) HOST=${2:?}; shift 2 ;;
    --ssh) SSH_BIN=${2:?}; shift 2 ;;
    --scp) SCP_BIN=${2:?}; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --help|-h) usage ;;
    *) die 2 "unknown option: $1" ;;
  esac
done

need_safe_path "$QUEUE" "--queue"
need_safe_path "$INBOX" "--inbox"
need_safe_path "$STATE" "--state"

[ -d "$QUEUE" ] || die 2 "queue directory does not exist: $QUEUE"

# --- pinned SSH coordinate check (stop condition: missing pinned identity) ---
pin_check() {
  local out identity known user hostname
  if ! out=$("$SSH_BIN" -G -- "$HOST" 2>/dev/null); then
    die 3 "cannot resolve ssh config for host '$HOST'"
  fi
  hostname=$(awk '$1=="hostname"{print $2; exit}' <<<"$out")
  user=$(awk '$1=="user"{print $2; exit}' <<<"$out")
  identity=$(awk '$1=="identityfile"{print $2; exit}' <<<"$out")
  known=$(awk '$1=="userknownhostsfile"{print $2; exit}' <<<"$out")
  [ -n "$hostname" ] || die 3 "no hostname pinned for '$HOST'"
  [ -n "$user" ] || die 3 "no user pinned for '$HOST'"
  [ -n "$identity" ] && [ -f "$identity" ] || die 3 "pinned identity file missing for '$HOST'"
  [ -n "$known" ] && [ -f "$known" ] || die 3 "pinned known_hosts file missing for '$HOST'"
}
pin_check

ssh_cmd() { "$SSH_BIN" -o BatchMode=yes -o StrictHostKeyChecking=yes "$HOST" "$1"; }
STAGING=$INBOX/.staging

# --- queue scan: classify before any transport (fail-safe) -------------------
candidates=()
while IFS= read -r -d '' entry; do
  base=$(basename "$entry")
  case "$base" in .*) continue ;; esac
  if [ -L "$entry" ] || [ ! -f "$entry" ]; then
    die 4 "unsafe queue entry (not a regular file): $entry"
  fi
  candidates+=("$entry")
done < <(find "$QUEUE" -mindepth 1 -maxdepth 1 -print0 | sort -z)

if [ "$DRY_RUN" = 1 ]; then
  printf 'dry-run: %d candidate(s) from %s -> %s@%s:%s\n' \
    "${#candidates[@]}" "$QUEUE" "$HOST" "$INBOX" "$INBOX"
  printf '  %s\n' "${candidates[@]:-}"
  exit 0
fi

mkdir -p "$STATE"
ssh_cmd "mkdir -p $INBOX $STAGING" >/dev/null

for entry in ${candidates[@]+"${candidates[@]}"}; do
  base=$(basename "$entry")
  local_sha=$(sha256sum "$entry" | awk '{print $1}')
  receipt=$STATE/$local_sha.$base.receipt
  if [ -f "$receipt" ]; then
    echo "skip (receipt exists): $base"
    continue
  fi
  tmp_name=$base.$$-$RANDOM
  tmp_remote=$STAGING/$tmp_name
  cleanup_remote() { ssh_cmd "rm -f '$tmp_remote'" >/dev/null 2>&1 || true; }
  trap 'cleanup_remote' EXIT

  if ! "$SCP_BIN" -o BatchMode=yes -o StrictHostKeyChecking=yes \
      "$entry" "$HOST:$tmp_remote" >/dev/null; then
    die 1 "scp failed for $base"
  fi
  remote_out=$(ssh_cmd "sha256sum $tmp_remote") || die 1 "remote sha256sum failed for $base"
  remote_sha=${remote_out%%[[:space:]]*}
  if [ "$remote_sha" != "$local_sha" ]; then
    cleanup_remote
    trap - EXIT
    die 5 "remote hash mismatch for $base (local $local_sha, remote $remote_sha)"
  fi
  ssh_cmd "mv '$tmp_remote' '$INBOX/$base'" >/dev/null || die 1 "atomic rename failed for $base"
  trap - EXIT

  ts=$(date -u +%Y%m%dT%H%M%SZ)
  tmp_receipt=$STATE/.receipt.$$.tmp
  printf 'sha256=%s\nfile=%s\ninbox=%s\nts=%s\n' "$local_sha" "$base" "$INBOX" "$ts" \
    >"$tmp_receipt"
  mv -f "$tmp_receipt" "$receipt"
  echo "pushed: $base ($local_sha)"
done

exit 0
