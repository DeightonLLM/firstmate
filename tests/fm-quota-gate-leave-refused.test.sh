#!/usr/bin/env bash
# Behavioural tests for the CAPTAIN-APPROVED NAMED REFUSAL in
# bin/fm-quota-gate.sh (captain ruling 2026-10-21, board question
# "quota-provider-binding", answer "leave-refused", provider "").
#
# The four harnesses claude, grok, kimi and opencode have NO provider account
# binding on this fleet. They must be refused BY NAME with exit 4 (cannot
# measure), the refusal must state WHY, and it must not be side-stepped by
# naming a model that maps to a bound provider. The harnesses that ARE bound
# (minimax-code/minimax, agy/agy-*, codex, zai, pi/pi-signed by model) must
# keep behaving exactly as before.
#
# The suite drives the gate's PUBLIC behaviour through a stub quota-axi
# emitting canned provider JSON - no source-text assertions.
#
# Usage: tests/fm-quota-gate-leave-refused.test.sh [path-to-gate-script]
#   The optional argument points the suite at another copy of the gate, which
#   is how the suite is proved RED-capable against the pre-change script.
set -u
ORIG_PWD=$PWD
cd "$(dirname "$0")/.."
REPO_ROOT=$PWD
GATE=${1:-}
if [ -z "$GATE" ]; then
  GATE="$REPO_ROOT/bin/fm-quota-gate.sh"
else
  case "$GATE" in
    /*) ;;
    *) GATE="$ORIG_PWD/$GATE" ;;
  esac
fi
TMP=$(mktemp -d)
cleanup() { python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)' "$TMP"; }
trap cleanup EXIT
PASS_COUNT=0; FAIL_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT+1)); echo "ok - $1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT+1)); echo "FAIL - $1"; }

stub() { # stub -> sets STUB_BIN, a quota-axi stand-in emitting the payload
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

# The reason the captain left these four unbound: no provider account binding
# exists, so quota-axi cannot measure the spend surface. An unmeasurable spend
# surface is not a verified-eligible surface.
REFUSE_MARKER="deliberately unbound"
REFUSE_MARKER2="no provider account binding exists"
REFUSE_MARKER3="unmeasurable spend surface is not a verified-eligible surface"

# --- fixture: one provider, parameterised ---
mk() { # mk <provider> <state> <semantics> <scope> <eff> <runway_status> <secs>
  payload "{\"providers\":[{\"provider\":\"$1\",\"state\":{\"status\":\"$2\"},\"quotaSemantics\":{\"status\":\"$3\",\"effectiveAvailability\":[{\"scope\":\"$4\",\"status\":\"known\",\"effectivePercentRemaining\":$5,\"runway\":{\"status\":\"$6\",\"usableRunwaySeconds\":$7}}]},\"windows\":[]}]}"
}

# A healthy payload for every provider the gate CAN bind, so that any refusal
# observed for the four unbound harnesses can only come from the named
# refusal path and not from an exhausted or stale provider.
payload '{"providers":[
{"provider":"minimax","state":{"status":"fresh"},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"model:general","status":"known","effectivePercentRemaining":90,"runway":{"status":"through_reset","usableRunwaySeconds":null}}]},"windows":[]},
{"provider":"agy","state":{"status":"fresh"},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":90,"runway":{"status":"through_reset","usableRunwaySeconds":null}}]},"windows":[]},
{"provider":"codex","state":{"status":"fresh"},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":90,"runway":{"status":"through_reset","usableRunwaySeconds":null}}]},"windows":[]},
{"provider":"zai","state":{"status":"fresh"},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":90,"runway":{"status":"through_reset","usableRunwaySeconds":null}}]},"windows":[]}
]}'
stub

# ---------------------------------------------------------------------------
# 1. Each of the four unbound harnesses is refused BY NAME with exit 4 and a
#    reason that states WHY it is refused.
# ---------------------------------------------------------------------------
for h in claude grok kimi opencode; do
  run_gate "$h" ""
  if [ "$RC" -eq 4 ] && echo "$OUT" | grep -q "REFUSE harness=$h" \
     && echo "$OUT" | grep -q "$REFUSE_MARKER" \
     && echo "$OUT" | grep -q "$REFUSE_MARKER2" \
     && echo "$OUT" | grep -q "$REFUSE_MARKER3"; then
    pass "$h refused by name with exit 4 and a stated reason (rc=$RC)"
  else
    fail "$h must be refused by name with exit 4 + reason (rc=$RC out=$OUT)"
  fi
done

# ---------------------------------------------------------------------------
# 2. The refusal must NOT be the generic "no provider mapping" fall-through:
#    it must be the named refusal.
# ---------------------------------------------------------------------------
run_gate claude ""
echo "$OUT" | grep -q "no provider mapping" \
  && fail "claude must not fall through to the generic no-provider-mapping refusal (out=$OUT)" \
  || pass "claude is refused by the named path, not the generic fall-through"

# ---------------------------------------------------------------------------
# 3. The refusal must not be side-stepped by a model prefix that maps to a
#    BOUND provider. Before the change, claude/grok/kimi/opencode with
#    --model gpt-6-* resolved to provider=codex and PASSED.
# ---------------------------------------------------------------------------
for h in claude grok kimi opencode; do
  for m in gpt-6-luna minimax/MiniMax-M3.1-Flash gemini-3.8-flash-medium; do
    run_gate "$h" "$m"
    if [ "$RC" -eq 4 ] && echo "$OUT" | grep -q "REFUSE harness=$h" \
       && echo "$OUT" | grep -q "$REFUSE_MARKER"; then
      pass "$h --model $m still refused by name (rc=$RC)"
    else
      fail "$h --model $m must still be refused by name (rc=$RC out=$OUT)"
    fi
  done
done

# ---------------------------------------------------------------------------
# 4. provider_for() must not resolve an unbound harness to any provider.
# ---------------------------------------------------------------------------
pf() { bash -c "source '$GATE' 2>/dev/null; provider_for '$1' '$2'"; }
for h in claude grok kimi opencode; do
  for m in "" gpt-6-luna minimax/MiniMax-M3.1-Flash gemini-3.8-flash-medium zai/glm-5.3-flash; do
    got=$(pf "$h" "$m")
    [ -z "$got" ] && pass "provider_for $h/$m -> (empty, unbound)" \
                  || fail "provider_for $h/$m must be empty, got '$got'"
  done
done

# ---------------------------------------------------------------------------
# 5. REGRESSION: the bound harnesses must behave exactly as before.
# ---------------------------------------------------------------------------
run_gate minimax-code minimax/MiniMax-M3.1-Flash
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=minimax" \
  && pass "minimax-code still passes (rc=$RC)" \
  || fail "minimax-code must still pass (rc=$RC out=$OUT)"

run_gate minimax minimax/MiniMax-M3.1-Flash
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=minimax" \
  && pass "minimax still passes (rc=$RC)" \
  || fail "minimax must still pass (rc=$RC out=$OUT)"

run_gate agy gemini-3.8-flash-medium
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=agy" \
  && pass "agy still passes (rc=$RC)" \
  || fail "agy must still pass (rc=$RC out=$OUT)"

run_gate codex gpt-6-luna
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=codex" \
  && pass "codex still passes (rc=$RC)" \
  || fail "codex must still pass (rc=$RC out=$OUT)"

run_gate zai glm-5.3-flash
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=zai" \
  && pass "zai still passes (rc=$RC)" \
  || fail "zai must still pass (rc=$RC out=$OUT)"

run_gate pi minimax/MiniMax-M2.7
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=minimax" \
  && pass "pi+minimax model still passes (rc=$RC)" \
  || fail "pi+minimax model must still pass (rc=$RC out=$OUT)"

run_gate pi zai/glm-5.3-flash
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=zai" \
  && pass "pi+zai model still passes (rc=$RC)" \
  || fail "pi+zai model must still pass (rc=$RC out=$OUT)"

run_gate pi openai-codex/gpt-6-luna
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=codex" \
  && pass "pi+codex model still passes (rc=$RC)" \
  || fail "pi+codex model must still pass (rc=$RC out=$OUT)"

# provider mapping for the bound harnesses is unchanged
mp() { [ "$(pf "$1" "$2")" = "$3" ] && pass "map $1/$2 -> $3" || fail "map $1/$2 should be $3, got '$(pf "$1" "$2")'"; }
mp minimax-code minimax/MiniMax-M3.1-Flash minimax
mp minimax minimax/MiniMax-M3.1-Flash minimax
mp agy gemini-3.8-flash-medium agy
mp codex gpt-6-luna codex
mp zai glm-5.3-flash zai
mp pi minimax/MiniMax-M2.7 minimax
mp pi zai/glm-5.3-flash zai
mp pi openai-codex/gpt-6-luna codex

# ---------------------------------------------------------------------------
# 6. REGRESSION: measured exhaustion and stale evidence still refuse as
#    before, and the exit-code contract is unchanged for bound providers.
# ---------------------------------------------------------------------------
mk codex fresh known all_models 5 through_reset null
stub; run_gate codex gpt-6-luna
[ "$RC" -eq 3 ] && echo "$OUT" | grep -q "REFUSE provider=codex effective=5%" \
  && pass "measured exhaustion still refuses exit 3 (rc=$RC)" \
  || fail "measured exhaustion must still refuse exit 3 (rc=$RC out=$OUT)"

mk codex stale known all_models 90 through_reset null
stub; run_gate codex gpt-6-luna
[ "$RC" -eq 4 ] && echo "$OUT" | grep -q "not fresh" \
  && pass "stale evidence still refuses exit 4 (rc=$RC)" \
  || fail "stale evidence must still refuse exit 4 (rc=$RC out=$OUT)"

# an unbound harness is refused even when quota-axi itself is missing
OUT=$(FM_QUOTA_AXI_BIN=/nonexistent/quota-axi "$GATE" check --harness claude --model "" 2>&1); RC=$?
[ "$RC" -eq 4 ] && echo "$OUT" | grep -q "REFUSE harness=claude" \
  && pass "unbound harness refused by name even without quota-axi (rc=$RC)" \
  || fail "unbound harness must be refused by name without quota-axi (rc=$RC out=$OUT)"

echo
echo "passed=$PASS_COUNT failed=$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
