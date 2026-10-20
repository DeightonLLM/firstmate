#!/usr/bin/env bash
# F1 regression tests: same basename with different bytes across two routes.
# The candidate must resolve each item by its actual bytes, not first-match filename.
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
while IFS= read -r -d '' path; do
  [[ ! -L "$path" && "$(realpath -m -- "$path")" == "$CAND"* ]]
done < <(find "$CAND" -mindepth 1 -print0)

# Full reset
rm -rf -- "$FM_STATE_OVERRIDE" "$CAND/inbox-controller-replies" "$FM_HOME/inbox-home" \
  "$CAND/inbox-deighton" "$CAND/inbox-firstmate" "$CAND/inbox-brandon" "$TMPDIR"
mkdir -p "$FM_STATE_OVERRIDE" "$CAND/inbox-controller-replies" "$FM_HOME/inbox-home" \
  "$CAND/inbox-deighton" "$CAND/inbox-firstmate" "$CAND/inbox-brandon" "$TMPDIR"

PASS=0; FAIL=0
result() { local label=$1 expected=$2 actual=$3; if [[ "$actual" == "$expected" ]]; then printf 'PASS %s expected=%q actual=%q\n' "$label" "$expected" "$actual"; PASS=$((PASS+1)); else printf 'FAIL %s expected=%q actual=%q\n' "$label" "$expected" "$actual"; FAIL=$((FAIL+1)); fi; }
call() { bash "$POLL" "$@" 2>&1; }
count_line() { printf '%s\n' "$1" | awk -v p="$2" 'index($0,p)>0 {n++} END {print n+0}'; }

# ---- F1.0: Seed the candidate so --pending is available ----
# Place a seed message so the candidate initializes (not baseline).
# Ack it immediately so it does not pollute later pending-item counts.
printf 'seed message\n' > "$CAND/inbox-controller-replies/seed.md"
touch -d @100 "$CAND/inbox-controller-replies/seed.md"
out=$(call)
result seed-initialization 1 "$(count_line "$out" 'pre-existing message')"
[[ -f "$FM_STATE_OVERRIDE/.controller-inbox-initialized" ]] || { echo 'FAIL seed-not-initialized'; FAIL=$((FAIL+1)); }
seed_hash=$(sha256sum "$CAND/inbox-controller-replies/seed.md" | awk '{print $1}')
call --ack seed.md "$seed_hash" > /dev/null 2>&1 || { echo 'FAIL seed-ack-failed'; FAIL=$((FAIL+1)); }

# ---- F1.1: Poll emits one notification for the first hash ----
# Same basename in two routes with DIFFERENT bytes; poll must emit once.
printf 'bytes from route 1\n' > "$CAND/inbox-controller-replies/colli.md"
printf 'bytes from route 2\n' > "$CAND/inbox-deighton/colli.md"
touch -d @$(($(date +%s)+60)) "$CAND/inbox-controller-replies/colli.md" "$CAND/inbox-deighton/colli.md"
out=$(call)
result f1-poll-emits-once 1 "$(count_line "$out" 'controller inbox update: colli.md')"

# ---- F1.2: --pending can list both items by their distinct hashes ----
# Each distinct hash must appear in --pending output.
set +e; out=$(call --pending); pending_rc=$?; set -e
result f1-pending-exit-zero 0 "$pending_rc"
hash1=$(sha256sum "$CAND/inbox-controller-replies/colli.md" | awk '{print $1}')
hash2=$(sha256sum "$CAND/inbox-deighton/colli.md" | awk '{print $1}')
result f1-pending-lists-first-hash 1 "$(count_line "$out" "sha256=$hash1")"
result f1-pending-lists-second-hash 1 "$(count_line "$out" "sha256=$hash2")"
# The name appears twice with different hashes
result f1-pending-both-hashes-distinct 1 "$([[ "$hash1" != "$hash2" ]] && echo 1 || echo 0)"

# ---- F1.3: Each hash is individually acknowledgeable ----
# Ack the first hash: must succeed (using the filename + hash that matches
# the actual bytes in whichever route has that hash).
set +e; out=$(call --ack colli.md "$hash1"); rc=$?; set -e
result f1-ack-first-hash 0 "$rc"
result f1-ack-first-hash-output 1 "$(count_line "$out" 'acknowledged: colli.md')"
result f1-ack-first-hash-confirms 1 "$(count_line "$out" "sha256=$hash1")"

# The second hash must STILL be in --pending after the first is acked.
set +e; out=$(call --pending); set -e
result f1-second-hash-still-pending 1 "$(count_line "$out" "sha256=$hash2")"

# Ack the second hash: must succeed (not refused as "changed after read").
set +e; out=$(call --ack colli.md "$hash2"); rc=$?; set -e
result f1-ack-second-hash 0 "$rc"
result f1-ack-second-hash-output 1 "$(count_line "$out" 'acknowledged: colli.md')"
result f1-ack-second-hash-confirms 1 "$(count_line "$out" "sha256=$hash2")"

# ---- F1.4: Both colli.md hashes acked -> colli.md absent from --pending ----
set +e; out=$(call --pending); set -e
result f1-pending-colli-gone-after-both-acked 0 "$(count_line "$out" 'pending: colli.md')"

# ---- F1.5: Idempotent ack of already-handled hash is accepted ----
set +e; out=$(call --ack colli.md "$hash1"); rc=$?; set -e
result f1-ack-idempotent-exit 0 "$rc"
result f1-ack-idempotent-output 1 "$(count_line "$out" 'already-acknowledged: colli.md')"

# ---- F1.6: Stale hash is refused when the file no longer exists at that hash ----
# Remove the surviving deighton route copy so that neither route holds hash1.
# Then overwrite the controller-replies copy with new bytes; now hash1 is genuinely
# gone and locate_with_hash cannot find any file at that digest.
rm -f -- "$CAND/inbox-deighton/colli.md"
printf 'new bytes after acks\n' > "$CAND/inbox-controller-replies/colli.md"
touch -d @$(($(date +%s)+120)) "$CAND/inbox-controller-replies/colli.md"
set +e; out=$(call --ack colli.md "$hash1"); rc=$?; set -e
result f1-stale-hash-refused 1 "$(count_line "$out" 'refused: Controller message')"

printf 'SUMMARY PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
