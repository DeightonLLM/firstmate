#!/usr/bin/env bash
# Deterministic Luna quota routing guard tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
GATE="$ROOT/bin/fm-luna-quota-gate.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/fm-luna-quota.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT
FAKE="$TMP/quota-axi"
FIXTURE="$TMP/quota.json"
CALLS="$TMP/calls"

cat > "$FAKE" <<'EOF'
#!/usr/bin/env bash
set -u
[[ "${1:-}" == --json && "$#" -eq 1 ]] || exit 64
printf '%s\n' "$*" >> "${QUOTA_AXI_CALLS:?}"
if [[ "${QUOTA_AXI_FAIL:-0}" == 1 ]]; then exit 1; fi
cat "${QUOTA_AXI_FIXTURE:?}"
EOF
chmod 755 "$FAKE"

write_fixture() {
  printf '%s\n' "$1" > "$FIXTURE"
}

run_gate() {
  QUOTA_AXI_BIN="$FAKE" QUOTA_AXI_CALLS="$CALLS" QUOTA_AXI_FIXTURE="$FIXTURE" \
    QUOTA_AXI_FAIL="${QUOTA_AXI_FAIL:-0}" "$GATE" gpt-5.6-terra medium
}

assert_route() {
  local label=$1 fixture=$2 expected_model=$3 expected_effort=$4
  write_fixture "$fixture"
  : > "$CALLS"
  local out
  out=$(run_gate)
  grep -Fxq "MODEL=$expected_model" <<<"$out" || { echo "FAIL $label: model" >&2; exit 1; }
  grep -Fxq "EFFORT=$expected_effort" <<<"$out" || { echo "FAIL $label: effort" >&2; exit 1; }
  [[ "$(cat "$CALLS")" == --json ]] || { echo "FAIL $label: quota call shape" >&2; exit 1; }
}

assert_route "above threshold preserves requested route" \
  '{"providers":[{"provider":"codex","windows":[{"id":"five_hour","percentRemaining":16}]}]}' \
  gpt-5.6-terra medium

assert_route "exactly threshold routes Luna Max" \
  '{"providers":[{"provider":"codex","windows":[{"id":"five_hour","percentRemaining":15}]}]}' \
  gpt-5.6-luna max

assert_route "below threshold routes Luna Max" \
  '{"providers":[{"provider":"codex","windows":[{"id":"five_hour","percentRemaining":14.9}]}]}' \
  gpt-5.6-luna max

: > "$CALLS"
QUOTA_AXI_FAIL=1
if run_gate >/dev/null 2>&1; then
  echo 'FAIL unavailable quota data was allowed' >&2
  exit 1
fi
[[ "$(cat "$CALLS")" == --json ]] || { echo 'FAIL unavailable quota was not queried data-only' >&2; exit 1; }
unset QUOTA_AXI_FAIL

write_fixture '{"providers":[{"provider":"codex","windows":[{"id":"weekly","percentRemaining":99}]}]}'
if run_gate >/dev/null 2>&1; then
  echo 'FAIL malformed/missing five-hour window was allowed' >&2
  exit 1
fi

# Existing workers bypass the new-worker quota intake and keep their route,
# even when quota data is unavailable; this proves no interruption/reroute.
: > "$CALLS"
QUOTA_AXI_FAIL=1
out=$(QUOTA_AXI_BIN="$FAKE" QUOTA_AXI_CALLS="$CALLS" QUOTA_AXI_FIXTURE="$FIXTURE" \
  QUOTA_AXI_FAIL=1 "$GATE" --existing-worker gpt-5.6-luna medium)
grep -Fxq 'MODEL=gpt-5.6-luna' <<<"$out" || { echo 'FAIL existing worker model changed' >&2; exit 1; }
grep -Fxq 'EFFORT=medium' <<<"$out" || { echo 'FAIL existing worker effort changed' >&2; exit 1; }
[[ ! -s "$CALLS" ]] || { echo 'FAIL existing worker queried quota' >&2; exit 1; }

# Test npx fallback when quota-axi is not on PATH and QUOTA_AXI_BIN is unset
FAKE_NPX_DIR="$TMP/fake-npx"
mkdir -p "$FAKE_NPX_DIR"
cat > "$FAKE_NPX_DIR/npx" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${FAKE_NPX_CALLS:?}"
cat "${FAKE_NPX_FIXTURE:?}"
EOF
chmod 755 "$FAKE_NPX_DIR/npx"

FAKE_NPX_CALLS="$TMP/npx-calls"
FAKE_NPX_FIXTURE="$TMP/npx-fixture"
printf '{"providers":[{"provider":"codex","windows":[{"id":"five_hour","percentRemaining":12}]}]}' > "$FAKE_NPX_FIXTURE"
: > "$FAKE_NPX_CALLS"

out=$(PATH="$FAKE_NPX_DIR:$PATH" FAKE_NPX_CALLS="$FAKE_NPX_CALLS" FAKE_NPX_FIXTURE="$FAKE_NPX_FIXTURE" \
  "$GATE" gpt-5.6-terra medium)
grep -Fxq 'MODEL=gpt-5.6-luna' <<<"$out" || { echo 'FAIL npx fallback model' >&2; exit 1; }
grep -Fxq 'EFFORT=max' <<<"$out" || { echo 'FAIL npx fallback effort' >&2; exit 1; }
grep -Eq -- '-y quota-axi.*--json' "$FAKE_NPX_CALLS" || { echo 'FAIL npx call shape' >&2; exit 1; }

echo 'PASS: Luna quota gate >15%, =15%, <15%, unavailable, malformed, existing-worker, and npx fallback cases'
