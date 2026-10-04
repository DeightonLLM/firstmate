#!/usr/bin/env bash
# fm-secondmate-guard.test.sh - colocated behavior test for the Pi secondmate
# controller guard (.pi/extensions/fm-secondmate-guard.ts).
#
# Contract under test:
#   In a GENUINE secondmate home, the guard DENIES exactly one call: the
#   controller-exclusive tool fm_watch_arm_pi. Everything else is allowed.
#   The per-home bin/fm-session-start.sh and bin/fm-watch-arm.sh are
#   LEGITIMATE in a secondmate home - its charter (bin/fm-brief.sh) tells it to
#   run normal bootstrap and recovery through bin/fm-session-start.sh for its
#   OWN home, and bin/fm-watch-arm.sh --restart resolves exactly this home's
#   watcher pid, so it can never touch a sibling. Only the controller's own Pi
#   watcher tool belongs to the primary seat; a secondmate routes that to the
#   primary firstmate.
#   A home WITHOUT a genuine marker is never denied anything.
#
# Marker fidelity: the guard must mirror the shell predicate
# fm_root_is_secondmate_home in bin/fm-primary-scope-lib.sh exactly, so a
# primary home is never misread as a secondmate (or vice versa) and the two
# layers cannot drift. The shell semantics pinned below were measured from
# that function: it rejects a symlinked marker, a non-regular file, an empty
# or whitespace-only id, an id outside [A-Za-z0-9._-], and a marker with no
# trailing newline (bash `read` returns non-zero at EOF without a delimiter);
# it reads only the FIRST line and strips ALL whitespace anywhere in that line
# before the charset test, so an internal space or tab is accepted. Seeding
# always writes the id with a trailing newline (bin/fm-home-seed.sh).
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

# Scenario D: one home per marker variant, so the guard's marker predicate is
# compared against the shell's measured verdict for the SAME filesystem state.
MARKER_VARIANTS="$TMP_ROOT/marker-variants"
mkdir -p "$MARKER_VARIANTS"

new_home() { # <name>
  local home="$MARKER_VARIANTS/$1"
  mkdir -p "$home/state"
  printf '%s' "$home"
}

VALID_ID_HOME=$(new_home valid-id)
printf 'sm.valid-id_1\n' > "$VALID_ID_HOME/.fm-secondmate-home"

NO_NEWLINE_HOME=$(new_home no-trailing-newline)
printf 'sm.valid-id_1' > "$NO_NEWLINE_HOME/.fm-secondmate-home"

EMPTY_HOME=$(new_home empty-file)
: > "$EMPTY_HOME/.fm-secondmate-home"

NEWLINE_ONLY_HOME=$(new_home newline-only)
printf '\n' > "$NEWLINE_ONLY_HOME/.fm-secondmate-home"

WHITESPACE_HOME=$(new_home whitespace-only)
printf '   \n' > "$WHITESPACE_HOME/.fm-secondmate-home"

INTERNAL_SPACE_HOME=$(new_home internal-space)
printf 'sm guard\n' > "$INTERNAL_SPACE_HOME/.fm-secondmate-home"

INTERNAL_TAB_HOME=$(new_home internal-tab)
printf 'sm\tguard\n' > "$INTERNAL_TAB_HOME/.fm-secondmate-home"

SLASH_HOME=$(new_home slash-in-id)
printf 'sm/guard\n' > "$SLASH_HOME/.fm-secondmate-home"

SURROUNDING_WS_HOME=$(new_home surrounding-whitespace)
printf '  sm-ws-1  \n' > "$SURROUNDING_WS_HOME/.fm-secondmate-home"

SECOND_LINE_HOME=$(new_home second-line-garbage)
printf 'sm-guard-fixture\nsecond line is ignored\n' > "$SECOND_LINE_HOME/.fm-secondmate-home"

DIR_MARKER_HOME=$(new_home directory-marker)
mkdir -p "$DIR_MARKER_HOME/.fm-secondmate-home"

SYMLINK_HOME=$(new_home symlink-marker)
printf 'sm-guard-fixture\n' > "$MARKER_VARIANTS/symlink-target"
ln -s "$MARKER_VARIANTS/symlink-target" "$SYMLINK_HOME/.fm-secondmate-home"

DANGLING_SYMLINK_HOME=$(new_home dangling-symlink)
ln -s "$MARKER_VARIANTS/does-not-exist" "$DANGLING_SYMLINK_HOME/.fm-secondmate-home"

NO_MARKER_HOME=$(new_home no-marker)

# --- driver -----------------------------------------------------------------

cat > "$TMP_ROOT/driver.mjs" <<'DRIVER'
// Drives the guard through a fake Pi ExtensionAPI and prints one
// "<name>\t<ALLOW|BLOCK>\t<reason>" line per case.
// CASE_FILTER (comma-separated names) runs a subset, for the marker-fidelity
// scenarios that only care about the one controller call.
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

// The single controller seat. Both per-home scripts stay in the matrix as
// ALLOWED forms, so a widened deny list cannot pass unnoticed.
const CONTROLLER_TOOL = "fm_watch_arm_pi";
const OWN_HOME_SCRIPTS = ["fm-session-start.sh", "fm-watch-arm.sh"];

const cases = [
  // --- the one call a genuine secondmate may never make --------------------
  ["tool_fm_watch_arm_pi", { type: "tool_call", toolName: "fm_watch_arm_pi", input: {} }],

  // --- a secondmate's OWN per-home startup and supervision are legitimate ---
  ["bash_own_home_session_start", { type: "tool_call", toolName: "bash", input: { command: "bin/fm-session-start.sh" } }],
  ["bash_own_home_session_start_explicit_home", { type: "tool_call", toolName: "bash", input: { command: "FM_HOME=/home/sm/homes/alpha bin/fm-session-start.sh" } }],
  ["bash_own_home_session_start_absolute", { type: "tool_call", toolName: "bash", input: { command: "/opt/firstmate/bin/fm-session-start.sh" } }],
  ["bash_own_home_session_start_wrapped", { type: "tool_call", toolName: "bash", input: { command: "bash ./bin/fm-session-start.sh" } }],
  ["bash_own_home_session_start_env", { type: "tool_call", toolName: "bash", input: { command: "env FM_X=1 /opt/firstmate/bin/fm-session-start.sh" } }],
  ["bash_own_home_session_start_second_segment", { type: "tool_call", toolName: "bash", input: { command: "cd bin && ../bin/fm-session-start.sh" } }],
  ["bash_own_home_watch_arm_restart", { type: "tool_call", toolName: "bash", input: { command: "bin/fm-watch-arm.sh --restart" } }],
  ["bash_own_home_watch_arm_wrapped", { type: "tool_call", toolName: "bash", input: { command: "bash bin/fm-watch-arm.sh --restart" } }],
  ["bash_own_home_watch_arm_quoted", { type: "tool_call", toolName: "bash", input: { command: "'bin/fm-watch-arm.sh' --restart" } }],
  ["bash_own_home_watch_arm_line_continuation", { type: "tool_call", toolName: "bash", input: { command: "bin/fm-watc\\\nh-arm.sh --restart" } }],
  ["bash_own_home_watch_arm_assignment_indirection", { type: "tool_call", toolName: "bash", input: { command: "FM_ARM=bin/fm-watch-arm.sh; \"$FM_ARM\" --restart" } }],
  ["bash_own_home_watch_arm_piped", { type: "tool_call", toolName: "bash", input: { command: "printf ok | bin/fm-watch-arm.sh" } }],

  // --- ordinary work stays allowed ------------------------------------------
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
  ["tool_similar_controller_tool", { type: "tool_call", toolName: "fm_watch_arm_pi_probe", input: {} }],
  ["non_tool_call_event", { type: "tool_result", toolName: "fm_watch_arm_pi", input: {} }],
];

const filter = process.env.CASE_FILTER
  ? new Set(process.env.CASE_FILTER.split(",").map((name) => name.trim()))
  : null;
const selected = filter ? cases.filter(([name]) => filter.has(name)) : cases;

for (const [name, event] of selected) {
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

// Self-checks: the FULL matrix must keep pinning the one controller seat and
// both per-home scripts, so a narrowed or widened guard cannot quietly stop
// testing the thing it exists to test. A filtered run covers a marker shape
// only, so it skips these.
if (!filter) {
  if (!cases.some(([, event]) => String(event?.toolName ?? "") === CONTROLLER_TOOL)) {
    console.error("case matrix no longer exercises the controller tool");
    process.exit(1);
  }
  for (const script of OWN_HOME_SCRIPTS) {
    const covered = cases.some(
      ([name, event]) => name.startsWith("bash_own_home_") && String(event?.input?.command ?? "").includes(script),
    );
    if (!covered) {
      console.error(`case matrix no longer exercises the per-home script ${script}`);
      process.exit(1);
    }
  }
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

check_exact_block_set() {
  # check_exact_block_set <out> <expected-csv> <label> <note>
  # The deny surface of a secondmate home is exactly one call: nothing else may
  # be blocked, and the controller call may never go missing.
  local out=$1 expected=$2 label=$3 note=$4 actual want
  actual=$(printf '%s\n' "$out" | awk -F'\t' '$2 == "BLOCK" { print $1 }' | sort | tr '\n' ',' | sed 's/,$//')
  want=$(printf '%s\n' "$expected" | tr ',' '\n' | sort | tr '\n' ',' | sed 's/,$//')
  if [ "$actual" != "$want" ]; then
    printf 'not ok - %s: blocked set expected [%s], got [%s]\n' "$label" "$want" "${actual:-none}" >&2
    failed=$((failed + 1))
    return
  fi
  printf 'ok - %s: blocked set is exactly [%s] (%s)\n' "$label" "$want" "$note"
  passed=$((passed + 1))
}

# The one denied call in a genuine secondmate home.
DENY_CASES="tool_fm_watch_arm_pi"

# A secondmate's own per-home startup and supervision, plus ordinary work.
ALLOW_CASES="bash_own_home_session_start bash_own_home_session_start_explicit_home
bash_own_home_session_start_absolute bash_own_home_session_start_wrapped
bash_own_home_session_start_env bash_own_home_session_start_second_segment
bash_own_home_watch_arm_restart bash_own_home_watch_arm_wrapped
bash_own_home_watch_arm_quoted bash_own_home_watch_arm_line_continuation
bash_own_home_watch_arm_assignment_indirection bash_own_home_watch_arm_piped
bash_unrelated_script bash_teardown bash_git_status bash_read_script_body
bash_grep_reference bash_read_session_start_body bash_similar_script_name
bash_suffixed_script_name bash_empty_command bash_missing_command tool_read
tool_other_controller_tool tool_similar_controller_tool non_tool_call_event"

# --- scenario A: genuine secondmate home, separate marker-free code root -----

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
check_blocked_reason "$out" tool_fm_watch_arm_pi "secondmate home" "secondmate"
check_blocked_reason "$out" tool_fm_watch_arm_pi "secondmate home" "fm_watch_arm_pi"
check_exact_block_set "$out" "tool_fm_watch_arm_pi" "secondmate home" \
  "a secondmate runs its own session-start and watch-arm"

# --- scenario B: primary home, same code root, no marker --------------------

out=$(PLUGIN="$PLUGIN" FM_HOME="$PRIMARY_HOME" FM_ROOT_OVERRIDE="$FIXTURE_REPO" \
  node "$TMP_ROOT/driver.mjs" 2>&1)
status=$?
if [ "$status" -ne 0 ]; then
  printf 'not ok - primary home driver failed (exit %s)\n%s\n' "$status" "$out" >&2
  failed=$((failed + 1))
fi
for name in $DENY_CASES $ALLOW_CASES; do
  check "$out" "$name" ALLOW "primary home" "never deny without a genuine marker"
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

# --- scenario D: marker fidelity against the shell predicate ----------------
#
# Each variant home carries exactly one marker shape, and the expected verdict
# is what fm_root_is_secondmate_home (bin/fm-primary-scope-lib.sh) returns for
# that same shape. The guard and the shell must agree in every case, so neither
# layer can drift into denying a primary home or exempting a secondmate one.

probe_marker() {
  # probe_marker <home> <expected> <label>
  local home=$1 expected=$2 label=$3 out status
  out=$(PLUGIN="$PLUGIN" FM_HOME="$home" FM_ROOT_OVERRIDE="$FIXTURE_REPO" \
    CASE_FILTER="tool_fm_watch_arm_pi" node "$TMP_ROOT/driver.mjs" 2>&1)
  status=$?
  if [ "$status" -ne 0 ]; then
    printf 'not ok - %s: driver failed (exit %s)\n%s\n' "$label" "$status" "$out" >&2
    failed=$((failed + 1))
    return
  fi
  check "$out" tool_fm_watch_arm_pi "$expected" "marker $label" "matches the shell predicate"
}

# genuine markers: the controller call is denied
probe_marker "$VALID_ID_HOME" BLOCK "valid id, trailing newline"
probe_marker "$SURROUNDING_WS_HOME" BLOCK "surrounding whitespace stripped"
probe_marker "$INTERNAL_SPACE_HOME" BLOCK "internal space stripped like the shell"
probe_marker "$INTERNAL_TAB_HOME" BLOCK "internal tab stripped like the shell"
probe_marker "$SECOND_LINE_HOME" BLOCK "only the first line is read"

# not genuine: every one of these reads as a primary home, so nothing is denied
probe_marker "$NO_NEWLINE_HOME" ALLOW "no trailing newline (read hits EOF)"
probe_marker "$EMPTY_HOME" ALLOW "empty marker"
probe_marker "$NEWLINE_ONLY_HOME" ALLOW "newline-only marker"
probe_marker "$WHITESPACE_HOME" ALLOW "whitespace-only marker"
probe_marker "$SLASH_HOME" ALLOW "id outside [A-Za-z0-9._-]"
probe_marker "$DIR_MARKER_HOME" ALLOW "marker is a directory, not a file"
probe_marker "$SYMLINK_HOME" ALLOW "symlinked marker"
probe_marker "$DANGLING_SYMLINK_HOME" ALLOW "dangling symlinked marker"
probe_marker "$NO_MARKER_HOME" ALLOW "no marker at all"

# --- summary ----------------------------------------------------------------

total=$((passed + failed))
if [ "$failed" -ne 0 ]; then
  printf 'not ok - fm-secondmate-guard: %d/%d assertions failed\n' "$failed" "$total" >&2
  exit 1
fi
printf 'ok - fm-secondmate-guard: %d/%d assertions passed (a genuine secondmate home denies only the controller tool and keeps its own session-start and watch-arm; the marker predicate mirrors fm_root_is_secondmate_home)\n' \
  "$passed" "$total"
