#!/usr/bin/env bash
# Behaviour tests for the per-task minimax-code runtime dir that bin/fm-spawn.sh
# builds at $TASK_TMP/mcode.
#
# The dir exists so an unattended mcode lane cannot park on an interactive
# permission gate: it carries its own config.yaml with permissionMode set to
# bypassPermissions, and every other base entry is symlinked into it so the
# lane sees the installed runtime state.
#
# mcode 0.6.12 refuses to start when its v2 runtime tree is reached through a
# symlink: it prints "Unsafe migration lock symlink path: <path>" and exits,
# which leaves the pane showing the banner and then a dead shell. So v2 is a
# REAL directory in the task dir while every other base entry stays a symlink.
#
# The launch also keeps the data dir and the config dir as DIFFERENT paths. mcode
# binds its OAuth credential to the literal auth-home path, so a per-task data
# dir makes every spawned agent ask for a login. Only the config dir is
# per-task, because that is where permissionMode must differ per task.
#
# The model axis is checked here too, because the same launch command carries
# it: a secondmate launch whose durable config/secondmate-harness pin names a
# model must thread that model into the launch command and into the task meta.
#
# These tests drive the real bin/fm-spawn.sh through a stub tmux and assert on
# the artefacts it leaves behind, so they fail against a spawn script that
# builds the wrong dir shape or drops the model axis.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
BASE_PATH=${FM_TEST_BASE_PATH:-/usr/bin:/bin:/usr/sbin:/sbin}
# Pin the runtime backend so the suite never inherits the host's ambient
# backend (an auto-detected herdr runtime would try to create real panes).
export FM_BACKEND=tmux
TMP_ROOT=$(fm_test_tmproot fm-mcode-task-dir)

cleanup_mcode_task_dir() {
  # bin/fm-spawn.sh pins the per-task root at /tmp/fm-<id>, outside this
  # suite's temp root, so the spawned task dirs are removed explicitly.
  rm -rf "$TMP_ROOT" /tmp/fm-mcode-task-dir-*
}
trap cleanup_mcode_task_dir EXIT

# The per-task root is /tmp/fm-<id>, so the task id carries a per-run suffix.
# Two suites running at once must not share one task root, or one run reads
# the other run's symlinks and reports a false failure.
TASK_PREFIX="mcode-task-dir-$$"

# A stub tmux that captures the literal `send-keys -l <cmd>` launch command,
# so the constructed launch command (not just the meta) can be asserted on.
make_launch_capturing_tmux() {
  local dir=$1 fakebin="$1/fakebin"
  mkdir -p "$fakebin"
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
set -u
case "$*" in
  *"#{pane_current_path}"*) printf '%s\n' "${FM_FAKE_PANE_PATH:-}"; exit 0 ;;
esac
case "${1:-}" in
  display-message) printf 'firstmate\n'; exit 0 ;;
  list-windows) exit 0 ;;
  has-session|new-session|new-window|kill-window) exit 0 ;;
  send-keys)
    if [ -n "${FM_FAKE_LAUNCH_LOG:-}" ]; then
      prev=
      for a in "$@"; do
        if [ "$prev" = "-l" ]; then
          printf '%s\n' "$a" >> "$FM_FAKE_LAUNCH_LOG"
        fi
        prev=$a
      done
    fi
    exit 0
    ;;
esac
exit 0
SH
  chmod +x "$fakebin/tmux"
  printf '%s\n' "$fakebin"
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

# The seed marker names the task id, so the seeded home is named after the id
# the spawn runs under.

# A fake base minimax runtime dir. <base> is created with a config.yaml that
# carries a permissionMode line when <with_perm> is yes, and with the extra
# runtime entries the task dir is expected to symlink.
make_base_dir() {
  local base=$1 with_perm=$2
  mkdir -p "$base/agents" "$base/auth" "$base/v2/migration" "$base/preferences"
  printf 'agent payload\n' > "$base/agents/a.txt"
  printf 'auth payload\n' > "$base/auth/a.txt"
  printf 'pref payload\n' > "$base/preferences/a.txt"
  printf 'migration payload\n' > "$base/v2/migration/a.txt"
  if [ "$with_perm" = yes ]; then
    printf 'logLevel: info\npermissionMode: ask\ndefaultModel: minimax/MiniMax-M3.1-Flash\n' > "$base/config.yaml"
  else
    printf 'logLevel: info\ndefaultModel: minimax/MiniMax-M3.1-Flash\n' > "$base/config.yaml"
  fi
}

# spawn_secondmate_capture <world> <id> <home> <launchlog> <base_dir>
# Runs the real bin/fm-spawn.sh in secondmate mode with the given base
# minimax dir standing in for the installed runtime, and captures the launch
# command. The harness is resolved from config/secondmate-harness, so the
# durable model pin applies exactly as it does in production.
spawn_secondmate_capture() {
  local world=$1 id=$2 home=$3 launchlog=$4 base=$5 fakebin
  mkdir -p "$world/home/state" "$world/home/data"
  fakebin=$(make_launch_capturing_tmux "$world/tmux-$id")
  : > "$launchlog"
  PATH="$fakebin:$BASE_PATH" TMUX='' CLAUDECODE=1 \
    FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$world/home" \
    FM_STATE_OVERRIDE="$world/home/state" FM_DATA_OVERRIDE="$world/home/data" \
    FM_PROJECTS_OVERRIDE="$world/home/projects" FM_CONFIG_OVERRIDE="$world/home/config" \
    MINIMAX_DATA_DIR="$base" \
    FM_SPAWN_NO_GUARD=1 FM_FAKE_LAUNCH_LOG="$launchlog" \
    "$SPAWN" "$id" "$home" --secondmate >/dev/null 2>&1 || true
}

meta_field() { grep "^$2=" "$1" 2>/dev/null | tail -1 | cut -d= -f2-; }

# The task dir the spawn built for <id>.
task_dir() { printf '/tmp/fm-%s/mcode\n' "$1"; }

# A real directory is a directory that is not a symlink.
is_real_dir() { [ -d "$1" ] && [ ! -L "$1" ]; }

# The base entries the task dir is expected to symlink. config.yaml is
# deliberately excluded: the task dir carries its own rewritten copy.
BASE_ENTRIES="agents auth preferences"

# Case 1: the base config.yaml has a permissionMode line.
test_task_dir_shape_with_base_permission_mode() {
  local w id sm base task launchlog meta
  w="$TMP_ROOT/shape-with-perm"
  id="$TASK_PREFIX-with-perm"
  sm="$w/sm"
  base="$w/base"
  launchlog="$w/launch.log"
  make_seeded_home "$sm" "$id"
  make_base_dir "$base" yes
  mkdir -p "$w/home/config"
  printf 'minimax-code minimax/MiniMax-M3.1-Flash medium\n' > "$w/home/config/secondmate-harness"

  spawn_secondmate_capture "$w" "$id" "$sm" "$launchlog" "$base"
  task=$(task_dir "$id")
  meta="$w/home/state/$id.meta"

  [ -d "$task" ] || fail "shape-with-perm: no per-task mcode dir at $task"
  [ -f "$meta" ] || fail "shape-with-perm: no task meta at $meta"

  is_real_dir "$task/v2" \
    || fail "shape-with-perm: task dir v2 must be a REAL directory, not a symlink (mcode refuses a symlinked v2 with 'Unsafe migration lock symlink path')"
  # Nothing under v2 may be a symlink either: mcode's migration lock lives
  # under v2/migration and refuses a symlinked path there too.
  local v2child
  for v2child in "$task/v2"/*; do
    [ -e "$v2child" ] || continue
    [ ! -L "$v2child" ] \
      || fail "shape-with-perm: task dir entry v2/$(basename "$v2child") must not be a symlink"
  done

  local b
  for b in $BASE_ENTRIES; do
    [ -L "$task/$b" ] \
      || fail "shape-with-perm: task dir entry $b must still be a symlink into the base dir"
    [ "$(readlink "$task/$b")" = "$base/$b" ] \
      || fail "shape-with-perm: task dir entry $b symlinks to '$(readlink "$task/$b")', expected '$base/$b'"
  done
  [ ! -e "$task/config.yaml.bak-mcode12" ] || fail "shape-with-perm: unexpected fixture artefact"

  assert_grep 'permissionMode: bypassPermissions' "$task/config.yaml" \
    "shape-with-perm: task config.yaml must carry permissionMode: bypassPermissions"
  assert_no_grep 'permissionMode: ask' "$task/config.yaml" \
    "shape-with-perm: task config.yaml must not keep the base permissionMode value"
  assert_grep 'defaultModel: minimax/MiniMax-M3.1-Flash' "$task/config.yaml" \
    "shape-with-perm: task config.yaml must keep the rest of the base config"

  pass "task dir: v2 is a real directory, every other base entry stays symlinked, config.yaml carries bypassPermissions"
}

# Case 2: the base config.yaml has NO permissionMode line.
test_task_dir_shape_without_base_permission_mode() {
  local w id sm base task launchlog
  w="$TMP_ROOT/shape-without-perm"
  id="$TASK_PREFIX-without-perm"
  sm="$w/sm"
  base="$w/base"
  launchlog="$w/launch.log"
  make_seeded_home "$sm" "$id"
  make_base_dir "$base" no
  mkdir -p "$w/home/config"
  printf 'minimax-code minimax/MiniMax-M3.1-Flash medium\n' > "$w/home/config/secondmate-harness"

  spawn_secondmate_capture "$w" "$id" "$sm" "$launchlog" "$base"
  task=$(task_dir "$id")

  [ -d "$task" ] || fail "shape-without-perm: no per-task mcode dir at $task"
  is_real_dir "$task/v2" \
    || fail "shape-without-perm: task dir v2 must be a REAL directory, not a symlink"
  local v2child
  for v2child in "$task/v2"/*; do
    [ -e "$v2child" ] || continue
    [ ! -L "$v2child" ] \
      || fail "shape-without-perm: task dir entry v2/$(basename "$v2child") must not be a symlink"
  done

  local b
  for b in $BASE_ENTRIES; do
    [ -L "$task/$b" ] \
      || fail "shape-without-perm: task dir entry $b must still be a symlink into the base dir"
  done

  assert_grep 'permissionMode: bypassPermissions' "$task/config.yaml" \
    "shape-without-perm: task config.yaml must carry permissionMode: bypassPermissions"
  assert_grep 'defaultModel: minimax/MiniMax-M3.1-Flash' "$task/config.yaml" \
    "shape-without-perm: task config.yaml must keep the rest of the base config"

  pass "task dir: with no permissionMode in the base config, the task config.yaml still gains bypassPermissions"
}

# Case 3: the durable pin names a model, so the model must reach the launch
# command and the task meta. mcode has no effort axis, so the effort token
# must be omitted from the launch without discarding the model.
test_model_axis_reaches_the_launch_command() {
  local w id sm base task launchlog meta launch
  w="$TMP_ROOT/model-axis"
  id="$TASK_PREFIX-model"
  sm="$w/sm"
  base="$w/base"
  launchlog="$w/launch.log"
  make_seeded_home "$sm" "$id"
  make_base_dir "$base" yes
  mkdir -p "$w/home/config"
  printf 'minimax-code minimax/MiniMax-M3.1-Flash medium\n' > "$w/home/config/secondmate-harness"

  spawn_secondmate_capture "$w" "$id" "$sm" "$launchlog" "$base"
  task=$(task_dir "$id")
  meta="$w/home/state/$id.meta"
  launch=$(cat "$launchlog" 2>/dev/null)

  [ -f "$meta" ] || fail "model-axis: no task meta at $meta"
  [ -n "$launch" ] || fail "model-axis: no launch command was captured"

  assert_equals "minimax/MiniMax-M3.1-Flash" "$(meta_field "$meta" model)" \
    "model-axis: task meta must record the pinned model"
  assert_equals "medium" "$(meta_field "$meta" effort)" \
    "model-axis: task meta must record the pinned effort"

  assert_contains "$launch" "mcode --model 'minimax/MiniMax-M3.1-Flash'" \
    "model-axis: launch command must carry the pinned --model"
  assert_contains "$launch" "MCODE_CONFIG_DIR='$task'" \
    "model-axis: launch command must point the runtime config at the per-task dir"
  assert_contains "$launch" "MINIMAX_DATA_DIR='$base'" \
    "model-axis: launch command must keep the runtime data dir on the real base dir"
  case "$launch" in
    *"MINIMAX_DATA_DIR='$task'"*)
      fail "model-axis: launch command must NOT point MINIMAX_DATA_DIR at the per-task dir (mcode keys its OAuth credential on the literal auth-home path)"
      ;;
    *) : ;;
  esac
  assert_not_contains "$launch" "--effort" \
    "model-axis: mcode has no effort axis, so the launch command must carry no effort flag"

  pass "model axis: the durable pin threads --model into the minimax-code launch command and the task meta"
}

test_task_dir_shape_with_base_permission_mode
test_task_dir_shape_without_base_permission_mode
test_model_axis_reaches_the_launch_command

pass "per-task minimax-code runtime dir: real v2, symlinked base entries, bypassPermissions, threaded model"
