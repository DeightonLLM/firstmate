#!/usr/bin/env bash
# Behavioural tests for bin/fm-quota-gate.sh (captain ruling 2026-10-13:
# quota-axi enforced at dispatch). Every test drives the gate's PUBLIC
# behaviour through a stub quota-axi emitting canned provider JSON - no
# source-text assertions.
set -u
cd "$(dirname "$0")/.."
GATE=bin/fm-quota-gate.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
PASS_COUNT=0; FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT+1)); echo "ok - $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL - $1"; }

stub() { # stub <json-file-content-on-stdin> -> sets STUB_BIN
  cat > "$TMP/fake-quota-axi" <<EOF
#!/usr/bin/env bash
cat "$TMP/payload.json"
EOF
  chmod +x "$TMP/fake-quota-axi"; STUB_BIN="$TMP/fake-quota-axi"
}
payload() { printf '%s' "$1" > "$TMP/payload.json"; }

run_gate() { # run_gate <harness> <model> ; sets OUT and RC
  OUT=$(FM_QUOTA_AXI_BIN="$STUB_BIN" "$GATE" check --harness "$1" --model "$2" 2>&1); RC=$?
}

# --- fixture: one provider, parameterised ---
mk() { # mk <provider> <state> <semantics> <scope> <eff> <runway_status> <secs>
  payload "{\"providers\":[{\"provider\":\"$1\",\"state\":{\"status\":\"$2\"},\"quotaSemantics\":{\"status\":\"$3\",\"effectiveAvailability\":[{\"scope\":\"$4\",\"status\":\"known\",\"effectivePercentRemaining\":$5,\"runway\":{\"status\":\"$6\",\"usableRunwaySeconds\":$7}}]},\"windows\":[]}]}"
}

# 1. healthy provider passes
mk agy fresh known gemini 33 through_reset null
stub; run_gate agy gemini-3.8-flash-medium
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=agy effective=33" && pass "healthy agy passes at 33%" || fail "healthy agy should pass (rc=$RC out=$OUT)"

# 2. exhausted percent refuses (exit 3)
mk codex fresh known all_models 5 through_reset null
stub; run_gate codex gpt-6-luna
[ "$RC" -eq 3 ] && echo "$OUT" | grep -q "REFUSE provider=codex effective=5%" && pass "5% refuses with exit 3" || fail "5% should refuse exit 3 (rc=$RC out=$OUT)"

# 3. projected exhaustion inside runway floor refuses
mk codex fresh known all_models 40 projected_exhaustion 1825
stub; run_gate codex gpt-6-luna
[ "$RC" -eq 3 ] && echo "$OUT" | grep -q "runway=1825s" && pass "1825s runway refuses" || fail "short runway should refuse (rc=$RC out=$OUT)"

# 4. projected exhaustion beyond runway floor passes
mk codex fresh known all_models 40 projected_exhaustion 287903
stub; run_gate codex gpt-6-luna
[ "$RC" -eq 0 ] && pass "287903s runway passes" || fail "long runway should pass (rc=$RC out=$OUT)"

# 5. boundary: exactly at the 10% floor refuses, 11% passes
mk minimax fresh known model:general 10 through_reset null
stub; run_gate minimax-code minimax/MiniMax-M3.1-Flash
[ "$RC" -eq 3 ] && pass "exactly 10% refuses (<= floor)" || fail "10% is <= floor and must refuse (rc=$RC out=$OUT)"
mk minimax fresh known model:general 11 through_reset null
stub; run_gate minimax-code minimax/MiniMax-M3.1-Flash
[ "$RC" -eq 0 ] && pass "11% passes" || fail "11% should pass (rc=$RC out=$OUT)"

# 6. unmeasured semantics discloses and passes (AGENTS.md section 4)
payload '{"providers":[{"provider":"agy","state":{"status":"fresh"},"quotaSemantics":{"status":"unknown","effectiveAvailability":[]},"windows":[]}]}'
stub; run_gate agy gemini-3.8-flash-medium
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "UNMEASURED" && pass "unmeasured discloses UNMEASURED and passes" || fail "unmeasured should disclose and pass (rc=$RC out=$OUT)"

# 7. unauthenticated provider refuses
mk codex auth_required unknown all_models 50 through_reset null
stub; run_gate codex gpt-6-luna
[ "$RC" -eq 4 ] && echo "$OUT" | grep -q "not authenticated" && pass "auth_required refuses exit 4" || fail "auth_required should refuse 4 (rc=$RC out=$OUT)"

# 8. missing provider block refuses (fail-closed)
payload '{"providers":[{"provider":"zai","state":{"status":"fresh"},"quotaSemantics":{"status":"known","effectiveAvailability":[]},"windows":[]}]}'
stub; run_gate claude ""
[ "$RC" -eq 4 ] && pass "missing provider block refuses exit 4" || fail "missing provider must refuse 4 (rc=$RC out=$OUT)"

# 9. quota-axi binary missing refuses (fail-closed)
payload '{"providers":[]}'
stub; run_gate agy gemini-3.8-flash-medium
OUT=$(FM_QUOTA_AXI_BIN=/nonexistent/quota-axi "$GATE" check --harness agy --model x 2>&1); RC=$?
[ "$RC" -eq 4 ] && echo "$OUT" | grep -q "not available" && pass "missing binary refuses exit 4" || fail "missing binary should refuse 4 (rc=$RC out=$OUT)"

# 10. malformed JSON refuses (fail-closed)
payload 'not-json-at-all'
stub; run_gate agy gemini-3.8-flash-medium
[ "$RC" -eq 4 ] && pass "malformed payload refuses exit 4" || fail "malformed payload should refuse 4 (rc=$RC out=$OUT)"

# 11. worst-scope rule: multi-scope provider admits on the MINIMUM scope
payload '{"providers":[{"provider":"agy","state":{"status":"fresh"},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":8,"runway":{"status":"through_reset","usableRunwaySeconds":null}},{"scope":"claude_gpt","status":"known","effectivePercentRemaining":95,"runway":{"status":"through_reset","usableRunwaySeconds":null}}]},"windows":[]}]}'
stub; run_gate agy gemini-3.8-flash-medium
[ "$RC" -eq 3 ] && echo "$OUT" | grep -q "effective=8%" && pass "worst scope (8%) refuses despite healthy 95% scope" || fail "worst-scope 8% must refuse (rc=$RC out=$OUT)"

# 12. provider mapping
mp() { [ "$(bash -c "source $GATE 2>/dev/null; provider_for '$1' '$2'")" = "$3" ] && pass "map $1/$2 -> $3" || fail "map $1/$2 should be $3"; }
mp minimax-code minimax/MiniMax-M3.1-Flash minimax
mp agy gemini-3.8-flash-medium agy
mp codex gpt-6-luna codex
mp pi minimax/MiniMax-M2.7 minimax
mp pi zai/glm-5.3-flash zai

echo
echo "passed=$PASS_COUNT failed=$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
