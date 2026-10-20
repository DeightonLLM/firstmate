#!/usr/bin/env bash
set -euo pipefail
FIX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export FM_HOME="$FIX/home"
export FM_STATE_OVERRIDE="$FIX/state"
rm -rf -- "$FM_STATE_OVERRIDE" "$FIX/inbox-controller-replies" "$FIX/inbox-home" "$FIX/inbox-deighton" "$FIX/inbox-firstmate" "$FIX/inbox-brandon"
mkdir -p "$FM_STATE_OVERRIDE" "$FIX/inbox-controller-replies" "$FIX/inbox-home" "$FIX/inbox-deighton" "$FIX/inbox-firstmate" "$FIX/inbox-brandon"
POLL="$FIX/controller-inbox.fixture.sh"
PASS=0
FAIL=0
result() { local label=$1 expected=$2 actual=$3; if [[ "$actual" == "$expected" ]]; then printf 'PASS %s expected=%q actual=%q exit=%s\n' "$label" "$expected" "$actual" "$4"; PASS=$((PASS+1)); else printf 'FAIL %s expected=%q actual=%q exit=%s\n' "$label" "$expected" "$actual" "$4"; FAIL=$((FAIL+1)); fi; }
call() { local out rc; set +e; out=$(bash "$POLL" "$@" 2>&1); rc=$?; set -e; printf '%s\n' "$out"; return "$rc"; }
# fixed baseline makes scenarios deterministic; no sleeps.
printf '1000\n' > "$FM_STATE_OVERRIDE/.controller-inbox-watermark"
printf 'fresh message\n' > "$FIX/inbox-controller-replies/fresh.md"
touch -d @2000 "$FIX/inbox-controller-replies/fresh.md"
out=$(call); rc=$?; fresh=$(printf '%s\n' "$out" | grep -c '^controller inbox update: fresh.md sha256=[a-f0-9]\{64\}$' || true); result fresh-surfaced 1 "$fresh" "$rc"
# no ack: poll advanced watermark, thus same hash and mtime is not re-notified.
out=$(call); rc=$?; result unacknowledged-next-sweep-silent '' "$out" "$rc"
# Exact ack of the surfaced bytes is accepted; subsequent sweep remains silent.
hash=$(sha256sum "$FIX/inbox-controller-replies/fresh.md" | cut -d' ' -f1)
out=$(call --ack fresh.md "$hash"); rc=$?; result exact-ack acknowledged: "$(printf '%s\n' "$out" | cut -d' ' -f1)" "$rc"
out=$(call); rc=$?; result acked-next-sweep-silent '' "$out" "$rc"
# A newly delivered file retaining an old mtime is below the advanced watermark.
printf 'arrived later, old timestamp\n' > "$FIX/inbox-controller-replies/oldmtime.md"
touch -d @2000 "$FIX/inbox-controller-replies/oldmtime.md"
out=$(call); rc=$?; result timestamp-preserving-arrival-silent '' "$out" "$rc"
# Duplicate identical bytes across fixture routes are emitted once in a sweep.
printf 'duplicate bytes\n' > "$FIX/inbox-home/duplicate.md"
printf 'duplicate bytes\n' > "$FIX/inbox-deighton/duplicate.md"
touch -d @$(($(date +%s)+10)) "$FIX/inbox-home/duplicate.md" "$FIX/inbox-deighton/duplicate.md"
out=$(call); rc=$?; count=$(printf '%s\n' "$out" | grep -c 'controller inbox update: duplicate.md' || true); result duplicate-emitted-once 1 "$count" "$rc"
# Ack digest must match exact current bytes, not earlier read bytes.
printf 'changed after read\n' > "$FIX/inbox-controller-replies/changed.md"
hash=$(sha256sum "$FIX/inbox-controller-replies/changed.md" | cut -d' ' -f1)
printf 'changed after read!\n' > "$FIX/inbox-controller-replies/changed.md"
set +e; out=$(call --ack changed.md "$hash"); rc=$?; set -e; result changed-bytes-refused refused: "$(printf '%s\n' "$out" | cut -d' ' -f1)" "$rc"
# Outbound hash is suppressed even when timestamp is newer than watermark.
printf 'sent by this home\n' > "$FIX/inbox-controller-replies/outbound.md"
hash=$(sha256sum "$FIX/inbox-controller-replies/outbound.md" | cut -d' ' -f1)
printf '%s\n' "$hash" > "$FM_STATE_OVERRIDE/.controller-inbox-outbound"
touch -d @$(($(date +%s)+20)) "$FIX/inbox-controller-replies/outbound.md"
out=$(call); rc=$?; result outbound-suppressed 0 "$(printf '%s\n' "$out" | grep -c 'outbound.md' || true)" "$rc"
printf 'SUMMARY PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
