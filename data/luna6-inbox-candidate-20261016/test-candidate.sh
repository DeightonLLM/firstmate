#!/usr/bin/env bash
set -euo pipefail
CAND="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export FM_HOME="$CAND/home"
export FM_STATE_OVERRIDE="$CAND/state"
export TMPDIR="$CAND/tmp"
POLL="${POLL_OVERRIDE:-$CAND/controller-inbox.candidate.sh}"
for path in "$CAND" "$FM_HOME" "$FM_STATE_OVERRIDE" "$TMPDIR"; do
  mkdir -p "$path"
  [[ ! -L "$path" && "$(realpath -m -- "$path")" == "$CAND"* ]]
done
for route in inbox-controller-replies inbox-deighton inbox-firstmate inbox-brandon; do
  mkdir -p "$CAND/$route"
  [[ ! -L "$CAND/$route" && "$(realpath -m -- "$CAND/$route")" == "$CAND"* ]]
done
mkdir -p "$FM_HOME/inbox-home"
[[ ! -L "$FM_HOME/inbox-home" && "$(realpath -m -- "$FM_HOME/inbox-home")" == "$CAND"* ]]
# Refuse to run if any fixture path is a symlink or escapes the candidate root.
while IFS= read -r -d '' path; do
  [[ ! -L "$path" && "$(realpath -m -- "$path")" == "$CAND"* ]]
done < <(find "$CAND" -mindepth 1 -print0)
rm -rf -- "$FM_STATE_OVERRIDE" "$CAND/inbox-controller-replies" "$FM_HOME/inbox-home" "$CAND/inbox-deighton" "$CAND/inbox-firstmate" "$CAND/inbox-brandon" "$TMPDIR"
mkdir -p "$FM_STATE_OVERRIDE" "$CAND/inbox-controller-replies" "$FM_HOME/inbox-home" "$CAND/inbox-deighton" "$CAND/inbox-firstmate" "$CAND/inbox-brandon" "$TMPDIR"
PASS=0; FAIL=0
result() { local label=$1 expected=$2 actual=$3; if [[ "$actual" == "$expected" ]]; then printf 'PASS %s expected=%q actual=%q\n' "$label" "$expected" "$actual"; PASS=$((PASS+1)); else printf 'FAIL %s expected=%q actual=%q\n' "$label" "$expected" "$actual"; FAIL=$((FAIL+1)); fi; }
call() { bash "$POLL" "$@" 2>&1; }
count_line() { printf '%s\n' "$1" | awk -v p="$2" 'index($0,p)>0 {n++} END {print n+0}'; }
# First-run bootstrap accounts for known historical content and does not surface it.
printf 'historical\n' > "$CAND/inbox-controller-replies/historical.md"
touch -d @100 "$CAND/inbox-controller-replies/historical.md"
out=$(call); result first-run-exclusion 1 "$(printf '%s\n' "$out" | awk '/pre-existing message\(s\)/ {n++} END {print n+0}')"
[[ ! -s "$FM_STATE_OVERRIDE/.controller-inbox-handled" ]] || { echo 'FAIL first-run-does-not-acknowledge-history'; FAIL=$((FAIL+1)); }
# Set up an existing-watermark state only with candidate's explicit initialization marker.
if [[ "${TEST_MIGRATION:-0}" == 1 ]]; then
  rm -f -- "$FM_STATE_OVERRIDE/.controller-inbox-watermark" "$FM_STATE_OVERRIDE/.controller-inbox-initialized"
  printf '1000\n' > "$FM_STATE_OVERRIDE/.controller-inbox-watermark"
  notified_before=$(sha256sum "$FM_STATE_OVERRIDE/.controller-inbox-notified" | awk '{print $1}')
  set +e; out=$(call); migration_rc=$?; set -e
  result existing-watermark-migration-blocked 1 "$(count_line "$out" 'migration blocked')"
  result existing-watermark-migration-exit 3 "$migration_rc"
  [[ ! -f "$FM_STATE_OVERRIDE/.controller-inbox-initialized" ]] || { echo 'FAIL migration-not-silently-initialized'; FAIL=$((FAIL+1)); }
  [[ ! -f "$FM_STATE_OVERRIDE/.controller-inbox-handled" ]] || { echo 'FAIL migration-does-not-mark-handled'; FAIL=$((FAIL+1)); }
  notified_after=$(sha256sum "$FM_STATE_OVERRIDE/.controller-inbox-notified" | awk '{print $1}')
  result migration-notification-ledger-unchanged "$notified_before" "$notified_after"
  printf 'SUMMARY PASS=%s FAIL=%s\n' "$PASS" "$FAIL"; [[ "$FAIL" -eq 0 ]]; exit
fi
# Fresh arrival; remains discoverable pending exact-byte ack, but only notifies once.
printf 'fresh message\n' > "$CAND/inbox-controller-replies/fresh.md"
touch -d @$(($(date +%s)+60)) "$CAND/inbox-controller-replies/fresh.md"
out=$(call); result fresh-surfaced 1 "$(count_line "$out" 'controller inbox update: fresh.md')"
out=$(call); result pending-notification-dedup 0 "$(count_line "$out" 'controller inbox update: fresh.md')"
set +e; out=$(call --pending); pending_rc=$?; set -e; result pending-visible-before-ack 1 "$(count_line "$out" 'pending: fresh.md')"
hash=$(sha256sum "$CAND/inbox-controller-replies/fresh.md" | awk '{print $1}')
out=$(call --ack fresh.md "$hash"); result exact-ack 1 "$(count_line "$out" 'acknowledged: fresh.md')"
set +e; out=$(call --pending); pending_rc=$?; set -e; result removed-after-ack 0 "$(count_line "$out" 'pending: fresh.md')"
# Newly delivered old-mtime and same-second files are content-detected, not timestamp-gated.
printf 'arrived later, old timestamp\n' > "$CAND/inbox-controller-replies/oldmtime.md"
touch -d @2000 "$CAND/inbox-controller-replies/oldmtime.md"
out=$(call); result timestamp-preserving-arrival-detected 1 "$(count_line "$out" 'controller inbox update: oldmtime.md')"
printf 'same second arrival\n' > "$FM_HOME/inbox-home/samesecond.md"
touch -d @$(date +%s) "$FM_HOME/inbox-home/samesecond.md"
out=$(call); result same-second-arrival-detected 1 "$(count_line "$out" 'controller inbox update: samesecond.md')"
# Same digest across routes and repeated polls produces one notification total.
printf 'duplicate bytes\n' > "$FM_HOME/inbox-home/duplicate.md"
printf 'duplicate bytes\n' > "$CAND/inbox-deighton/duplicate.md"
touch -d @$(($(date +%s)+60)) "$FM_HOME/inbox-home/duplicate.md" "$CAND/inbox-deighton/duplicate.md"
out=$(call); result duplicate-emitted-once 1 "$(count_line "$out" 'controller inbox update: duplicate.md')"
out=$(call); result duplicate-repeat-suppressed 0 "$(count_line "$out" 'controller inbox update: duplicate.md')"
# Changed current bytes cannot be acknowledged using the digest previously read.
printf 'changed after read\n' > "$CAND/inbox-controller-replies/changed.md"
hash=$(sha256sum "$CAND/inbox-controller-replies/changed.md" | awk '{print $1}')
printf 'changed after read!\n' > "$CAND/inbox-controller-replies/changed.md"
set +e; out=$(call --ack changed.md "$hash"); rc=$?; set -e
result changed-bytes-refused 1 "$(count_line "$out" 'refused: Controller message changed after it was read')"
# Outbound bytes in bidirectional route remain excluded.
printf 'sent by this home\n' > "$CAND/inbox-controller-replies/outbound.md"
hash=$(sha256sum "$CAND/inbox-controller-replies/outbound.md" | awk '{print $1}')
printf '%s\n' "$hash" > "$FM_STATE_OVERRIDE/.controller-inbox-outbound"
out=$(call); result outbound-suppressed 0 "$(count_line "$out" 'controller inbox update: outbound.md')"
printf 'SUMMARY PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
