#!/usr/bin/env bash
# tests/fm-mcode-herdr-agent-plugin.test.sh - the MCode herdr agent plugin must
# actually load, and the per-task runtime dir must carry a PHYSICAL plugins
# directory.
#
# The chain this guards, end to end:
#
#   1. bin/fm-spawn.sh builds a per-task mcode runtime dir. The `plugins` entry
#      must be a real directory, not a symlink: mcode refuses a symlinked
#      plugin root with "PLUGIN_ROOT_SYMLINK: Plugin root must be a physical
#      directory", and that refusal takes the whole local marketplace down, so
#      the lane loses every local plugin - including mcode-herdr-agent, the
#      plugin that lets a pane publish its own agent state to herdr.
#   2. The mcode-herdr-agent package itself must be a valid MINIMAX manifest.
#      The package used to carry a root plugin.json (the portable Agent Plugins
#      manifest). mcode reads THAT manifest first when it is present and it
#      resolves to a plugin with no hooks, so the native manifest that declares
#      the hooks was never used and the pane never reported anything.
#   3. The reporter must survive the filtered environment mcode gives a hook.
#      mcode passes a fixed allowlist to hook processes, and HERDR_ENV /
#      HERDR_PANE_ID / HERDR_BIN_PATH are not on it, so the reporter has to
#      recover the pane identity from the mcode process that spawned it.
#   4. The semantic busy read must stay fail-closed: no agent state means
#      unknown, never idle, and a live holder is never mistaken for an idle one.
#
# Hermetic: every filesystem write lands under a scratch tmp root. The herdr
# CLI is stubbed. The live mcode CLI is only consulted when it is installed,
# and the test skips that case otherwise.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
BACKEND="$ROOT/bin/backends/herdr.sh"
REPORTER="$ROOT/bin/fm-herdr-agent-report.sh"
PKG="$ROOT/extensions/mcode-herdr-agent"

TMP_ROOT=$(fm_test_tmproot fm-mcode-herdr-agent)
trap 'rm -rf "$TMP_ROOT"' EXIT

# =============================================================================
# helpers
# =============================================================================

# Extract a top-level shell function from fm-spawn.sh by name.
extract_fn() {
  awk -v fn="$1" '
    $0 ~ "^" fn "\\(\\) \\{" { inside = 1 }
    inside { print }
    inside && $0 ~ /^}$/ { exit }
  ' "$SPAWN"
}

# make_fake_herdr: a stub `herdr` that logs every invocation (one line,
# unit-separated args, to $FM_HERDR_LOG) and returns the canned response for
# that call read from $FM_HERDR_RESPONSES/<n>.out, consumed IN ORDER (call 1
# reads 1.out, call 2 reads 2.out, ...). A missing response file means
# "succeed with empty stdout". `status --json` answers "server running" so the
# adapter's server-liveness probe passes. Same stub contract as the one in
# tests/fm-backend-herdr.test.sh.
make_fake_herdr() {  # <dir>
  local dir=$1 fb="$1/fakebin"
  mkdir -p "$fb" "$dir/responses"
  : > "$dir/log"
  # The log and response paths are baked into the stub rather than read from
  # the environment: the whole point of the reporter test is that the hook
  # process runs with a FILTERED environment, so the stub cannot depend on
  # variables the reporter would have to pass through. The stub body is
  # written with placeholders and then substituted, so the shell that builds it
  # does not expand the stub's own variables.
  cat > "$fb/herdr.in" <<'SH'
#!/usr/bin/env bash
set -u
LOG="__LOG__"
RESP="__RESP__"
COUNT="$RESP/.count"
next=$(( $(cat "$COUNT" 2>/dev/null || echo 0) + 1 ))
{
  printf 'HERDR_SESSION=%s' "${HERDR_SESSION:-}"
  for a in "$@"; do printf '\x1f%s' "$a"; done
  printf '\n'
} >> "$LOG"
if [ "${1:-}" = status ] && [ "${2:-}" = --json ]; then
  printf '{"client":{"version":"0.9.5","protocol":14},"server":{"running":true}}\n'
  exit 0
fi
n=$next
echo "$n" > "$COUNT"
if [ -f "$RESP/$n.exit" ]; then
  exit "$(cat "$RESP/$n.exit")"
fi
[ -f "$RESP/$n.out" ] && cat "$RESP/$n.out"
exit 0
SH
  sed -e "s|__LOG__|$dir/log|" -e "s|__RESP__|$dir/responses|" "$fb/herdr.in" > "$fb/herdr"
  rm -f "$fb/herdr.in"
  chmod 0755 "$fb/herdr"
  printf '%s\n' "$fb"
}

# make_runtime_data_dir: a scratch MINIMAX_DATA_DIR shaped like the real one,
# with the pieces the per-task mirror has to treat differently.
make_runtime_data_dir() {  # <dir>
  local dir=$1
  mkdir -p "$dir/v2" "$dir/sessions" "$dir/plugins"
  printf 'provider: test\n' > "$dir/config.yaml"
  printf 'v2-marker\n' > "$dir/v2/marker"
  printf 'session-marker\n' > "$dir/sessions/marker"
  cp -R "$PKG" "$dir/plugins/mcode-herdr-agent"
  printf '%s\n' "$dir"
}

# =============================================================================
# 1. the per-task runtime dir must carry a PHYSICAL plugins directory
# =============================================================================

test_task_dir_has_physical_plugins_dir() {
  local base task out
  base=$(make_runtime_data_dir "$TMP_ROOT/data1")
  task="$TMP_ROOT/task1"

  # The exact production code path: the same function fm-spawn.sh calls.
  FUNCS="$TMP_ROOT/fns1.sh"
  : > "$FUNCS"
  for fn in copy_mcode_plugins_dir setup_mcode_task_dir; do
    body=$(extract_fn "$fn")
    [ -n "$body" ] || fail "could not extract $fn from fm-spawn.sh"
    printf '%s\n' "$body" >> "$FUNCS"
  done
  # shellcheck source=/dev/null
  . "$FUNCS"

  setup_mcode_task_dir "$task" "$base"

  [ -d "$task/plugins" ] || fail "the per-task dir must contain a plugins directory"
  [ ! -L "$task/plugins" ] || fail "the per-task plugins entry must be a physical directory, not a symlink"
  [ -d "$task/plugins/mcode-herdr-agent" ] || fail "the plugin package must be copied into the per-task plugins directory"
  [ ! -L "$task/plugins/mcode-herdr-agent" ] || fail "the copied plugin package must be a physical directory, not a symlink"
  [ -f "$task/plugins/mcode-herdr-agent/.minimax-plugin/plugin.json" ] \
    || fail "the copied plugin package must carry its MINIMAX manifest"
  [ -f "$task/plugins/mcode-herdr-agent/hooks/hooks.json" ] \
    || fail "the copied plugin package must carry its hooks declaration"

  # The package that was copied must still be a package mcode can load: the
  # native manifest must declare the hooks, and the portable root manifest must
  # not be present, because mcode reads that one first and resolves it to a
  # plugin with no hooks.
  out=$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("schemaVersion") == 1, "schemaVersion must be 1"
assert isinstance(d.get("author"), str), "author must be a string"
assert isinstance(d.get("skills", []), list), "skills must be an array"
assert isinstance(d.get("hooks"), list) and d["hooks"], "hooks must be a non-empty array"
assert d.get("icon"), "icon is required by the MINIMAX manifest"
print("ok")
' "$task/plugins/mcode-herdr-agent/.minimax-plugin/plugin.json" 2>&1) \
    || fail "the MINIMAX manifest is not valid for mcode: $out"
  [ ! -f "$task/plugins/mcode-herdr-agent/plugin.json" ] \
    || fail "the portable root plugin.json must not ship: mcode reads it first and resolves a hook-less plugin"

  pass "the per-task runtime dir carries a physical plugins directory with a loadable package"
}

# =============================================================================
# 2. the v2 and config.yaml exclusions must be unchanged
# =============================================================================

test_task_dir_exclusions_unchanged() {
  local base task
  base=$(make_runtime_data_dir "$TMP_ROOT/data2")
  task="$TMP_ROOT/task2"

  FUNCS="$TMP_ROOT/fns2.sh"
  : > "$FUNCS"
  for fn in copy_mcode_plugins_dir setup_mcode_task_dir; do
    body=$(extract_fn "$fn")
    [ -n "$body" ] || fail "could not extract $fn from fm-spawn.sh"
    printf '%s\n' "$body" >> "$FUNCS"
  done
  # shellcheck source=/dev/null
  . "$FUNCS"

  setup_mcode_task_dir "$task" "$base"

  # v2 stays excluded: mcode refuses a symlinked migration-lock path.
  [ ! -e "$task/v2" ] || fail "v2 must stay excluded from the per-task mirror"

  # config.yaml stays a real per-task file with the permission override.
  [ -f "$task/config.yaml" ] || fail "config.yaml must be a real file in the per-task dir"
  [ ! -L "$task/config.yaml" ] || fail "config.yaml must not be a symlink"
  grep -q '^permissionMode: bypassPermissions$' "$task/config.yaml" \
    || fail "the per-task config.yaml must carry permissionMode: bypassPermissions"

  # Every other entry keeps the old mirrored-symlink behaviour.
  [ -L "$task/sessions" ] || fail "other runtime entries must stay mirrored as symlinks"

  pass "the v2 and config.yaml exclusions are unchanged and other entries still mirror as symlinks"
}

# =============================================================================
# 3. the copied package really is loadable by the mcode CLI
# =============================================================================

test_copied_package_is_loadable_by_mcode() {
  local base task probe out
  if ! command -v mcode >/dev/null 2>&1; then
    printf 'ok - the copied package is loadable by mcode (skipped: mcode is not installed)\n'
    return 0
  fi
  base=$(make_runtime_data_dir "$TMP_ROOT/data3")
  task="$TMP_ROOT/task3"

  FUNCS="$TMP_ROOT/fns3.sh"
  : > "$FUNCS"
  for fn in copy_mcode_plugins_dir setup_mcode_task_dir; do
    body=$(extract_fn "$fn")
    [ -n "$body" ] || fail "could not extract $fn from fm-spawn.sh"
    printf '%s\n' "$body" >> "$FUNCS"
  done
  # shellcheck source=/dev/null
  . "$FUNCS"

  setup_mcode_task_dir "$task" "$base"

  # Point a scratch runtime data dir at the per-task plugins directory and ask
  # the real CLI to enumerate the local marketplace.
  probe="$TMP_ROOT/probe3"
  mkdir -p "$probe"
  cp -R "$task/plugins" "$probe/plugins"
  [ ! -L "$probe/plugins" ] || fail "the probe marketplace must be physical"

  out=$(MINIMAX_DATA_DIR="$probe" timeout 120 mcode plugin list --marketplace local 2>&1) \
    || fail "mcode plugin list failed: $out"
  printf '%s\n' "$out" | grep -q 'mcode-herdr-agent@local' \
    || fail "mcode must enumerate the copied package in the local marketplace: $out"

  pass "the copied package is loadable: mcode enumerates it as an enabled local plugin"
}

# =============================================================================
# 4. the semantic busy read stays fail-closed
# =============================================================================

test_busy_state_fail_closed() {
  local dir log resp fb out

  # A working agent is busy.
  dir="$TMP_ROOT/busy-working"; mkdir -p "$dir/responses"; log="$dir/log"; resp="$dir/responses"; : > "$log"
  printf '{"result":{"agent":{"agent_status":"working"}}}\n' > "$resp/1.out"
  fb=$(make_fake_herdr "$dir")
  out=$( PATH="$fb:$PATH" FM_HERDR_LOG="$log" FM_HERDR_RESPONSES="$resp" \
    bash -c '. "$0"; fm_backend_herdr_busy_state default:w1:p2' "$BACKEND" )
  [ "$out" = busy ] || fail "agent_status=working must map to busy, got '$out'"

  # An idle agent is idle.
  dir="$TMP_ROOT/busy-idle"; mkdir -p "$dir/responses"; log="$dir/log"; resp="$dir/responses"; : > "$log"
  printf '{"result":{"agent":{"agent_status":"idle"}}}\n' > "$resp/1.out"
  fb=$(make_fake_herdr "$dir")
  out=$( PATH="$fb:$PATH" FM_HERDR_LOG="$log" FM_HERDR_RESPONSES="$resp" \
    bash -c '. "$0"; fm_backend_herdr_busy_state default:w1:p2' "$BACKEND" )
  [ "$out" = idle ] || fail "agent_status=idle must map to idle, got '$out'"

  # No agent state at all must be unknown - never idle, never busy.
  dir="$TMP_ROOT/busy-none"; mkdir -p "$dir/responses"; log="$dir/log"; resp="$dir/responses"; : > "$log"
  printf '1\n' > "$resp/1.exit"
  fb=$(make_fake_herdr "$dir")
  out=$( PATH="$fb:$PATH" FM_HERDR_LOG="$log" FM_HERDR_RESPONSES="$resp" \
    bash -c '. "$0"; fm_backend_herdr_busy_state default:w1:p2' "$BACKEND" )
  [ "$out" = unknown ] || fail "a failed agent get must report unknown, never idle, got '$out'"

  # A response with no usable status must be unknown too.
  dir="$TMP_ROOT/busy-garbage"; mkdir -p "$dir/responses"; log="$dir/log"; resp="$dir/responses"; : > "$log"
  printf '{"result":{"agent":{"agent_status":"bogus-state"}}}\n' > "$resp/1.out"
  fb=$(make_fake_herdr "$dir")
  out=$( PATH="$fb:$PATH" FM_HERDR_LOG="$log" FM_HERDR_RESPONSES="$resp" \
    bash -c '. "$0"; fm_backend_herdr_busy_state default:w1:p2' "$BACKEND" )
  [ "$out" = unknown ] || fail "an unrecognised agent status must report unknown, never idle, got '$out'"

  # The classifier itself never promotes unknown to idle.
  out=$( bash -c '. "$0"; fm_backend_herdr_classify_agent_status ""' "$BACKEND" )
  [ "$out" = unknown ] || fail "an empty agent status must classify as unknown, got '$out'"
  out=$( bash -c '. "$0"; fm_backend_herdr_classify_agent_status "unknown"' "$BACKEND" )
  [ "$out" = unknown ] || fail "an unknown agent status must classify as unknown, got '$out'"

  pass "the busy read stays fail-closed: working->busy, idle->idle, no state->unknown (never idle)"
}

# =============================================================================
# 5. the reporter recovers the pane identity mcode's filtered env drops
# =============================================================================

test_reporter_recovers_pane_from_ancestor_env() {
  local dir log resp fb out

  dir="$TMP_ROOT/reporter"; mkdir -p "$dir/responses"; log="$dir/log"; resp="$dir/responses"; : > "$log"
  fb=$(make_fake_herdr "$dir")

  # The hook environment mcode hands a hook process carries no HERDR_* at all.
  # The reporter must recover them from the mcode process that spawned it, so
  # the pane identity is present in the parent's EXEC-TIME environment and
  # stripped from the child's. (The parent is exec'd with the variables rather
  # than exporting them after start: /proc/<pid>/environ reports the
  # environment as it was at exec, which is exactly what a real mcode process
  # carries, because it inherits the pane environment at launch.)
  out=$( PATH="$fb:$PATH" FM_HERDR_LOG="$log" FM_HERDR_RESPONSES="$resp" \
    REPORTER_PATH="$REPORTER" \
    env HERDR_ENV=1 HERDR_PANE_ID=w1:p2 HERDR_BIN_PATH="$fb/herdr" \
    bash -c 'env -i PATH="$PATH" HOME="$HOME" "$REPORTER_PATH" working < /dev/null' 2>&1 )

  assert_contains "$(cat "$log")" 'report-agent' "the reporter must call herdr pane report-agent"
  assert_contains "$(cat "$log")" 'w1:p2' "the reporter must report against the recovered pane id"
  pass "the reporter recovers the pane identity from the spawning mcode process"
}

test_reporter_stays_silent_without_pane_identity() {
  local dir log resp fb out

  dir="$TMP_ROOT/reporter-silent"; mkdir -p "$dir/responses"; log="$dir/log"; resp="$dir/responses"; : > "$log"
  fb=$(make_fake_herdr "$dir")

  # No HERDR_* anywhere in the chain: the reporter must do nothing at all.
  # `env -i` strips the environment on purpose - that is the case under test.
  # shellcheck disable=SC2097,SC2098
  out=$( PATH="$fb:$PATH" FM_HERDR_LOG="$log" FM_HERDR_RESPONSES="$resp" \
    env -i PATH="$PATH" HOME="$HOME" "$REPORTER" working 2>&1 )
  [ -z "$(cat "$log")" ] || fail "the reporter must stay silent when no pane identity is available: $(cat "$log")"
  pass "the reporter stays silent when no pane identity can be found"
}

# =============================================================================
# runner
# =============================================================================

test_task_dir_has_physical_plugins_dir
test_task_dir_exclusions_unchanged
test_copied_package_is_loadable_by_mcode
test_busy_state_fail_closed
test_reporter_recovers_pane_from_ancestor_env
test_reporter_stays_silent_without_pane_identity

printf 'all mcode herdr agent plugin tests passed\n'
