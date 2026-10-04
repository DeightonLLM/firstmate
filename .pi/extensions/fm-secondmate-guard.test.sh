#!/usr/bin/env bash
# fm-secondmate-guard.test.sh - colocated behavior test for the Pi secondmate
# controller guard (.pi/extensions/fm-secondmate-guard.ts).
#
# Contract under test:
#   In a home whose root carries the .fm-secondmate-home marker, the guard
#   DENIES  (a) bash invocations of bin/fm-session-start.sh and
#           bin/fm-watch-arm.sh, and
#           (b) any tool call named fm_watch_arm_pi.
#   It ALLOWS every other tool call, and it ALLOWS all of the above in a home
#   WITHOUT the marker (a primary home is never denied by this guard).
#
# The guard is driven through the real Pi extension surface: a fake ExtensionAPI
# captures the tool_call listener, the same { block: true, reason } shape the
# primary turn-end guard already uses to stop execution before the tool runs.
# Nothing here executes a guarded command.
#
# Run: bash .pi/extensions/fm-secondmate-guard.test.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXT="$ROOT/.pi/extensions/fm-secondmate-guard.ts"

if [ ! -f "$EXT" ]; then
  printf 'not ok - guard under test is missing: %s\n' "$EXT" >&2
  exit 1
fi

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-secondmate-guard.XXXXXX")
trap 'rm -rf "$TMP_ROOT" 2>/dev/null || true' EXIT

# --- fixtures ---------------------------------------------------------------
#
# The extension is loaded from a fixture checkout, not the real one, so each
# scenario controls BOTH roots: the code root the extension file lives in and
# the session home (FM_HOME) it supervises. Real secondmate deployments vary
# here, and the guard must key on the home root, not the code root.

FIXTURE_REPO="$TMP_ROOT/fixture-repo"
mkdir -p "$FIXTURE_REPO/.pi/extensions"
cp "$EXT" "$FIXTURE_REPO/.pi/extensions/fm-secondmate-guard.ts"
PLUGIN="$FIXTURE_REPO/.pi/extensions/fm-secondmate-guard.ts"

# Scenario A/B share a marker-free code root and differ only by the home.
SECONDMATE_HOME="$TMP_ROOT/home-secondmate"
mkdir -p "$SECONDMATE_HOME/state"
printf 'sm-guard-fixture\n' > "$SECONDMATE_HOME/.fm-secondmate-home"

PRIMARY_HOME="$TMP_ROOT/home-primary"
mkdir -p "$PRIMARY_HOME/state"

# Scenario C: the secondmate home IS its own checkout, which is how
# bin/fm-home-seed.sh materializes it - no FM_HOME or FM_ROOT_OVERRIDE at all.
SELF_HOSTED_HOME="$TMP_ROOT/home-self-hosted"
mkdir -p "$SELF_HOSTED_HOME/.pi/extensions" "$SELF_HOSTED_HOME/state" "$SELF_HOSTED_HOME/bin"
cp "$EXT" "$SELF_HOSTED_HOME/.pi/extensions/fm-secondmate-guard.ts"
printf 'sm-guard-fixture\n' > "$SELF_HOSTED_HOME/.fm-secondmate-home"

# --- driver -----------------------------------------------------------------

cat > "$TMP_ROOT/driver.mjs" <<'DRIVER'
// Drives the guard through a fake Pi ExtensionAPI and prints one
// "<name>\t<ALLOW|BLOCK>\t<reason>" line per case.
import { pathToFileURL } from "node:url";

const mod = await import(pathToFileURL(process.env.PLUGIN).href);
let handler = null;
const pi = {
  on(event, callback) {
    if (event === "tool_call") handler = callback;
  },
  registerCommand() {},
  registerTool() {},
  sendUserMessage: async () => {},
};
mod.default(pi);
if (!handler) {
  console.error("fm-secondmate-guard registered no tool_call listener");
  process.exit(1);
}

const CONTROLLER_SCRIPTS = ["fm-session-start.sh", "fm-watch-arm.sh"];

const cases = [
  // --- must be denied in a secondmate home ---------------------------------
  ["bash_watch_arm", { type: "tool_call", toolName: "bash", input: { command: "bin/fm-watch-arm.sh --restart" } }],
  ["bash_watch_arm_second_segment", { type: "tool_call", toolName: "bash", input: { command: "cd bin && ./fm-watch-arm.sh --restart" } }],
  ["bash_watch_arm_newline_segment", { type: "tool_call", toolName: "bash", input: { command: "cd bin\n./fm-watch-arm.sh" } }],
  ["bash_session_start", { type: "tool_call", toolName: "bash", input: { command: "bin/fm-session-start.sh" } }],
  ["bash_session_start_absolute", { type: "tool_call", toolName: "bash", input: { command: "/opt/firstmate/bin/fm-session-start.sh" } }],
  ["bash_session_start_interpreter", { type: "tool_call", toolName: "bash", input: { command: "bash ./bin/fm-session-start.sh" } }],
  ["bash_session_start_env", { type: "tool_call", toolName: "bash", input: { command: "env FM_X=1 /opt/firstmate/bin/fm-session-start.sh" } }],
  ["bash_watch_arm_line_continuation", { type: "tool_call", toolName: "bash", input: { command: "bin/fm-watc\\\nh-arm.sh --restart" } }],
  ["bash_watch_arm_quoted", { type: "tool_call", toolName: "bash", input: { command: "'bin/fm-watch-arm.sh' --restart" } }],
  ["bash_watch_arm_assignment_indirection", { type: "tool_call", toolName: "bash", input: { command: "FM_ARM=bin/fm-watch-arm.sh; \"$FM_ARM\" --restart" } }],
  ["bash_watch_arm_piped", { type: "tool_call", toolName: "bash", input: { command: "printf ok | bin/fm-watch-arm.sh" } }],
  ["tool_fm_watch_arm_pi", { type: "tool_call", toolName: "fm_watch_arm_pi", input: {} }],

  // --- must be allowed even in a secondmate home ---------------------------
  ["bash_unrelated_script", { type: "tool_call", toolName: "bash", input: { command: "bin/fm-crew-state.sh task-1" } }],
  ["bash_teardown", { type: "tool_call", toolName: "bash", input: { command: "bin/fm-teardown.sh task-1" } }],
  ["bash_git_status", { type: "tool_call", toolName: "bash", input: { command: "git status --porcelain" } }],
  ["bash_read_script_body", { type: "tool_call", toolName: "bash", input: { command: "cat bin/fm-watch-arm.sh" } }],
  ["bash_grep_reference", { type: "tool_call", toolName: "bash", input: { command: "grep -rn fm-watch-arm.sh bin/" } }],
  ["bash_read_session_start_body", { type: "tool_call", toolName: "bash", input: { command: "sed -n 1,40p bin/fm-session-start.sh" } }],
  ["bash_similar_script_name", { type: "tool_call", toolName: "bash", input: { command: "bin/fm-watch-arm-helper.sh --check" } }],
  ["bash_suffixed_script_name", { type: "tool_call", toolName: "bash", input: { command: "bin/my-fm-watch-arm.sh" } }],
  ["bash_empty_command", { type: "tool_call", toolName: "bash", input: { command: "" } }],
  ["bash_missing_command", { type: "tool_call", toolName: "bash", input: {} }],
  ["tool_read", { type: "tool_call", toolName: "read", input: { path: "bin/fm-watch-arm.sh" } }],
  ["tool_other_controller_tool", { type: "tool_call", toolName: "fm_watch_arm", input: {} }],
  ["non_tool_call_event", { type: "tool_result", toolName: "fm_watch_arm_pi", input: {} }],
];

for (const [name, event] of cases) {
  const result = await handler(event);
  const blocked = result?.block === true;
  const reason = blocked ? String(result?.reason ?? "") : "";
  if (blocked && !reason.trim()) {
    console.error(`${name}\tBLOCK\t`);
    console.error(`guard blocked ${name} without a reason`);
    process.exit(1);
  }
  console.log(`${name}\t${blocked ? "BLOCK" : "ALLOW"}\t${reason.replace(/\s+/g, " ")}`);
}

const guardOwnsBothSeats = CONTROLLER_SCRIPTS.every((script) => cases.some(([name, event]) => name.startsWith("bash_") && String(event?.input?.command ?? "").includes(script)));
if (!guardOwnsBothSeats) {
  console.error("case matrix no longer exercises both controller scripts");
  process.exit(1);
}
DRIVER

# --- helpers ----------------------------------------------------------------

passed=0
failed=0

decision_of() {
  printf '%s\n' "$1" | awk -F'\t' -v name="$2" '$1 == name { print $2; exit }'
}

reason_of() {
  printf '%s\n' "$1" | awk -F'\t' -v name="$2" '$1 == name { $1 = ""; sub(/^\t/, ""); print; exit }'
}

check() {
  # check <out> <name> <expected> <label> <note>
  local out=$1 name=$2 expected=$3 label=$4 note=$5 actual
  actual=$(decision_of "$out" "$name")
  if [ -z "$actual" ]; then
    printf 'not ok - %s: %s produced no decision\n' "$label" "$name" >&2
    failed=$((failed + 1))
    return
  fi
  if [ "$actual" != "$expected" ]; then
    printf 'not ok - %s: %s expected %s, got %s (reason: %s)\n' \
      "$label" "$name" "$expected" "$actual" "$(reason_of "$out" "$name")" >&2
    failed=$((failed + 1))
    return
  fi
  printf 'ok - %s: %s is %s (%s)\n' "$label" "$name" "$expected" "$note"
  passed=$((passed + 1))
}

check_blocked_reason() {
  # check_blocked_reason <out> <name> <label> <needle>
  local out=$1 name=$2 label=$3 needle=$4 reason
  reason=$(reason_of "$out" "$name")
  case "$reason" in
  *"$needle"*)
    printf 'ok - %s: %s denial explains itself ("%s")\n' "$label" "$name" "$needle"
    passed=$((passed + 1))
    ;;
  *)
    printf 'not ok - %s: %s denial omitted "%s": %s\n' "$label" "$name" "$needle" "$reason" >&2
    failed=$((failed + 1))
    ;;
  esac
}

# Denied in a secondmate home, allowed everywhere else, for every case.
DENY_CASES="bash_watch_arm bash_watch_arm_second_segment bash_watch_arm_newline_segment
bash_session_start bash_session_start_absolute bash_session_start_interpreter
bash_session_start_env bash_watch_arm_line_continuation bash_watch_arm_quoted
bash_watch_arm_assignment_indirection bash_watch_arm_piped tool_fm_watch_arm_pi"

ALLOW_CASES="bash_unrelated_script bash_teardown bash_git_status bash_read_script_body
bash_grep_reference bash_read_session_start_body bash_similar_script_name
bash_suffixed_script_name bash_empty_command bash_missing_command tool_read
tool_other_controller_tool non_tool_call_event"

# --- scenario A: secondmate home, separate marker-free code root ------------

out=$(PLUGIN="$PLUGIN" FM_HOME="$SECONDMATE_HOME" FM_ROOT_OVERRIDE="$FIXTURE_REPO" \
  node "$TMP_ROOT/driver.mjs" 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
  printf 'not ok - secondmate home driver failed (exit %s)\n%s\n' "$status" "$out" >&2
  failed=$((failed + 1))
fi
for name in $DENY_CASES; do
  check "$out" "$name" BLOCK "secondmate home" "deny"
done
for name in $ALLOW_CASES; do
  check "$out" "$name" ALLOW "secondmate home" "allow"
done
check_blocked_reason "$out" bash_watch_arm "secondmate home" "secondmate"
check_blocked_reason "$out" tool_fm_watch_arm_pi "secondmate home" "secondmate"

# --- scenario B: primary home, same code root, no marker --------------------

out=$(PLUGIN="$PLUGIN" FM_HOME="$PRIMARY_HOME" FM_ROOT_OVERRIDE="$FIXTURE_REPO" \
  node "$TMP_ROOT/driver.mjs" 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
  printf 'not ok - primary home driver failed (exit %s)\n%s\n' "$status" "$out" >&2
  failed=$((failed + 1))
fi
for name in $DENY_CASES $ALLOW_CASES; do
  check "$out" "$name" ALLOW "primary home" "never deny without the marker"
done

# --- scenario C: the secondmate home is its own checkout --------------------

# No FM_HOME and no FM_ROOT_OVERRIDE: the extension must fall back to the
# checkout it lives in, which is how bin/fm-home-seed.sh materializes a home.
out=$(PLUGIN="$SELF_HOSTED_HOME/.pi/extensions/fm-secondmate-guard.ts" \
  env -u FM_HOME -u FM_ROOT_OVERRIDE node "$TMP_ROOT/driver.mjs" 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
  printf 'not ok - self-hosted secondmate driver failed (exit %s)\n%s\n' "$status" "$out" >&2
  failed=$((failed + 1))
fi
for name in $DENY_CASES; do
  check "$out" "$name" BLOCK "self-hosted secondmate home" "deny"
done
for name in $ALLOW_CASES; do
  check "$out" "$name" ALLOW "self-hosted secondmate home" "allow"
done

# --- summary ----------------------------------------------------------------

total=$((passed + failed))
if [ "$failed" -ne 0 ]; then
  printf 'not ok - fm-secondmate-guard: %d/%d assertions failed\n' "$failed" "$total" >&2
  exit 1
fi
printf 'ok - fm-secondmate-guard: %d/%d assertions passed (secondmate homes deny the controller seats; a primary home is never denied)\n' \
  "$passed" "$total"
