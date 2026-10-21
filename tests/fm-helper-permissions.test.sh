#!/usr/bin/env bash
# tests/fm-helper-permissions.test.sh - Drift detection and mutation tests for
# helper permission rules.
#
# Verifies that:
#   1. bin/fm-helper-permissions-check.sh fails (RED) on configuration drift.
#   2. The test suite catches mutations: flipping or removing an entry fails.
#   3. Admitting forbidden secret paths fails closed with a safety hazard.
#   4. Canonical live host containment matches the tracked definition (GREEN).
set -u

# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-helper-permissions-check.sh"
TRACKED="$ROOT/docs/helper-permissions.json"

[ -x "$CHECK" ] || fail "check script not executable at $CHECK"
[ -f "$TRACKED" ] || fail "tracked definition missing at $TRACKED"

TMP_LAB=$(fm_test_tmproot helper-perm-test)
mkdir -p "$TMP_LAB"

# --- Test 1: Drift detection when tracked definition differs from live -------
test_drift_detected_on_stale_or_mutated_definition() {
  local mutated_def="$TMP_LAB/mutated-tracked.json"
  python3 - "$TRACKED" "$mutated_def" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
# Remove git from lean_ctx extra allowlist
if "git" in d.get("lean_ctx", {}).get("shell_allowlist_extra", []):
    d["lean_ctx"]["shell_allowlist_extra"].remove("git")
with open(sys.argv[2], "w") as f:
    json.dump(d, f, indent=2)
PY

  local out rc=0
  out=$("$CHECK" --tracked "$mutated_def" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "expected drift check to fail (exit 1), got $rc: $out"
  assert_contains "$out" "DRIFT: lean-ctx shell_allowlist_extra mismatch" \
    "drift check failed to report lean-ctx allowlist mismatch"
  pass "drift detection fails when tracked allowlist differs from live"
}

# --- Test 2: Mutation test on MiniMax read roots ----------------------------
test_minimax_read_root_mutation_fails() {
  local mutated_mm="$TMP_LAB/mutated-minimax.json"
  local mock_lc="$TMP_LAB/mock-lc.toml"
  local mock_cb="$TMP_LAB/mock-cb.toml"

  # Create mock lean-ctx configs matching tracked
  cat > "$mock_lc" <<'EOF'
shell_allowlist_extra = [
    "bin/fm-session-start.sh",
    "git",
    "read",
    "nproc",
    "uptime",
    "free",
    "df",
    "pi",
    "quota-axi",
]
EOF

  cat > "$mock_cb" <<'EOF'
exclude_paths = ["/root/.bash_history", "/root/.codex/auth.json", "/root/.gemini/antigravity-ide", "/root/.gemini/brain", "/root/.pi/sessions", "/root/.secrets", "/root/.ssh", "/root/secret-quarantine"]
shell_allowlist_extra = ["agent-secret-scan", "bash", "cat", "chmod", "command", "ctx_read", "ctx_search", "ctx_session", "ctx_tree", "df", "fm-install-shellcheck.sh", "fm-lint.sh", "fm-session-start.sh", "fm-test-run.sh", "free", "ls", "node", "npm", "ssh", "uptime", "xargs"]
EOF

  # Mutate minimax: remove /var/log/**
  cat > "$mutated_mm" <<'EOF'
{
  "version": 2,
  "allow": [
    {
      "tool_name": "bash",
      "matcher": { "kind": "path", "pattern": "/etc/**", "actions": ["read"] }
    }
  ]
}
EOF

  local out rc=0
  out=$("$CHECK" --tracked "$TRACKED" --lean-ctx "$mock_lc" --lean-ctx-contabo "$mock_cb" --minimax "$mutated_mm" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "expected minimax mutation to fail, got $rc: $out"
  assert_contains "$out" "DRIFT: minimax read_roots mismatch" \
    "drift check failed to report minimax read_roots mutation"
  pass "mutation test: flipping/removing MiniMax read roots is caught"
}

# --- Test 3: Safety check fails if secret path is admitted in tracked -------
test_safety_check_blocks_secret_read_roots() {
  local hazard_def="$TMP_LAB/hazard-tracked.json"
  python3 - "$TRACKED" "$hazard_def" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
# Inappropriately add /root/.secrets to read_roots
d["minimax"]["read_roots"].append("/root/.secrets")
with open(sys.argv[2], "w") as f:
    json.dump(d, f, indent=2)
PY

  local out rc=0
  out=$("$CHECK" --tracked "$hazard_def" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "expected safety hazard check to fail, got $rc: $out"
  assert_contains "$out" "SAFETY HAZARD: tracked rules admit forbidden secret root" \
    "drift check failed to catch secret root hazard"
  pass "safety guard rejects tracked rules that admit secret paths"
}

# --- Test 4: Live host check passes when tracked definition is correct ------
test_canonical_live_host_matches() {
  local out rc=0
  out=$("$CHECK" 2>&1) || rc=$?
  [ "$rc" -eq 0 ] || fail "canonical live host check failed (exit $rc): $out"
  assert_contains "$out" "PASS: helper permission rules match live configurations with 0 drift" \
    "missing PASS verification summary"
  pass "canonical live host containment matches tracked definition"
}

# Execute tests
test_drift_detected_on_stale_or_mutated_definition
test_minimax_read_root_mutation_fails
test_safety_check_blocks_secret_read_roots
test_canonical_live_host_matches

printf '1..4\n'
