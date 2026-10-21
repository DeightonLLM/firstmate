#!/usr/bin/env bash
# Behaviour tests for the spawn-side plugin isolation of a dispatched MCode
# lane, and for the reporter shim that makes the lane's plugin hooks reach
# Herdr.
#
# Two independent facts are covered here, because a lane only self-reports when
# BOTH hold.
#
# 1. The per-task runtime dir that bin/fm-spawn.sh builds carries a PHYSICAL
#    plugin root. The MCode CLI refuses a symlinked plugin root with
#    "PLUGIN_ROOT_SYMLINK: Plugin root must be a physical directory", so a
#    lane whose plugin root is a symlink cannot load the local package at all.
#    Every other base entry stays a symlink into the base runtime, and v2 stays
#    a real directory because mcode refuses a symlinked v2 as well.
#
# 2. MCode spawns lifecycle hooks with a fixed environment whitelist that
#    carries no HERDR_* variable. The reporter inside such a hook would
#    therefore refuse to act, so the installed shim has to recover the pane
#    identity from the MCode process that spawned it. Without that recovery
#    every hook is a silent no-op and the lane never registers with Herdr.
#
# The tests drive the real bin/fm-spawn.sh and the real
# bin/fm-install-mcode-herdr-agent.sh through stubs, and assert on the
# artefacts they leave behind.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
INSTALLER="$ROOT/bin/fm-install-mcode-herdr-agent.sh"
BASE_PATH=${FM_TEST_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}
# Pin the runtime backend so the suite never inherits the host's ambient
# backend (an auto-detected herdr runtime would try to create real panes).
export FM_BACKEND=tmux
TMP_ROOT=$(fm_test_tmproot fm-spawn-plugin-root)

cleanup_plugin_root() {
  # bin/fm-spawn.sh pins the per-task root at /tmp/fm-<id>, outside this
  # suite's temp root, so the spawned task dirs are removed explicitly.
  rm -rf "$TMP_ROOT" /tmp/fm-spawn-plugin-root-*
}
trap cleanup_plugin_root EXIT

TASK_PREFIX="mcode-plugin-root-$$"

# A stub tmux that swallows the launch, so the suite never opens a real pane.
make_stub_tmux() {
  local fakebin="$1/fakebin"
  mkdir -p "$fakebin"
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  display-message) printf 'firstmate\n'; exit 0 ;;
esac
exit 0
SH
  chmod +x "$fakebin/tmux"
  printf '%s\n' "$fakebin"
}

# A stub mcode that records how it was called, so the suite can assert that
# the per-task enable ran against the per-task runtime dir alone.
make_stub_mcode() {
  local fakebin=$1 log=$2
  cat > "$fakebin/mcode" <<SH
#!/usr/bin/env bash
set -u
printf '%s %s\n' "\${MINIMAX_DATA_DIR:-}" "\$*" >> "$log"
exit 0
SH
  chmod +x "$fakebin/mcode"
}

# A minimal seeded secondmate home: the spawn validates the seed marker,
# AGENTS.md, bin/ and a charter before it launches.
make_seeded_home() {
  local home=$1 id=$2
  mkdir -p "$home/bin" "$home/data"
  printf '# Firstmate\n' > "$home/AGENTS.md"
  printf '%s\n' "$id" > "$home/.fm-secondmate-home"
  printf 'charter\n' > "$home/data/charter.md"
}

# A fake base minimax runtime dir with a local marketplace that carries one
# package directory, so the plugin-root copy has something to copy.
make_base_dir() {
  local base=$1
  mkdir -p "$base/agents" "$base/auth" "$base/preferences" "$base/v2/migration"
  mkdir -p "$base/plugins/mcode-herdr-agent/.minimax-plugin" "$base/plugins/mcode-herdr-agent/hooks"
  printf 'agent payload\n' > "$base/agents/a.txt"
  printf 'auth payload\n' > "$base/auth/a.txt"
  printf 'pref payload\n' > "$base/preferences/a.txt"
  printf 'migration payload\n' > "$base/v2/migration/a.txt"
  printf '{"name":"mcode-herdr-agent"}\n' > "$base/plugins/mcode-herdr-agent/.minimax-plugin/plugin.json"
  printf '{"hooks":{}}\n' > "$base/plugins/mcode-herdr-agent/hooks/hooks.json"
  printf 'logLevel: info\npermissionMode: ask\ndefaultModel: minimax/MiniMax-M3.1-Flash\n' > "$base/config.yaml"
}

# spawn_capture <world> <id> <home> <base_dir> <mcode_log>
# Runs the real bin/fm-spawn.sh in secondmate mode with the given base
# minimax dir standing in for the installed runtime.
spawn_capture() {
  local world=$1 id=$2 home=$3 base=$4 mcode_log=$5 fakebin
  mkdir -p "$world/home/state" "$world/home/data" "$world/home/config"
  fakebin=$(make_stub_tmux "$world")
  make_stub_mcode "$fakebin" "$mcode_log"
  printf 'minimax-code minimax/MiniMax-M3.1-Flash medium\n' > "$world/home/config/secondmate-harness"
  PATH="$fakebin:$BASE_PATH" TMUX='' CLAUDECODE=1 \
    FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$world/home" \
    FM_STATE_OVERRIDE="$world/home/state" FM_DATA_OVERRIDE="$world/home/data" \
    FM_PROJECTS_OVERRIDE="$world/home/projects" FM_CONFIG_OVERRIDE="$world/home/config" \
    MINIMAX_DATA_DIR="$base" \
    FM_SPAWN_NO_GUARD=1 \
    "$SPAWN" "$id" "$home" --secondmate >/dev/null 2>&1 || true
}

# Case 1: the per-task plugin root is physical and every other base entry
# stays a symlink.
test_plugin_root_is_physical_and_other_entries_stay_symlinks() {
  local w id sm base task mcode_log
  w="$TMP_ROOT/plugin-root"
  id="$TASK_PREFIX-root"
  sm="$w/sm"
  base="$w/base"
  mcode_log="$w/mcode.log"
  make_seeded_home "$sm" "$id"
  make_base_dir "$base"

  spawn_capture "$w" "$id" "$sm" "$base" "$mcode_log"
  task="/tmp/fm-$id/mcode"

  [ -d "$task" ] || fail "plugin-root: no per-task mcode dir at $task"

  # The plugin root must be a real directory, never a symlink.
  [ -d "$task/plugins" ] || fail "plugin-root: task dir has no plugins entry"
  [ ! -L "$task/plugins" ] \
    || fail "plugin-root: task dir plugins entry must be a REAL directory, not a symlink (mcode refuses a symlinked plugin root with PLUGIN_ROOT_SYMLINK)"
  [ -d "$task/plugins/mcode-herdr-agent" ] \
    || fail "plugin-root: the local package was not copied into the task dir plugin root"
  assert_present "$task/plugins/mcode-herdr-agent/.minimax-plugin/plugin.json" \
    "plugin-root: the copied package must carry its manifest"
  [ ! -L "$task/plugins/mcode-herdr-agent" ] \
    || fail "plugin-root: the copied package directory must not be a symlink"

  # Every other base entry stays a symlink into the base runtime.
  local b
  for b in agents auth preferences; do
    [ -L "$task/$b" ] \
      || fail "plugin-root: task dir entry $b must still be a symlink into the base dir"
    assert_equals "$base/$b" "$(readlink "$task/$b")" \
      "plugin-root: task dir entry $b must symlink to the base entry"
  done

  # v2 stays a real directory, and nothing under it is a symlink.
  [ -d "$task/v2" ] && [ ! -L "$task/v2" ] \
    || fail "plugin-root: task dir v2 must be a REAL directory, not a symlink"
  local v2child
  for v2child in "$task/v2"/*; do
    [ -e "$v2child" ] || continue
    [ ! -L "$v2child" ] \
      || fail "plugin-root: task dir entry v2/$(basename "$v2child") must not be a symlink"
  done

  pass "per-task plugin root: physical plugin root with the local package copied in, every other base entry still symlinked"
}

# Case 2: the local package is enabled in the per-task runtime dir, and the
# enable runs against that dir alone, so the base runtime's marketplace and
# enabled state are untouched by a spawn.
test_local_package_is_enabled_in_the_task_dir() {
  local w id sm base task mcode_log calls
  w="$TMP_ROOT/enable"
  id="$TASK_PREFIX-enable"
  sm="$w/sm"
  base="$w/base"
  mcode_log="$w/mcode.log"
  mkdir -p "$w"
  : > "$mcode_log"
  make_seeded_home "$sm" "$id"
  make_base_dir "$base"

  spawn_capture "$w" "$id" "$sm" "$base" "$mcode_log"
  task="/tmp/fm-$id/mcode"

  [ -f "$mcode_log" ] || fail "enable: the spawn never called the mcode CLI"
  calls=$(cat "$mcode_log")
  assert_contains "$calls" "plugin enable mcode-herdr-agent@local" \
    "enable: the spawn must enable the local package with the supported verb"
  assert_contains "$calls" "$task plugin enable" \
    "enable: the enable must run against the per-task runtime dir, not the base runtime"

  pass "local package: enabled in the per-task runtime dir with the supported verb, against that dir alone"
}

# Case 3: the installed shim recovers the pane identity that MCode strips
# from the hook environment, so the hook is not a silent no-op.
test_installed_shim_recovers_the_stripped_herdr_environment() {
  local w marketplace bindir home shim fakeherdr herdrlog reporter
  w="$TMP_ROOT/shim"
  marketplace="$w/marketplace"
  bindir="$w/bin"
  home="$w/home"
  fakeherdr="$w/fakeherdr"
  herdrlog="$w/herdr.log"
  reporter="$w/reporter.sh"
  mkdir -p "$home" "$fakeherdr"
  : > "$herdrlog"

  # A stub herdr that records the report it was asked to make.
  cat > "$fakeherdr/herdr" <<SH
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$herdrlog"
exit 0
SH
  chmod +x "$fakeherdr/herdr"

  # A stub reporter that records the arguments the shim passed on.
  cat > "$reporter" <<SH
#!/usr/bin/env bash
printf 'reporter %s\n' "\$*" >> "$herdrlog"
exit 0
SH
  chmod +x "$reporter"

  # Run the installer into a temp marketplace and a temp PATH dir.
  local fakebin
  fakebin=$(make_stub_tmux "$w")
  make_stub_mcode "$fakebin" "$w/mcode.log"
  PATH="$fakebin:$BASE_PATH" FM_HOME="$home" \
    FM_MCODE_MARKETPLACE_DIR="$marketplace" FM_HERDR_AGENT_BIN_DIR="$bindir" \
    "$INSTALLER" >/dev/null 2>&1 \
    || fail "shim: the installer must succeed against a temp marketplace"
  shim="$bindir/fm-herdr-agent-report.sh"
  [ -x "$shim" ] || fail "shim: the installer must publish an executable shim"

  # The shim must read the pane identity back out of the spawning process.
  assert_grep "/proc/\$pid/environ" "$shim" \
    "shim: the shim must recover the pane identity from /proc/<pid>/environ"
  assert_grep 'HERDR_PANE_ID' "$shim" \
    "shim: the shim must recover HERDR_PANE_ID"

  # Behaviour: run the shim the way MCode runs a hook - with a stripped
  # environment - from a parent that still carries the pane identity. The
  # helper starts with the identity in its own environment and then starts the
  # shim with every HERDR_* variable removed, which is exactly what MCode does.
  # The identity has to be in the helper's environment at exec time, because
  # /proc/<pid>/environ keeps the environment a process started with and
  # nothing that process exports afterwards.
  local helper="$w/hook-runner.sh"
  cat > "$helper" <<SH
#!/usr/bin/env bash
env -u HERDR_ENV -u HERDR_PANE_ID -u HERDR_BIN_PATH bash "$shim" working
status=\$?
exit \$status
SH
  chmod +x "$helper"

  # A hook runs inside the agent's own output stream, so the shim must stay
  # silent on stdout even when it reports.
  local out
  out=$(cd "$w" && env HERDR_ENV=1 HERDR_PANE_ID=wTEST:p9 \
    HERDR_BIN_PATH="$fakeherdr/herdr" HOME="$w" PATH="$fakebin:$BASE_PATH" \
    bash "$helper" 2>/dev/null) || true
  assert_equals "" "$out" \
    "shim: the hook must not write to stdout, or it corrupts the agent's output"
  assert_contains "$(cat "$herdrlog")" "pane report-agent wTEST:p9" \
    "shim: the shim must report the recovered pane to herdr even when the hook environment is stripped"

  pass "installed shim: recovers the pane identity MCode strips from the hook environment and reports to herdr"
}

test_plugin_root_is_physical_and_other_entries_stay_symlinks
test_local_package_is_enabled_in_the_task_dir
test_installed_shim_recovers_the_stripped_herdr_environment

pass "spawn plugin isolation: physical per-task plugin root, per-task enable, and a shim that reaches herdr"
