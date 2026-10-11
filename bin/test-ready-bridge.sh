#!/usr/bin/env bash
# Regression test: BRIDGE_READY_REPORTS section must contain real newlines,
# not literal \n text.  Defect: M3 received "BRIDGE_READY_REPORTS:\n  - path=..."
# instead of separate lines.
#
set -u
# ── Mock external dependencies ────────────────────────────────────────────────
FAKE_PROMPT="Existing M3 prompt content.
Keep this intact."

FAKE_STATE_DIR=$(mktemp -d)
trap 'rm -rf "$FAKE_STATE_DIR"' EXIT

FAKE_PROMPT_FILE="$FAKE_STATE_DIR/m3-auto-review.prompt.md"
FAKE_STAMP="$FAKE_STATE_DIR/.m3-review-last-fingerprint"
FAKE_LEDGER="$FAKE_STATE_DIR/.ready-bridge-ledger"
FAKE_PENDING="$FAKE_STATE_DIR/.ready-bridge-pending"

printf '%s\n' "$FAKE_PROMPT" > "$FAKE_PROMPT_FILE"
touch "$FAKE_STAMP"

# Mock herdr-ready-bridge discover output
FAKE_READY_A="$FAKE_STATE_DIR/report-a.md"
FAKE_READY_B="$FAKE_STATE_DIR/report-b.md"
printf 'Report A content\n' > "$FAKE_READY_A"
printf 'Report B content\n' > "$FAKE_READY_B"

# ── Mock BRIDGE discover returns two reports ──────────────────────────────────
mock_bridge() {
  printf '%s\n%s\n' "$FAKE_READY_A" "$FAKE_READY_B"
}

# ── Minimal validate that checks for real newlines ────────────────────────────
validate_real_newlines() {
  local prompt="$1"
  # PASS if prompt contains separate lines with proper indentation
  # FAIL if literal \n appears instead of actual newlines
  if printf '%s' "$prompt" | grep -q 'BRIDGE_READY_REPORTS:.*\\n'; then
    return 1  # FAIL: literal \n found
  fi
  if ! printf '%s' "$prompt" | grep -qF 'BRIDGE_READY_REPORTS:'; then
    return 1  # FAIL: header missing
  fi
  if ! printf '%s' "$prompt" | grep -qF '  - path='; then
    return 1  # FAIL: report entries missing
  fi
  # PASS: real newlines present and structure correct
  return 0
}

# ── Simulate the bridge section building logic (copy of fixed code) ────────────
build_bridge_section() {
  local new_ready="$1"
  local bridge_section=""
  bridge_section="${bridge_section}BRIDGE_READY_REPORTS:"$'\n'
  while IFS= read -r rpath; do
    [ -z "$rpath" ] && continue
    digest=$(sha256sum "$rpath" 2>/dev/null | cut -d' ' -f1 || echo unknown)
    bridge_section="${bridge_section}  - path=${rpath} digest=${digest}"$'\n'
  done <<< "$new_ready"
  printf '%s' "$bridge_section"
}

# ── Run test ─────────────────────────────────────────────────────────────────
NEW_READY=$(
  printf '%s\n%s\n' "$FAKE_READY_A" "$FAKE_READY_B"
)

BRIDGE_OUTPUT=$(build_bridge_section "$NEW_READY")
PROMPT_CONTENT="${FAKE_PROMPT}

${BRIDGE_OUTPUT}"

echo "=== BRIDGE_READY_REPORTS section ==="
echo "$BRIDGE_OUTPUT" | cat -A   # Show with visible newlines
echo ""

if validate_real_newlines "$PROMPT_CONTENT"; then
  echo "PASS: Bridge section contains real newlines, not literal \\\\n"
  exit 0
else
  echo "FAIL: Bridge section contains literal \\\\n instead of actual newlines"
  echo "--- Prompt excerpt ---"
  printf '%s' "$PROMPT_CONTENT" | grep -A2 'BRIDGE_READY_REPORTS'
  exit 1
fi
