#!/usr/bin/env bash
# Async M3 review trigger.  Never waits for M3 and never starts a worker.
# Integrates herdr-ready-bridge for controller-level READY_FOR_M3_REVIEW
# discovery (covers retired-lane orphans that lack state/ metadata).
#
# Commit-on-success semantics:
#   1. Bridge discovers new READY reports and writes them to a PENDING file.
#   2. This script validates the prompt and sends to M3.
#   3. On SUCCESS: commits pending digests to the permanent ledger.
#   4. On FAILURE: discards pending entries so the next poll can retry.
#
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
STATE="${FM_STATE_OVERRIDE:-$FM_ROOT/state}"
META="$STATE/subagent-cap-v1.meta"
PROMPT="$STATE/m3-auto-review.prompt.md"
STAMP="$STATE/.m3-review-last-fingerprint"
LEDGER="$STATE/.ready-bridge-ledger"
PENDING="$STATE/.ready-bridge-pending"
REVIEW_LOG="${FM_M3_REVIEW_LOG:-$FM_ROOT/data/subagent-cap-v1/m3-review-log.md}"

# Env-overridable for testing isolation.  Never call real commands during tests.
BRIDGE="${FM_BRIDGE_BIN:-/root/bin/herdr-ready-bridge}"
VALIDATE_BIN="${FM_VALIDATE_BIN:-/root/bin/validate-herdr-lane-prompt}"
SEND_BIN="${FM_SEND_BIN:-/root/bin/herdr-send-submit}"
JQ_BIN="${FM_JQ_BIN:-jq}"
HERDR_BIN="${FM_HERDR_BIN:-herdr}"

[ -r "$META" ] || exit 0
[ -r "$PROMPT" ] || exit 0

session=$(sed -n 's/^herdr_session=//p' "$META" | head -1)
pane=$(sed -n 's/^herdr_pane_id=//p' "$META" | head -1)
[ -n "$session" ] && [ -n "$pane" ] || exit 0

# Only dispatch when the protected pane is idle/done; never interrupt M3.
live=$("$HERDR_BIN" pane list 2>/dev/null || true)
status=$(printf '%s' "$live" | "$JQ_BIN" -r --arg p "$pane" '.result.panes[]? | select(.pane_id==$p) | .agent_status' 2>/dev/null | head -1)
case "$status" in idle|done) ;; *) exit 0 ;; esac

# ── Primary fingerprint: state/ files ─────────────────────────────────────────
fingerprint=$(find "$STATE" -maxdepth 1 -type f \
  \( -name '*.status' -o -name '*.report' -o -name '*.meta' \) \
  -printf '%f:%T@:%s\n' 2>/dev/null | sort | sha256sum | cut -d' ' -f1)
[ -n "$fingerprint" ] || exit 0

# ── Bridge: controller-level READY_FOR_M3_REVIEW discovery ────────────────────
# Scans allowlisted roots (FM_ROOT/data, /root/agent-work, etc.).
# Writes pending entries before claiming; commits only after M3 send succeeds.
# Idempotent: historical digests already in LEDGER are skipped.
new_ready=""
bridge_hash=""
bridge_pending=""
if [ -x "$BRIDGE" ]; then
  # Tests may inject one temporary root. Production leaves this unset so the
  # bridge retains its bounded controller-level allowlist.
  bridge_args=()
  if [ -n "${FM_BRIDGE_ROOT:-}" ]; then
    bridge_args+=(--root "$FM_BRIDGE_ROOT")
  fi
  discovered_ready=$("$BRIDGE" discover \
    "${bridge_args[@]}" \
    --ledger "$LEDGER" \
    --pending "$PENDING" \
    --stamp  "$STATE/.ready-bridge-stamp" \
    2>/dev/null || true)
  # A manual/direct M3 handoff may have been accepted before the bridge ledger
  # was updated.  Consult the authoritative M3 review ledger by digest before
  # dispatching discovered reports; otherwise the periodic supervisor can
  # replay an already-reviewed batch.  Baseline those digests so later polls
  # remain idempotent.  A changed report has a new digest and is not suppressed.
  if [ -n "$discovered_ready" ]; then
    while IFS= read -r rpath; do
      [ -z "$rpath" ] && continue
      digest=$(sha256sum "$rpath" 2>/dev/null | cut -d' ' -f1 || true)
      if [ -n "$digest" ] && [ -r "$REVIEW_LOG" ] && rg -q --fixed-strings "$digest" "$REVIEW_LOG"; then
        "$BRIDGE" ledger-baseline "$rpath" "$digest" \
          --ledger "$LEDGER" 2>/dev/null || true
        continue
      fi
      new_ready="${new_ready}${rpath}"$'\n'
    done <<< "$discovered_ready"
    new_ready=${new_ready%$'\n'}
  fi
  if [ -n "$new_ready" ]; then
    bridge_hash=$(printf '%s' "$new_ready" | sort | sha256sum | cut -d' ' -f1)
    fingerprint="${fingerprint}:bridge:${bridge_hash}"

    # Capture the combined digest of all pending reports for commit/discard.
    # Build pending file path list for the commit step.
    bridge_pending="$new_ready"
  fi
fi

# Idempotency: skip if nothing changed since last run.
# A successful READY dispatch stores `base-fingerprint:bridge:reports-hash`.
# On the next poll the bridge may correctly return no new reports, leaving only
# the base fingerprint. Compare the base portion in that case; otherwise every
# post-dispatch poll would look new and resend an empty base prompt to M3.
stored_stamp=$(cat "$STAMP" 2>/dev/null || true)
if [ -n "$new_ready" ]; then
  [ "$stored_stamp" = "$fingerprint" ] && exit 0
else
  stored_base=${stored_stamp%%:bridge:*}
  [ "$stored_base" = "$fingerprint" ] && exit 0
fi

# ── Build M3 prompt (with bridge extension if new READY reports found) ─────────
prompt_content=$(cat "$PROMPT")
if [ -n "$new_ready" ]; then
  bridge_section=""
  bridge_section="${bridge_section}BRIDGE_READY_REPORTS:"$'\n'
  while IFS= read -r rpath; do
    [ -z "$rpath" ] && continue
    digest=$(sha256sum "$rpath" 2>/dev/null | cut -d' ' -f1 || echo unknown)
    bridge_section="${bridge_section}  - path=${rpath} digest=${digest}"$'\n'
  done <<< "$new_ready"
  prompt_content="${prompt_content}

${bridge_section}"
fi

# Validate prompt structure before sending.
if ! "$VALIDATE_BIN" < <(printf '%s' "$prompt_content") >/dev/null 2>&1; then
  # Validation failed — discard any pending entries so the next poll retries.
  if [ -n "$bridge_pending" ] && [ -n "$BRIDGE" ]; then
    while IFS= read -r rpath; do
      [ -z "$rpath" ] && continue
      digest=$(sha256sum "$rpath" 2>/dev/null | cut -d' ' -f1 || true)
      [ -n "$digest" ] && BRIDGE_DISCARD_DIGEST="$digest" "$BRIDGE" discard \
        --ledger "$LEDGER" --pending "$PENDING" 2>/dev/null || true
    done <<< "$bridge_pending"
  fi
  exit 0
fi

# ── Send to M3 ─────────────────────────────────────────────────────────────────
if "$SEND_BIN" "$pane" "$prompt_content" >/dev/null 2>&1; then
  # SUCCESS: update stamp AND commit all pending digests to the permanent ledger.
  printf '%s\n' "$fingerprint" > "$STAMP"

  if [ -n "$bridge_pending" ] && [ -x "$BRIDGE" ]; then
    while IFS= read -r rpath; do
      [ -z "$rpath" ] && continue
      digest=$(sha256sum "$rpath" 2>/dev/null | cut -d' ' -f1 || true)
      [ -n "$digest" ] && BRIDGE_COMMIT_DIGEST="$digest" "$BRIDGE" commit \
        --ledger "$LEDGER" --pending "$PENDING" 2>/dev/null || true
    done <<< "$bridge_pending"
  fi
else
  # FAILURE: discard pending entries so the next poll can rediscover and retry.
  if [ -n "$bridge_pending" ] && [ -n "$BRIDGE" ]; then
    while IFS= read -r rpath; do
      [ -z "$rpath" ] && continue
      digest=$(sha256sum "$rpath" 2>/dev/null | cut -d' ' -f1 || true)
      [ -n "$digest" ] && BRIDGE_DISCARD_DIGEST="$digest" "$BRIDGE" discard \
        --ledger "$LEDGER" --pending "$PENDING" 2>/dev/null || true
    done <<< "$bridge_pending"
  fi
fi
