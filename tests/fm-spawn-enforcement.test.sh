#!/usr/bin/env bash
# Exercise the lease refusal and project-capacity deferral through fm-spawn.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"

make_project_fixture() {
  local root=$1
  mkdir -p "$root/config" "$root/data" "$root/state" "$root/projects/wire-enforcement"
  git -C "$root/projects/wire-enforcement" init -q
  printf 'claude\n' > "$root/config/supervision-host"
  printf 'wire-enforcement 1\n' > "$root/config/project-capacity"
}

test_branch_spawn_refuses_with_reason() {
  local root project out rc
  root=$(fm_test_tmproot spawn-lease-refusal)
  make_project_fixture "$root"
  # shellcheck source=bin/fm-supervision-engine-lib.sh
  . "$ROOT/bin/fm-supervision-engine-lib.sh"
  fm_supervision_host_config "$root/config" codex \
    || fail "configured Codex supervision host did not resolve"
  [ "$FM_SUPERVISION_ENGINE" = claude ] \
    || fail "configured supervision host did not select the declared Claude engine"
  project="$root/projects/wire-enforcement"
  out=$(FM_HOME="$root" FM_SUPERVISION_ACTOR=branch FM_SPAWN_NO_GUARD=1 \
    bash "$SPAWN" blocked-task "$project" --harness pi --backend tmux 2>&1)
  rc=$?
  [ "$rc" -eq 6 ] || fail "branch spawn must refuse with lease exit 6, got $rc: $out"
  printf '%s\n' "$out" | grep -Fq 'the supervision branch never performs this action' \
    || fail "branch spawn refusal omitted its reason: $out"
  [ ! -e "$root/state/blocked-task.meta" ] || fail "refused branch spawn wrote task metadata"
  pass "branch spawn dry invocation refuses with a logged reason before task creation"
}

test_project_capacity_defers_without_launch() {
  local root project out rc lock
  root=$(fm_test_tmproot spawn-capacity-deferral)
  make_project_fixture "$root"
  project="$root/projects/wire-enforcement"
  cat > "$root/state/holder.meta" <<META
project=$project
kind=ship
META
  out=$(FM_HOME="$root" FM_SPAWN_NO_GUARD=1 \
    bash "$SPAWN" deferred-task "$project" --harness pi --backend tmux 2>&1)
  rc=$?
  [ "$rc" -eq 75 ] || fail "full project capacity must defer with exit 75, got $rc: $out"
  printf '%s\n' "$out" | grep -Fq 'deferred: project wire-enforcement admits 1 worker(s)' \
    || fail "capacity deferral omitted its reason: $out"
  [ ! -e "$root/state/deferred-task.meta" ] || fail "deferred spawn wrote task metadata"
  for lock in "$root"/state/.treehouse-project-*.lock; do
    [ ! -e "$lock" ] && [ ! -L "$lock" ] || fail "deferred spawn retained the project admission lock: $lock"
  done
  pass "over-capacity spawn dry invocation defers before worker launch"
}

test_branch_spawn_refuses_with_reason
test_project_capacity_defers_without_launch
