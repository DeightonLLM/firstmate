#!/usr/bin/env bash
# fm-pane-isolation-guard.sh - refuse pane operations that target the operator's coordinator pane.
#
# WHY THIS EXISTS (the Captain's rule, 2026-10-21, after an agent split panes inside his own
# visible Herdr session): an agent must never create or drive a pane ON the coordinator's pane.
# Splitting the coordinator pane stacks worker panes on the operator's screen.
#
# THE RULE IS DOCUMENTED, NOT INVENTED:
#   docs/audits-20260928/AGENTSEC.md 3.5 describes the Pi runtime extension
#   06-worker-pane-isolation.ts: it matches `herdr pane split <target>` and blocks when the
#   target is `--current`, `$PANE`, `${PANE}`, or the live coordinator pane id, and it "enforces
#   use of /root/bin/herdr-worker-pane".
#
# THE GAP THIS CLOSES:
#   1. That extension lived only in the Pi runtime and was not installed on this host, so an
#      MCode agent had nothing stopping it. This is the MCode side of the same rule.
#   2. AGENTSEC 5.1 (GAP-01, HIGH) records that the Pi hook only intercepted `herdr pane split`
#      and NOT `herdr pane send-text` / `send-keys`, so raw dispatch into the coordinator pane
#      was possible. This guard refuses those too.
#
# CONTRACT:
#   stdin  - the MCode PreToolUse payload (JSON): tool_name, tool_input.command, session_id
#   stdout - nothing to allow; a deny decision (JSON) to refuse
#   exit   - always 0 (a broken guard must never wedge the agent's turn)
#
# The canonical way to create a worker pane is bin/fm-spawn.sh (or /root/bin/herdr-worker-pane
# where it exists), never by splitting the coordinator's own pane.
set -uo pipefail

STATE_DIR="${FM_HOME:-$HOME/.local/state/firstmate}/state"
LOG_FILE="$STATE_DIR/fm-pane-isolation-guard.log"
HERDR_BIN="${HERDR_BIN_PATH:-$(command -v herdr 2>/dev/null || echo /usr/local/bin/herdr)}"

log() {
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"$LOG_FILE" 2>/dev/null || true
}

deny() {
  local reason="$1"
  log "DENY $reason"
  REASON="$reason" python3 - <<'PY'
import json, os
reason = os.environ.get("REASON", "refused by fm-pane-isolation-guard")
print(json.dumps({
    "decision": "deny",
    "reason": reason,
    "systemMessage": reason,
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    },
}))
PY
  exit 0
}

# Pane subcommands that CREATE or MOVE a pane. Splitting the coordinator pane is the stacking
# case the rule names.
SPLIT_SUBCOMMANDS="split"
# Pane subcommands that DRIVE an existing pane. Raw send-text/send-keys into the coordinator
# pane is AGENTSEC GAP-01.
DRIVE_SUBCOMMANDS="send-text send-keys input close rename zoom focus resize move swap"

payload="$(cat 2>/dev/null || true)"

# --- extract the command from the payload -----------------------------------------------
command_text="$(PAYLOAD="$payload" python3 - <<'PY' 2>/dev/null || true
import json, os
raw = os.environ.get("PAYLOAD", "")
if not raw.strip():
    print("")
    raise SystemExit(0)
try:
    data = json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)
if not isinstance(data, dict):
    print("")
    raise SystemExit(0)
ti = data.get("tool_input")
if isinstance(ti, dict):
    cmd = ti.get("command")
    if isinstance(cmd, list):
        cmd = " ".join(str(x) for x in cmd)
    if isinstance(cmd, str):
        print(cmd)
        raise SystemExit(0)
for key in ("command", "cmd"):
    val = data.get(key)
    if isinstance(val, str):
        print(val)
        raise SystemExit(0)
print("")
PY
)"

[ -n "$command_text" ] || exit 0
case "$command_text" in
  *herdr*) ;;
  *) exit 0 ;;
esac

# --- the live coordinator pane id -------------------------------------------------------
coordinator=""
if [ -x "$HERDR_BIN" ]; then
  coordinator="$(timeout 2 "$HERDR_BIN" pane current 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
pane = (data.get("result") or {}).get("pane") or {}
pid = pane.get("pane_id")
if isinstance(pid, str):
    print(pid)
' 2>/dev/null || true)"
fi
[ -n "$coordinator" ] || coordinator="${HERDR_PANE_ID:-}"

# --- decide ---------------------------------------------------------------------------
decision="$(CMD="$command_text" COORD="$coordinator" SPLIT_CMDS="$SPLIT_SUBCOMMANDS" DRIVE_CMDS="$DRIVE_SUBCOMMANDS" python3 - <<'PY' 2>/dev/null || true
import os, shlex

cmd = os.environ.get("CMD", "")
coord = os.environ.get("COORD", "")
split_cmds = set((os.environ.get("SPLIT_CMDS") or "").split())
drive_cmds = set((os.environ.get("DRIVE_CMDS") or "").split())

# Global herdr options that take a value.
GLOBAL_VALUE_OPTS = {"--session", "--machine", "--remote"}
# Pane options that take a value and are NOT pane targets.
PANE_VALUE_OPTS = {
    "--direction", "--ratio", "--cwd", "--env", "--message", "--source",
    "--agent", "--state", "--seq", "--agent-session-id", "--agent-session-path",
}
# Tokens that name the focused / current pane.
CURRENT_TOKENS = {"--current", "$PANE", "${PANE}", "$HERDR_PANE_ID", "${HERDR_PANE_ID}"}

try:
    tokens = shlex.split(cmd)
except Exception:
    tokens = cmd.split()

# Locate "herdr" and take the group command after it.
idx = None
for i, t in enumerate(tokens):
    if os.path.basename(t) == "herdr" or t == "herdr":
        idx = i
        break
if idx is None:
    raise SystemExit(0)

rest = tokens[idx + 1:]
i = 0
while i < len(rest):
    t = rest[i]
    if t in GLOBAL_VALUE_OPTS:
        i += 2
        continue
    if t.startswith("-"):
        i += 1
        continue
    break
if i >= len(rest):
    raise SystemExit(0)

group = rest[i]
rest = rest[i + 1:]

# `herdr pane <subcommand> ...` - the group is "pane" and the next token is the subcommand.
if group == "pane":
    j = 0
    while j < len(rest):
        t = rest[j]
        if t.startswith("-"):
            j += 1
            continue
        break
    if j >= len(rest):
        raise SystemExit(0)
    sub = rest[j]
    rest = rest[j + 1:]
else:
    raise SystemExit(0)

# Collect the pane TARGETS: positionals and the values of --pane / --pane-id.
targets = []
k = 0
while k < len(rest):
    t = rest[k]
    if t in ("--pane", "--pane-id"):
        if k + 1 < len(rest):
            targets.append(rest[k + 1])
            k += 2
            continue
        k += 1
        continue
    if t.startswith("--pane="):
        targets.append(t.split("=", 1)[1])
        k += 1
        continue
    if t in CURRENT_TOKENS:
        targets.append(t)
        k += 1
        continue
    if t in PANE_VALUE_OPTS:
        k += 2
        continue
    if t.startswith("-"):
        k += 1
        continue
    targets.append(t)
    k += 1


def coord_like(tok):
    if tok in CURRENT_TOKENS:
        return True
    if coord and tok == coord:
        return True
    return False


if sub in split_cmds:
    for tok in targets:
        if coord_like(tok):
            print("SPLIT_COORDINATOR")
            raise SystemExit(0)
    # `herdr pane split` with NO target at all splits the focused pane, which is the
    # coordinator pane in an operator session. Refuse it: name a pane explicitly.
    if not targets:
        print("SPLIT_NO_TARGET")
        raise SystemExit(0)

if sub in drive_cmds:
    for tok in targets:
        if coord and tok == coord:
            print("DRIVE_COORDINATOR:%s" % sub)
            raise SystemExit(0)

print("")
PY
)"

case "$decision" in
  SPLIT_COORDINATOR)
    deny "Refused: that would create a worker pane on the operator's coordinator pane (${coordinator:-the live coordinator pane}). Spawn a worker pane with bin/fm-spawn.sh (or /root/bin/herdr-worker-pane), never by splitting the coordinator's own pane."
    ;;
  SPLIT_NO_TARGET)
    deny "Refused: 'herdr pane split' with no explicit target splits the focused pane, which is the operator's coordinator pane. Name the worker pane explicitly and spawn it through bin/fm-spawn.sh."
    ;;
  DRIVE_COORDINATOR:*)
    deny "Refused: 'herdr pane ${decision#DRIVE_COORDINATOR:}' would drive the operator's coordinator pane directly. Raw pane dispatch into the coordinator pane is AGENTSEC GAP-01; use the sanctioned send path instead."
    ;;
esac

exit 0
