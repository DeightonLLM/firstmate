#!/usr/bin/env bash
# fm-pane-isolation.test.sh - the pane-isolation guard must refuse exactly the documented
# operations and nothing else.
#
# The rule (docs/audits-20260928/AGENTSEC.md 3.5): never split the operator's coordinator pane
# to stack worker panes on it. AGENTSEC 5.1 (GAP-01): the Pi hook did not intercept raw
# send-text / send-keys, so those are refused here too.
#
# The suite is hermetic: a fake `herdr` on PATH reports a fixed coordinator pane id, so the
# verdict never depends on the live surface. It is also non-vacuous: it asserts that the guard
# DOES refuse the forbidden cases, so a guard that always allows cannot pass.
set -uo pipefail

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SELF_DIR/.." && pwd)"
GUARD="$REPO_ROOT/bin/fm-pane-isolation-guard.sh"
PLUGIN_HOOKS="$REPO_ROOT/extensions/mcode-pane-isolation/hooks/hooks.json"
COORD_PANE="wK:p1Q"
OTHER_PANE="wK:p9Z"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

ok_count=0
not_ok_count=0

ok() {
  ok_count=$((ok_count + 1))
  printf 'ok %d - %s\n' "$ok_count" "$1"
}

not_ok() {
  not_ok_count=$((not_ok_count + 1))
  printf 'not ok %d - %s\n' "$not_ok_count" "$1"
}

# A fake herdr: `pane current` reports the coordinator pane id, everything else is a no-op.
mkdir -p "$WORK/bin"
cat >"$WORK/bin/herdr" <<'HERDR_EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "pane" ] && [ "${2:-}" = "current" ]; then
  printf '{"id":"cli:pane:current","result":{"pane":{"pane_id":"wK:p1Q"},"type":"pane_info"}}\n'
  exit 0
fi
exit 0
HERDR_EOF
chmod 0755 "$WORK/bin/herdr"

# run_guard <command-string> -> prints the guard's stdout
run_guard() {
  local cmd="$1"
  local payload
  payload="$(printf '{"tool_name":"Bash","tool_input":{"command":%s},"session_id":"test-session"}' \
    "$(printf '%s' "$cmd" | python3 -c 'import json,sys;print(json.dumps(sys.stdin.read()))')")"
  # The suite must be hermetic. The guard honours HERDR_BIN_PATH and
  # HERDR_PANE_ID by design (an operator may pin the real binary and the live
  # coordinator pane), and a herdr session exports BOTH into the ambient
  # environment. Inherited, they beat the fake herdr on PATH, so the guard
  # compared against the LIVE coordinator pane and every "refused" case
  # silently became "allowed". Clear them so the stub is the only source.
  printf '%s' "$payload" | env -u HERDR_BIN_PATH -u HERDR_PANE_ID \
    PATH="$WORK/bin:$PATH" FM_HOME="$WORK/home" bash "$GUARD" 2>/dev/null
}

is_denied() {
  local out="$1"
  printf '%s' "$out" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("ALLOW"); raise SystemExit(0)
try:
    data = json.loads(raw)
except Exception:
    print("GARBAGE"); raise SystemExit(0)
hook = data.get("hookSpecificOutput") or {}
deny = data.get("decision") == "deny" or hook.get("permissionDecision") == "deny"
print("DENY" if deny else "ALLOW")
'
}

expect_deny() {
  local label="$1" cmd="$2" out verdict
  out="$(run_guard "$cmd")"
  verdict="$(is_denied "$out")"
  if [ "$verdict" = "DENY" ]; then
    ok "$label is refused"
  else
    not_ok "$label is refused (verdict=$verdict output=$(printf '%s' "$out" | head -c 160))"
  fi
}

expect_allow() {
  local label="$1" cmd="$2" out verdict
  out="$(run_guard "$cmd")"
  verdict="$(is_denied "$out")"
  if [ "$verdict" = "ALLOW" ]; then
    ok "$label is allowed"
  else
    not_ok "$label is allowed (verdict=$verdict output=$(printf '%s' "$out" | head -c 160))"
  fi
}

# --- 1. the guard exists and is runnable -------------------------------------------------
if [ -x "$GUARD" ]; then
  ok "the guard script exists and is executable"
else
  not_ok "the guard script exists and is executable"
fi

# --- 2. the documented stacking cases are refused -----------------------------------------
expect_deny "split --current" "herdr pane split --current"
expect_deny "split --pane <coordinator>" "herdr pane split --pane $COORD_PANE"
expect_deny "split \$PANE" 'herdr pane split $PANE'
expect_deny "split \${PANE}" 'herdr pane split ${PANE}'
expect_deny "split with no target" "herdr pane split"
expect_deny "split --current behind a global option" "herdr --session default pane split --current"

# --- 3. AGENTSEC GAP-01: raw dispatch into the coordinator pane ---------------------------
expect_deny "send-text into the coordinator pane" "herdr pane send-text $COORD_PANE hello"
expect_deny "send-keys into the coordinator pane" "herdr pane send-keys $COORD_PANE Enter"
expect_deny "input into the coordinator pane" "herdr pane input $COORD_PANE"
expect_deny "close the coordinator pane" "herdr pane close $COORD_PANE"

# --- 4. legitimate operations still work --------------------------------------------------
expect_allow "pane list" "herdr pane list"
expect_allow "agent list" "herdr agent list"
expect_allow "pane read of the coordinator pane" "herdr pane read $COORD_PANE"
expect_allow "pane get of the coordinator pane" "herdr pane get $COORD_PANE"
expect_allow "split of an explicitly named non-coordinator pane" "herdr pane split $OTHER_PANE"
expect_allow "a command that does not touch herdr" "ls -la /tmp"

# --- 5. non-vacuity: the guard must actually be able to refuse ---------------------------
if run_guard "herdr pane split --current" | grep -q '"deny"'; then
  ok "the guard emits a deny decision, not a no-op"
else
  not_ok "the guard emits a deny decision, not a no-op"
fi

# --- 6. the deny payload is well formed ---------------------------------------------------
out="$(run_guard "herdr pane split --current")"
if printf '%s' "$out" | python3 -c '
import json, sys
data = json.loads(sys.stdin.read())
hook = data.get("hookSpecificOutput") or {}
assert data.get("decision") == "deny", "decision"
assert hook.get("hookEventName") == "PreToolUse", "hookEventName"
assert hook.get("permissionDecision") == "deny", "permissionDecision"
assert isinstance(hook.get("permissionDecisionReason"), str) and hook["permissionDecisionReason"], "reason"
' 2>/dev/null; then
  ok "the deny payload is valid JSON with a PreToolUse deny decision and a reason"
else
  not_ok "the deny payload is valid JSON with a PreToolUse deny decision and a reason"
fi

# --- 7. the plugin is wired so the runtime calls it ----------------------------------------
if [ -f "$PLUGIN_HOOKS" ]; then
  if python3 -c '
import json, sys
data = json.load(open(sys.argv[1]))
entries = (data.get("hooks") or {}).get("PreToolUse") or []
assert entries, "no PreToolUse entries"
matcher = entries[0].get("matcher") or ""
assert matcher.startswith("Bash("), "matcher must target the Bash tool"
cmds = [h.get("command") for e in entries for h in (e.get("hooks") or [])]
assert "fm-pane-isolation-guard.sh" in cmds, "guard not wired"
' "$PLUGIN_HOOKS" 2>/dev/null; then
    ok "the MCode plugin wires a PreToolUse Bash matcher to the guard"
  else
    not_ok "the MCode plugin wires a PreToolUse Bash matcher to the guard"
  fi
else
  not_ok "the MCode plugin wires a PreToolUse Bash matcher to the guard (no hooks.json)"
fi

printf '1..%d\n' "$((ok_count + not_ok_count))"
printf '# %d ok, %d not ok\n' "$ok_count" "$not_ok_count"
[ "$not_ok_count" -eq 0 ]
