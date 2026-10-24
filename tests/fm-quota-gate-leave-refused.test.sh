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
cd "$(dirname "$0")/.." || exit 1
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
healthy_payload() {
  payload '{"providers":[
{"provider":"minimax","state":{"status":"fresh"},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"model:general","status":"known","effectivePercentRemaining":90,"runway":{"status":"through_reset","usableRunwaySeconds":null}}]},"windows":[]},
{"provider":"agy","state":{"status":"fresh"},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"gemini","status":"known","effectivePercentRemaining":90,"runway":{"status":"through_reset","usableRunwaySeconds":null}}]},"windows":[]},
{"provider":"codex","state":{"status":"fresh"},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":90,"runway":{"status":"through_reset","usableRunwaySeconds":null}}]},"windows":[]},
{"provider":"zai","state":{"status":"fresh"},"quotaSemantics":{"status":"known","effectiveAvailability":[{"scope":"all_models","status":"known","effectivePercentRemaining":90,"runway":{"status":"through_reset","usableRunwaySeconds":null}}]},"windows":[]}
]}'
  stub
}
healthy_payload

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

# ---------------------------------------------------------------------------
# 7. FAMILY ALIASES. The refusal is a property of the harness FAMILY, not of
#    one spelling of it. This fleet spells the opencode harness "opencode"
#    but its own quota provider - the identifier its quota board, its
#    quota-axi output and its dispatch config use - is "opencode-go". Before
#    the fix, "--harness opencode-go --model gpt-6-luna" resolved to
#    provider=codex and PASSED, so the dispatch spent an unmeasured surface.
# ---------------------------------------------------------------------------
healthy_payload
for alias in opencode-go opencode-zen claude-code grok-build kimi-code; do
  for m in "" gpt-6-luna minimax/MiniMax-M3.1-Flash; do
    run_gate "$alias" "$m"
    if [ "$RC" -eq 4 ] && echo "$OUT" | grep -q "REFUSE harness=$alias" \
       && echo "$OUT" | grep -q "$REFUSE_MARKER" \
       && echo "$OUT" | grep -q "$REFUSE_MARKER2"; then
      pass "alias $alias --model $m is refused by family (rc=$RC)"
    else
      fail "alias $alias --model $m must be refused by family (rc=$RC out=$OUT)"
    fi
  done
done

# the family match must never refuse a DIFFERENT harness that merely shares a
# prefix with a refused family.
run_gate opencoder gpt-6-luna
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=codex"; then
  pass "a harness that only shares a prefix with a refused family is not refused (rc=$RC)"
else
  fail "a harness that only shares a prefix with a refused family must not be refused (rc=$RC out=$OUT)"
fi

# ---------------------------------------------------------------------------
# 8. THE RAW-LAUNCH HATCH. bin/fm-spawn.sh derives the harness name from the
#    FIRST word of a raw launch command, so a refused harness hidden behind
#    another word ("env opencode ...", "sh -c 'grok ...'") reached the gate
#    under a name the gate did not recognise, was measured against a bound
#    provider's quota, and passed. The gate reads the WHOLE command.
# ---------------------------------------------------------------------------
run_launch() { # run_launch <harness> <model> <launch-command>
  OUT=$(FM_QUOTA_AXI_BIN="$STUB_BIN" "$GATE" check --harness "$1" --model "$2" --launch-command "$3" 2>&1); RC=$?
}
for cmd in "env opencode --prompt hi" "sh -c 'grok --always-approve'" \
           "opencode-go --model gpt-6-luna" "FOO=1 claude --dangerously-skip-permissions"; do
  run_launch env gpt-6-luna "$cmd"
  if [ "$RC" -eq 4 ] && echo "$OUT" | grep -q "REFUSE launch command" \
     && echo "$OUT" | grep -q "$REFUSE_MARKER"; then
    pass "launch command naming a refused family is refused (rc=$RC)"
  else
    fail "launch command naming a refused family must be refused (rc=$RC out=$OUT)"
  fi
done

run_launch codex gpt-6-luna "codex --model gpt-6-luna"
[ "$RC" -eq 0 ] && echo "$OUT" | grep -q "PASS provider=codex" \
  && pass "a launch command naming a bound family still passes (rc=$RC)" \
  || fail "a launch command naming a bound family must still pass (rc=$RC out=$OUT)"

# ---------------------------------------------------------------------------
# 9. BINDING-ONLY. A dispatch path that carries no quota measurement (a
#    --secondmate launch) still routes through the leave-refused refusal.
# ---------------------------------------------------------------------------
OUT=$(FM_QUOTA_AXI_BIN="$STUB_BIN" "$GATE" check --harness opencode-go --model "" --binding-only 2>&1); RC=$?
[ "$RC" -eq 4 ] && echo "$OUT" | grep -q "REFUSE harness=opencode-go" \
  && pass "binding-only still refuses a refused family (rc=$RC)" \
  || fail "binding-only must refuse a refused family (rc=$RC out=$OUT)"

OUT=$(FM_QUOTA_AXI_BIN=/nonexistent/quota-axi "$GATE" check --harness codex --model "" --binding-only 2>&1); RC=$?
[ "$RC" -eq 0 ] \
  && pass "binding-only passes a bound family without measuring (rc=$RC)" \
  || fail "binding-only must pass a bound family without measuring (rc=$RC out=$OUT)"

# ---------------------------------------------------------------------------
# 10. REGRESSION: the generic "no provider mapping" refusal still fires for a
#     harness that is not refused by name.
# ---------------------------------------------------------------------------
run_gate omp ""
[ "$RC" -eq 4 ] && echo "$OUT" | grep -q "no provider mapping" \
  && pass "an unmapped harness still refuses with the generic reason (rc=$RC)" \
  || fail "an unmapped harness must still refuse with the generic reason (rc=$RC out=$OUT)"

# ---------------------------------------------------------------------------
# 11. THE DISPATCH ENTRY POINT. bin/fm-spawn.sh is the script that starts a
#     harness, so the refusal has to hold there: on every spawn kind, and
#     through the raw-launch hatch. These cases drive the real spawn script
#     and assert that it refuses with exit 4 and leaves no task record
#     behind. They use the tree's OWN gate (the spawn resolves it from its
#     own code root), so pointing this suite at another gate copy proves the
#     gate cases above, not these.
# ---------------------------------------------------------------------------
SPAWN="$REPO_ROOT/bin/fm-spawn.sh"
# A lane key the naming owner accepts, so the refusal cases are not masked
# by a lane-naming violation that a different rule owns.
PROBE_ID="mcode-m3.1f-hetz-qg-probe"
spawn_probe() { # spawn_probe <secondmate?> <spawn-args...> ; sets OUT, RC, PROBE_HOME
  local secondmate=$1; shift
  PROBE_HOME=$(mktemp -d "$TMP/spawn-home.XXXXXX")
  mkdir -p "$PROBE_HOME/data/$PROBE_ID" \
           "$PROBE_HOME/state" "$PROBE_HOME/projects" "$PROBE_HOME/config" \
           "$PROBE_HOME/project"
  printf 'brief\n' > "$PROBE_HOME/data/$PROBE_ID/brief.md"
  ( cd "$PROBE_HOME/project" && git init -q . && \
    git -c user.name=qg -c user.email=qg@example.invalid commit -q --allow-empty -m init ) >/dev/null 2>&1
  # A --secondmate launch stands up its own home, and that home may not live
  # inside the active firstmate home, so it gets its own seeded directory.
  PROBE_TARGET="$PROBE_HOME/project"
  if [ "$secondmate" = secondmate ]; then
    PROBE_TARGET=$(mktemp -d "$TMP/spawn-secondmate.XXXXXX")
    mkdir -p "$PROBE_TARGET/bin" "$PROBE_TARGET/data"
    printf '# Firstmate\n' > "$PROBE_TARGET/AGENTS.md"
    printf '%s\n' "$PROBE_ID" > "$PROBE_TARGET/.fm-secondmate-home"
    printf 'charter\n' > "$PROBE_TARGET/data/charter.md"
  fi
  OUT=$(HOME="$PROBE_HOME" FM_HOME="$PROBE_HOME" FM_ROOT_OVERRIDE="$REPO_ROOT" \
    FM_STATE_OVERRIDE="$PROBE_HOME/state" FM_DATA_OVERRIDE="$PROBE_HOME/data" \
    FM_PROJECTS_OVERRIDE="$PROBE_HOME/projects" FM_CONFIG_OVERRIDE="$PROBE_HOME/config" \
    FM_SPAWN_NO_GUARD=1 TMUX=fake,1,0 \
    timeout 60 bash "$SPAWN" "$PROBE_ID" "$PROBE_TARGET" "$@" 2>&1); RC=$?
}
spawn_refused() { # spawn_refused <label> <secondmate?> <spawn-args...>
  local label=$1 kind=$2; shift 2
  spawn_probe "$kind" "$@"
  if [ "$RC" -eq 4 ] && echo "$OUT" | grep -q "quota gate: REFUSE" \
     && echo "$OUT" | grep -q "$REFUSE_MARKER"; then
    pass "spawn refuses $label with exit 4 and the captain's reason (rc=$RC)"
  else
    fail "spawn must refuse $label with exit 4 + reason (rc=$RC out=$OUT)"
  fi
  if [ -f "$PROBE_HOME/state/$PROBE_ID.meta" ]; then
    fail "spawn refused $label but still wrote a task record"
  else
    pass "spawn refused $label and wrote no task record"
  fi
}

spawn_refused "a raw launch that hides opencode behind another word" crewmate \
  --harness "env opencode --prompt hi" --model gpt-6-luna
spawn_refused "a raw launch that hides grok behind another word" crewmate \
  --harness "sh -c 'grok --always-approve'" --model gpt-6-luna
spawn_refused "a raw launch on the opencode-go alias" crewmate \
  --harness "opencode-go --model gpt-6-luna"
spawn_refused "a secondmate launch on a refused family" secondmate \
  --harness claude --secondmate
spawn_refused "a secondmate launch on the opencode family" secondmate \
  --harness opencode --secondmate

echo
echo "passed=$PASS_COUNT failed=$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ]
