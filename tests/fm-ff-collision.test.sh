#!/usr/bin/env bash
# Tests for the fast-forward collision guard in bin/fm-ff-lib.sh.
#
# THE SHAPE UNDER TEST
#   A path can be TRACKED by the index and gitIGNORED by an ignore rule at the
#   same time, and it can carry a local working-tree change. When the index
#   entry also carries the skip-worktree or assume-unchanged bit, `git status
#   --porcelain` cannot see that change at all - so the dirty gate passed, the
#   fast-forward was attempted anyway, and git refused with "Your local changes
#   to the following files would be overwritten by merge". The helper printed
#   only git's FIRST line, so the refusal named no path and offered no way
#   forward. Measured 2026-10-24 in the residual-queue-20261020 home:
#   data/backlog.md and data/projects.md, tracked-but-carrying-a-local-change.
#
# THE GUARANTEES UNDER TEST
#   - A colliding tracked path is DETECTED before the merge is attempted, and
#     the status line NAMES it.
#   - The detection is GENERAL: any tracked path under any ignore rule, never a
#     data/ special case.
#   - The colliding working-tree content survives byte-exactly and HEAD does
#     not move: a refusal never loses or overwrites a local change.
#   - A home with no collision still fast-forwards; an unrelated dirty path is
#     still reported the way it always was; a tracked symlink is never a false
#     positive.
#   - The documented recovery recipe preserves the private content byte-exactly
#     and does advance the home.
#
# FM_FF_LIB lets the RED proof run this SAME suite against a mechanically
# extracted pre-fix copy of bin/fm-ff-lib.sh.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# shellcheck source=bin/fm-ff-lib.sh
# shellcheck disable=SC1090
. "${FM_FF_LIB:-$ROOT/bin/fm-ff-lib.sh}"

TMP_ROOT=$(fm_test_tmproot fm-ff-collision)
export FM_BACKEND=tmux

# Deterministic, isolated git identity for fixture commits.
fm_git_identity fmtest fmtest@example.com

# --- world builders --------------------------------------------------------

# new_world <name>: a PRIMARY firstmate repo on `main` whose operational dirs
# (data/, private/) are gitignored AND tracked - the collision shape - plus a
# home dir with state/ and data/. Echoes the world dir.
new_world() {
  local name=$1 w
  w="$TMP_ROOT/$name"
  mkdir -p "$w/home/state" "$w/home/data"
  git init -q -b main "$w/main"
  printf 'projects/\nstate/\ndata/\n.no-mistakes/\nconfig/\nprivate/\n' > "$w/main/.gitignore"
  printf 'v1\n' > "$w/main/AGENTS.md"
  printf 'r1\n' > "$w/main/README.md"
  mkdir -p "$w/main/bin" "$w/main/.agents/skills" "$w/main/data" "$w/main/private"
  printf 'echo a\n' > "$w/main/bin/tool.sh"
  printf 's1\n' > "$w/main/.agents/skills/note.md"
  # The tracked-but-ignored private paths: the shape that collides.
  printf 'upstream backlog\n' > "$w/main/data/backlog.md"
  printf 'upstream cache\n' > "$w/main/private/cache.bin"
  git -C "$w/main" add AGENTS.md README.md .gitignore bin .agents
  git -C "$w/main" add -f data/backlog.md private/cache.bin
  git -C "$w/main" commit -qm c1
  printf '%s\n' "$w"
}

# add_home <w> <id> <commit>: a secondmate home as a DETACHED worktree of the
# primary at <commit>, plus its seed marker and a LIVE kind=secondmate meta.
add_home() {
  local w=$1 id=$2 commit=$3
  git -C "$w/main" worktree add -q --detach "$w/$id" "$commit"
  printf '%s\n' "$id" > "$w/$id/.fm-secondmate-home"
  {
    printf 'window=firstmate:fm-%s\n' "$id"
    printf 'kind=secondmate\n'
    printf 'harness=codex\n'
    printf 'home=%s/%s\n' "$w" "$id"
  } > "$w/home/state/$id.meta"
}

# hide_private_edit <home> <path> <content> <bit>: the local, private change on
# a tracked-but-ignored path, plus the index bit that hides it from
# `git status --porcelain`. <bit> is --skip-worktree or --assume-unchanged.
hide_private_edit() {
  local home=$1 path=$2 content=$3 bit=$4
  printf '%s\n' "$content" > "$home/$path"
  git -C "$home" update-index "$bit" -- "$path"
}

# bump_private <w> <path>: advance the PRIMARY's main branch so the
# fast-forward would overwrite that private path.
bump_private() {
  local w=$1 path=$2
  printf 'upstream v2 %s\n' "$path" > "$w/main/$path"
  git -C "$w/main" add -f -- "$path"
  git -C "$w/main" commit -qm "bump $path"
}

head_of() { git -C "$1" rev-parse HEAD; }

# run_ff <dir> <base>: drive the shared ff helper in THIS shell (output to a
# file, not a subshell, so FF_STATUS / FF_INSTR propagate). Sets FF_OUT.
FF_OUT=""
run_ff() {
  local dir=$1 base=$2 outfile="$TMP_ROOT/ff.out"
  ff_target "$dir" "secondmate sm" "$base" yes yes >"$outfile" 2>&1
  FF_OUT=$(cat "$outfile")
}

# --- T1: skip-worktree collision - detected, named, content preserved ------
# The exact 2026-10-24 shape: a tracked-but-ignored private path carrying a
# local change, hidden from `git status --porcelain` by the skip-worktree bit.
test_collision_skip_worktree_detected() {
  local w c1 base before
  w=$(new_world collision-skip)
  c1=$(head_of "$w/main")
  add_home "$w" sm "$c1"
  hide_private_edit "$w/sm" data/backlog.md "LOCAL PRIVATE BACKLOG" --skip-worktree
  bump_private "$w" data/backlog.md
  base=$(primary_head_commit "$w/main")
  before=$(head_of "$w/sm")

  run_ff "$w/sm" "$base"

  [ "$FF_STATUS" = skipped ] || fail "FF_STATUS: expected skipped, got '$FF_STATUS'"
  assert_contains "$FF_OUT" "data/backlog.md" \
    "the colliding path must be named in the skip status line"
  assert_contains "$FF_OUT" "recovery:" \
    "a refusal must carry a usable way forward, not just a reason"
  assert_not_contains "$FF_OUT" "would be overwritten by merge" \
    "the guard must catch the collision BEFORE git refuses, not relay git's raw refusal"
  [ "$(head_of "$w/sm")" = "$before" ] || fail "a refused fast-forward must not move HEAD"
  assert_equals "LOCAL PRIVATE BACKLOG" "$(cat "$w/sm/data/backlog.md")" \
    "the colliding local content must survive byte-exactly"
  pass "T1 collision: a skip-worktree hidden tracked path is detected, named and preserved"
}

# --- T2: assume-unchanged collision - the same shape, the other bit --------
test_collision_assume_unchanged_detected() {
  local w c1 base before
  w=$(new_world collision-assume)
  c1=$(head_of "$w/main")
  add_home "$w" sm "$c1"
  hide_private_edit "$w/sm" data/backlog.md "LOCAL PRIVATE BACKLOG" --assume-unchanged
  bump_private "$w" data/backlog.md
  base=$(primary_head_commit "$w/main")
  before=$(head_of "$w/sm")

  run_ff "$w/sm" "$base"

  [ "$FF_STATUS" = skipped ] || fail "FF_STATUS: expected skipped, got '$FF_STATUS'"
  assert_contains "$FF_OUT" "data/backlog.md" \
    "the colliding path must be named for the assume-unchanged bit too"
  assert_contains "$FF_OUT" "recovery:" "a refusal must carry a usable way forward"
  [ "$(head_of "$w/sm")" = "$before" ] || fail "a refused fast-forward must not move HEAD"
  assert_equals "LOCAL PRIVATE BACKLOG" "$(cat "$w/sm/data/backlog.md")" \
    "the colliding local content must survive byte-exactly"
  pass "T2 collision: an assume-unchanged hidden tracked path is detected, named and preserved"
}

# --- T3: the guard is general - not a data/ special case --------------------
# The same shape under a different ignore rule and a different directory.
test_collision_detection_is_general() {
  local w c1 base before
  w=$(new_world collision-general)
  c1=$(head_of "$w/main")
  add_home "$w" sm "$c1"
  hide_private_edit "$w/sm" private/cache.bin "LOCAL PRIVATE CACHE" --skip-worktree
  bump_private "$w" private/cache.bin
  base=$(primary_head_commit "$w/main")
  before=$(head_of "$w/sm")

  run_ff "$w/sm" "$base"

  [ "$FF_STATUS" = skipped ] || fail "FF_STATUS: expected skipped, got '$FF_STATUS'"
  assert_contains "$FF_OUT" "private/cache.bin" \
    "a colliding path under any ignore rule must be named"
  assert_contains "$FF_OUT" "recovery:" "a refusal must carry a usable way forward"
  [ "$(head_of "$w/sm")" = "$before" ] || fail "a refused fast-forward must not move HEAD"
  assert_equals "LOCAL PRIVATE CACHE" "$(cat "$w/sm/private/cache.bin")" \
    "the colliding local content must survive byte-exactly"
  pass "T3 general: the collision guard is general across ignored paths, not a data/ check"
}

# --- T4: a VISIBLE dirty tracked path is named too --------------------------
# Without the hiding bit the dirty gate already caught this shape, but the
# status line named no path, so the operator still had to go looking.
test_visible_dirty_collision_is_named() {
  local w c1 base before
  w=$(new_world collision-visible)
  c1=$(head_of "$w/main")
  add_home "$w" sm "$c1"
  printf 'LOCAL PRIVATE BACKLOG\n' > "$w/sm/data/backlog.md"
  bump_private "$w" data/backlog.md
  base=$(primary_head_commit "$w/main")
  before=$(head_of "$w/sm")

  run_ff "$w/sm" "$base"

  [ "$FF_STATUS" = skipped ] || fail "FF_STATUS: expected skipped, got '$FF_STATUS'"
  assert_contains "$FF_OUT" "skipped: dirty working tree" \
    "the existing dirty-home wording must be preserved"
  assert_contains "$FF_OUT" "data/backlog.md" \
    "a visible dirty colliding path must be named as well"
  [ "$(head_of "$w/sm")" = "$before" ] || fail "a refused fast-forward must not move HEAD"
  assert_equals "LOCAL PRIVATE BACKLOG" "$(cat "$w/sm/data/backlog.md")" \
    "the colliding local content must survive byte-exactly"
  pass "T4 visible: a visible dirty colliding path is named and preserved"
}

# --- T5: no collision - the fast-forward still happens ---------------------
test_no_collision_still_advances() {
  local w c1 base
  w=$(new_world collision-none)
  c1=$(head_of "$w/main")
  add_home "$w" sm "$c1"
  printf 'r2\n' >> "$w/main/README.md"
  git -C "$w/main" commit -qam "bump-readme"
  base=$(primary_head_commit "$w/main")

  run_ff "$w/sm" "$base"

  [ "$FF_STATUS" = updated ] || fail "FF_STATUS: expected updated, got '$FF_STATUS' ($FF_OUT)"
  [ "$(head_of "$w/sm")" = "$base" ] || fail "a clean home must still fast-forward"
  pass "T5 no collision: a clean home still fast-forwards"
}

# --- T6: an unrelated dirty path is still reported as before ----------------
test_unrelated_dirty_is_not_a_collision() {
  local w c1 base
  w=$(new_world collision-unrelated)
  c1=$(head_of "$w/main")
  add_home "$w" sm "$c1"
  # The fast-forward would rewrite AGENTS.md; the local edit is in README.md,
  # which the fast-forward does not touch.
  printf 'v2\n' > "$w/main/AGENTS.md"
  git -C "$w/main" commit -qam "bump-agents"
  base=$(primary_head_commit "$w/main")
  printf 'local edit elsewhere\n' >> "$w/sm/README.md"

  run_ff "$w/sm" "$base"

  [ "$FF_STATUS" = skipped ] || fail "FF_STATUS: expected skipped, got '$FF_STATUS'"
  assert_contains "$FF_OUT" "skipped: dirty working tree" \
    "an unrelated dirty path keeps the existing dirty-home wording"
  assert_not_contains "$FF_OUT" "README.md" \
    "a dirty path the fast-forward would not overwrite is not a collision"
  pass "T6 unrelated: a dirty path outside the fast-forward is not reported as a collision"
}

# --- T7: a tracked symlink is never a false positive ----------------------
# CLAUDE.md is a symlink to AGENTS.md in the real repo, so a content-based
# detector must not read the link TARGET's content as a local change.
test_symlink_is_not_a_false_positive() {
  local w c1 base
  w=$(new_world collision-symlink)
  ln -s AGENTS.md "$w/main/CLAUDE.md"
  git -C "$w/main" add CLAUDE.md
  git -C "$w/main" commit -qm "add symlink"
  c1=$(head_of "$w/main")
  add_home "$w" sm "$c1"
  printf 'v2\n' > "$w/main/AGENTS.md"
  git -C "$w/main" commit -qam "bump-agents"
  base=$(primary_head_commit "$w/main")

  run_ff "$w/sm" "$base"

  [ "$FF_STATUS" = updated ] || fail "FF_STATUS: expected updated, got '$FF_STATUS' ($FF_OUT)"
  assert_not_contains "$FF_OUT" "CLAUDE.md" \
    "a tracked symlink must never be reported as a local change"
  pass "T7 symlink: a tracked symlink is never a false positive"
}

# --- T8: the documented recovery recipe works ------------------------------
# The procedure docs/architecture.md now carries ("Fast-forward collisions with
# a locally changed tracked path"), step for step: back the paths up, clear the
# index bits, check the paths out, fast-forward, restore the private content
# byte-exactly. It must advance the home AND leave the private content
# byte-identical - if the recipe in the doc were wrong, this test would fail.
test_documented_recipe_preserves_private_content() {
  local w c1 base backup p
  w=$(new_world recipe)
  c1=$(head_of "$w/main")
  add_home "$w" sm "$c1"
  hide_private_edit "$w/sm" data/backlog.md "LOCAL PRIVATE BACKLOG" --skip-worktree
  bump_private "$w" data/backlog.md
  base=$(primary_head_commit "$w/main")
  backup="$w/ff-backup.tar"
  p=data/backlog.md

  # Step 1: back the colliding path up byte-exactly.
  ( cd "$w/sm" && tar -cpf "$backup" -- "$p" )
  # Step 2: clear the index bits that hide the local change. The two bits need
  # SEPARATE invocations: `git update-index --no-skip-worktree
  # --no-assume-unchanged` in one call clears neither, because the two options
  # conflict - the path stays hidden and the checkout below refuses.
  git -C "$w/sm" update-index --no-skip-worktree -- "$p"
  git -C "$w/sm" update-index --no-assume-unchanged -- "$p"
  # Step 3: check the path out, so git will allow the fast-forward.
  git -C "$w/sm" checkout -- "$p"
  # Step 4: fast-forward.
  git -C "$w/sm" merge --ff-only "$base" >/dev/null 2>&1
  # Step 5: restore the private content byte-exactly, and prove it.
  ( cd "$w/sm" && tar -xpf "$backup" )
  tar -xOf "$backup" "$p" | cmp -s - "$w/sm/$p" \
    || fail "the restored content is not byte-identical to the backup"

  [ "$(head_of "$w/sm")" = "$base" ] || fail "the recipe must advance the home to the base"
  assert_equals "LOCAL PRIVATE BACKLOG" "$(cat "$w/sm/$p")" \
    "the recipe must restore the private content byte-exactly"
  pass "T8 recipe: the documented recovery advances the home and restores the content byte-exactly"
}

test_collision_skip_worktree_detected
test_collision_assume_unchanged_detected
test_collision_detection_is_general
test_visible_dirty_collision_is_named
test_no_collision_still_advances
test_unrelated_dirty_is_not_a_collision
test_symlink_is_not_a_false_positive
test_documented_recipe_preserves_private_content

echo "# all fm-ff-collision tests passed"
