#!/usr/bin/env bash
# Regression test: config/ must stay untracked in git.
#
# config/ is captain-private and gitignored (AGENTS.md section 2, .gitignore
# line 11, docs/configuration.md). The inherited-local-material propagation in
# bin/fm-config-inherit-lib.sh gates every destination item on
# `git check-ignore`, and `git check-ignore` consults the INDEX: a tracked path
# is reported as NOT ignored. A tracked config/ file therefore makes the
# destination guard reject every inherited item, so the propagation into
# secondmate homes is silently skipped with a warning instead of running.
#
# This test fails if any path under config/ is tracked again.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck source=/dev/null
. "$ROOT/bin/fm-config-inherit-lib.sh"

# No path under config/ may be tracked. An empty ls-files result is the
# contract: the directory is gitignored local material, not repo content.
test_config_dir_has_no_tracked_path() {
  local tracked
  tracked=$(git -C "$ROOT" ls-files -- config/)
  [ -z "$tracked" ] \
    || fail "config/ must stay untracked, but git tracks these paths:$(printf '\n')$tracked"
  pass "no path under config/ is tracked in git"
}

# The repo root must actually ignore config/, not merely lack tracked content.
# This is the rule the inheritance guard consults.
test_config_dir_is_gitignored() {
  git -C "$ROOT" check-ignore -q -- config/crew-dispatch.json \
    || fail "config/crew-dispatch.json is not gitignored for the repo root"
  pass "config/crew-dispatch.json is gitignored for the repo root"
}

# The behavioural consequence: the destination guard must ALLOW an inherited
# config item for the repo root. A tracked config/ path made this return
# false and silently skipped every inherited item.
test_inheritance_guard_allows_a_config_item() {
  destination_allows_inherited_item "$ROOT/config" crew-dispatch.json \
    || fail "the inheritance guard rejects an inherited config item for the repo root"
  pass "the inheritance guard allows an inherited config item for the repo root"
}

test_config_dir_has_no_tracked_path
test_config_dir_is_gitignored
test_inheritance_guard_allows_a_config_item

echo "# all fm-config-not-tracked tests passed"
