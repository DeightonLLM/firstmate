#!/usr/bin/env bash
# Contract tests for the own-scratch purge path - bin/fm-scratch-lib.sh, the
# tests/lib.sh cleanup, the bin/fm-test-run.sh runner tree, and the
# bin/fm-wake-lib.sh lock churn.
#
# WHAT DEFECT THESE TESTS CATCH
#   On this host /root/.minimax/shims/rm shadows /usr/bin/rm on the agent's
#   PATH. It is a managed recoverable-delete shim: it MOVES the target into
#   ~/.local/share/Trash instead of unlinking it. The trash is on the SAME
#   filesystem, so the move frees ZERO bytes. For fleet or user MATERIAL that
#   is correct and intended. For scratch a program created itself it is a leak:
#   the secondmate-safety suite builds a ~330 MB tree per run, and the fleet's
#   lock churn added roughly 26 new trash entries per minute at idle.
#
#   These tests install a FAKE recoverable-delete shim on PATH that records
#   every "delete" as a move into a fake trash directory. The fake shim makes
#   the defect observable without touching the real trash:
#     - a plain `rm -rf` on PATH MOVES the tree and grows the fake trash
#       (this is the old behaviour, and it is asserted here so the test can
#       prove it detects the defect at all);
#     - fm_purge_scratch resolves the real rm by ABSOLUTE path, so the fake
#       shim is never consulted: the tree is really gone and the fake trash
#       does not grow.
#
#   Reverting tests/lib.sh, bin/fm-test-run.sh or bin/fm-wake-lib.sh to a
#   plain `rm -rf` makes these tests FAIL.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SCRATCH_LIB="$ROOT/bin/fm-scratch-lib.sh"
WAKE_LIB="$ROOT/bin/fm-wake-lib.sh"
TEST_RUNNER="$ROOT/bin/fm-test-run.sh"

assert_present "$SCRATCH_LIB" "bin/fm-scratch-lib.sh is missing"
assert_present "$WAKE_LIB" "bin/fm-wake-lib.sh is missing"
assert_present "$TEST_RUNNER" "bin/fm-test-run.sh is missing"

# Every scratch dir this test creates is registered through fm_test_tmproot, so
# the suite cleans up after itself. A test that leaks its own fixtures is the
# very defect this lane exists to fix.
#
# The fake recoverable-delete shim. It behaves like the real one: `rm` on PATH
# moves the target into a "trash" directory and leaves the original path gone,
# but the bytes are still there - which is the whole defect.
FAKE_TRASH=""
FAKE_BIN=""
setup_fake_shim() {
  local base
  base=$(fm_test_tmproot m31f-shim-fixture)
  FAKE_TRASH="$base/trash"
  FAKE_BIN="$base/bin"
  mkdir -p "$FAKE_TRASH" "$FAKE_BIN"
  cat > "$FAKE_BIN/rm" <<'SH'
#!/usr/bin/env bash
# A stand-in for the host's recoverable-delete shim: it MOVES the target into
# a fake trash instead of unlinking it, and records the move.
set -u
trash="${FAKE_TRASH:?}"
dest="$trash/$(basename -- "${@: -1}")"
n=1
while [ -e "$dest" ]; do
  dest="$trash/$(basename -- "${@: -1}").$n"
  n=$((n + 1))
done
printf '%s\n' "${@: -1}" >> "$trash/.moved"
if [ -d "${@: -1}" ]; then
  mv -- "${@: -1}" "$dest"
else
  mv -- "${@: -1}" "$dest"
fi
exit 0
SH
  chmod +x "$FAKE_BIN/rm"
  export FAKE_TRASH
  export PATH="$FAKE_BIN:$PATH"
}

fake_trash_count() {
  local n=0 f
  for f in "$FAKE_TRASH"/*; do
    [ -e "$f" ] || continue
    case "${f##*/}" in
      .moved) continue ;;
    esac
    n=$((n + 1))
  done
  printf '%s\n' "$n"
}

# ---------------------------------------------------------------------------
test_old_behaviour_is_detected() {
  # The test must be able to SEE the defect, or it proves nothing. With the
  # fake shim on PATH, a plain `rm -rf` moves the tree instead of unlinking
  # it: the original path is gone, but the bytes are now in the trash.
  setup_fake_shim
  local d before after
  d=$(fm_test_tmproot m31f-old-behaviour)
  mkdir -p "$d/inner"
  echo payload > "$d/inner/file"
  before=$(fake_trash_count)
  rm -rf "$d"
  after=$(fake_trash_count)
  [ ! -e "$d" ] || fail "the fake shim did not remove the original path"
  [ "$after" -gt "$before" ] \
    || fail "the fake shim did not relocate the tree into the fake trash; this test cannot detect the defect"
  pass "a plain rm -rf on PATH relocates scratch into the trash (old behaviour detected)"
}

test_purge_helper_really_unlinks() {
  setup_fake_shim
  local d before after
  d=$(fm_test_tmproot m31f-purge-helper)
  mkdir -p "$d/inner"
  echo payload > "$d/inner/file"
  before=$(fake_trash_count)
  # shellcheck source=bin/fm-scratch-lib.sh
  . "$SCRATCH_LIB"
  fm_purge_scratch "$d" >/dev/null 2>&1
  after=$(fake_trash_count)
  [ ! -e "$d" ] || fail "fm_purge_scratch did not remove the scratch tree"
  [ "$after" -eq "$before" ] \
    || fail "fm_purge_scratch routed the delete through the recoverable-delete shim; the tree was relocated, not unlinked"
  pass "fm_purge_scratch unlinks scratch for real and never consults the shim"
}

test_purge_helper_refuses_material() {
  # The helper must not become a general-purpose delete. Everything under a
  # system temp root is scratch by convention, so the material cases are the
  # ones OUTSIDE a temp root: a tracked repo file, a protected surface, a
  # relative path, and a path with a .. component.
  setup_fake_shim
  # shellcheck source=bin/fm-scratch-lib.sh
  . "$SCRATCH_LIB"
  local tracked="$ROOT/README.md"
  assert_present "$tracked" "README.md is missing; cannot test the material refusal"
  fm_purge_scratch "$tracked" >/dev/null 2>&1 && \
    fail "fm_purge_scratch accepted a tracked repo file"
  assert_present "$tracked" "fm_purge_scratch deleted a tracked repo file"
  # A protected surface is refused outright.
  fm_purge_scratch "/root/backups/anything" >/dev/null 2>&1 && \
    fail "fm_purge_scratch accepted a protected surface"
  # A relative path and a path with a .. component are refused.
  fm_purge_scratch "relative/path" >/dev/null 2>&1 && \
    fail "fm_purge_scratch accepted a relative path"
  fm_purge_scratch "$ROOT/tests/../README.md" >/dev/null 2>&1 && \
    fail "fm_purge_scratch accepted a path with a .. component"
  assert_present "$tracked" "fm_purge_scratch deleted a refused path"
  pass "fm_purge_scratch refuses material, protected, relative and .. paths"
}

test_purge_helper_never_uses_path_lookup() {
  # The real rm must be resolved by ABSOLUTE path. If the helper ever used a
  # PATH lookup, the host's shim would silently take over again.
  local body
  body=$(cat "$SCRATCH_LIB")
  case "$body" in
    *"command -v rm"*|*"which rm"*) fail "the helper resolves rm through PATH lookup" ;;
  esac
  case "$body" in
    *"/usr/bin/rm"*) : ;;
    *) fail "the helper does not reference an absolute /usr/bin/rm" ;;
  esac
  pass "the helper resolves the real rm by absolute path, never by PATH lookup"
}

# ---------------------------------------------------------------------------
# The repo's own cleanup. This is the ~330 MB per run leak: the secondmate
# safety suite clones the firstmate repo twice into one temp root.
test_test_lib_cleanup_unlinks_for_real() {
  setup_fake_shim
  local d before after
  # tests/lib.sh is already sourced above, so fm_test_tmproot and
  # fm_test_cleanup are the real ones.
  d=$(fm_test_tmproot m31f-cleanup-probe)
  mkdir -p "$d/inner"
  echo payload > "$d/inner/file"
  before=$(fake_trash_count)
  fm_test_cleanup
  after=$(fake_trash_count)
  [ ! -e "$d" ] || fail "tests/lib.sh cleanup left the temp root in place"
  [ "$after" -eq "$before" ] \
    || fail "tests/lib.sh cleanup relocated the temp root into the trash instead of unlinking it"
  pass "tests/lib.sh cleanup unlinks the registered temp root for real"
}

test_test_lib_cleanup_covers_the_registry_file() {
  setup_fake_shim
  local d before after
  d=$(fm_test_tmproot m31f-registry-probe)
  mkdir -p "$d/inner"
  echo payload > "$d/inner/file"
  before=$(fake_trash_count)
  fm_test_cleanup
  after=$(fake_trash_count)
  [ ! -e "$d" ] || fail "tests/lib.sh cleanup left a registry-registered temp root in place"
  [ "$after" -eq "$before" ] \
    || fail "tests/lib.sh cleanup relocated a registry-registered temp root into the trash"
  pass "tests/lib.sh cleanup unlinks registry-registered temp roots for real"
}

test_test_lib_cleanup_covers_the_registered_array() {
  # The registered-array branch of fm_test_cleanup is a second, independent
  # path: a partial revert of only that branch must still be caught.
  setup_fake_shim
  local d before after
  d=$(fm_test_tmproot m31f-array-probe)
  mkdir -p "$d/inner"
  echo payload > "$d/inner/file"
  FM_TEST_CLEANUP_DIRS+=("$d")
  before=$(fake_trash_count)
  fm_test_cleanup
  after=$(fake_trash_count)
  [ ! -e "$d" ] || fail "tests/lib.sh cleanup left an array-registered temp root in place"
  [ "$after" -eq "$before" ] \
    || fail "tests/lib.sh cleanup relocated an array-registered temp root into the trash"
  pass "tests/lib.sh cleanup unlinks array-registered temp roots for real"
}

# ---------------------------------------------------------------------------
# The runner's own tree: RUN_TMP and the coverage guard's temp dir.
test_test_runner_run_tmp_is_unlinked() {
  setup_fake_shim
  local before after
  before=$(fake_trash_count)
  # --check-coverage creates and removes its own temp tree and exits.
  "$TEST_RUNNER" --check-coverage >/dev/null 2>&1
  after=$(fake_trash_count)
  [ "$after" -eq "$before" ] \
    || fail "bin/fm-test-run.sh relocated its own scratch into the trash"
  pass "bin/fm-test-run.sh unlinks its own scratch tree for real"
}

test_test_runner_leaves_no_run_tmp_behind() {
  # The runner's RUN_TMP must not survive the run. A nested RUN_TMP is also
  # invisible to the capacity guard's flat /tmp glob, so a leftover RUN_TMP
  # holds a whole suite's scratch.
  local out
  out=$("$TEST_RUNNER" --check-coverage 2>&1)
  case "$out" in
    *fm-test-run.*) fail "bin/fm-test-run.sh left a RUN_TMP path visible in its output: $out" ;;
  esac
  pass "bin/fm-test-run.sh leaves no RUN_TMP behind"
}

# ---------------------------------------------------------------------------
# The lock churn. This is the flood source: the fleet's own high-frequency
# lock and claim churn was creating thousands of pid.NNNN and *.lock.owner.*
# trash entries per hour. Every lock owner dir and lock pointer is scratch the
# lock library created itself moments earlier.
test_lock_churn_does_not_leak_into_the_trash() {
  setup_fake_shim
  local home state lockdir before after i
  home=$(fm_test_tmproot m31f-lock-home)
  state="$home/state"
  mkdir -p "$state"
  lockdir="$state/.watch.lock"
  before=$(fake_trash_count)
  # Acquire and release repeatedly, the way the fleet's watchers do. The
  # library runs in a subshell on purpose: the lock it takes is released again
  # inside that subshell, which is exactly the churn being measured.
  # shellcheck disable=SC2031
  for i in 1 2 3 4 5 6 7 8 9 10; do
    (
      # shellcheck source=bin/fm-wake-lib.sh
      . "$WAKE_LIB"
      fm_lock_try_acquire "$lockdir" >/dev/null 2>&1
      fm_lock_release "$lockdir" >/dev/null 2>&1
    ) >/dev/null 2>&1
  done
  after=$(fake_trash_count)
  [ "$after" -eq "$before" ] \
    || fail "the lock machinery relocated lock scratch into the trash ($before -> $after entries)"
  # shellcheck disable=SC2031 # the lock library runs in a subshell on purpose
  [ ! -e "$lockdir" ] && [ ! -L "$lockdir" ] \
    || fail "the lock machinery left its lock pointer behind"
  pass "the lock machinery unlinks its own lock scratch instead of trashing it"
}

test_lock_release_leaves_no_owner_dir() {
  setup_fake_shim
  local home state lockdir i before after
  home=$(fm_test_tmproot m31f-lock-owner)
  state="$home/state"
  mkdir -p "$state"
  lockdir="$state/.watch.lock"
  before=$(fake_trash_count)
  for i in 1 2 3 4 5; do
    (
      # shellcheck source=bin/fm-wake-lib.sh
      . "$WAKE_LIB"
      fm_lock_try_acquire "$lockdir" >/dev/null 2>&1
      fm_lock_release "$lockdir" >/dev/null 2>&1
    ) >/dev/null 2>&1
  done
  after=$(fake_trash_count)
  # No owner dir may survive either.
  local leftover
  # shellcheck disable=SC2031
  leftover=$(find "$state" -maxdepth 1 -name '.watch.lock.owner.*' 2>/dev/null | wc -l | tr -d ' ')
  [ "$leftover" -eq 0 ] || fail "the lock machinery left $leftover owner dirs behind"
  [ "$after" -eq "$before" ] \
    || fail "the lock machinery relocated lock owner scratch into the trash"
  pass "the lock machinery leaves no owner dir and no trash entry behind"
}

# ---------------------------------------------------------------------------
# The declared-root shape rules. These decide whether a scratch entry a
# program made INSIDE a root it declared with --root is really purged.
#
# These rules were rewritten during postflight. The earlier rule demanded that
# the mktemp suffix hold a digit, and mktemp's suffix is random alnum, so
# about one run in three left its scratch behind: a repo-root fixture such as
# .fm-lint-parity.ESyxyF survived its own cleanup. The rule now uses mktemp's
# real guarantee - an owner-private mode - and adds a git-tracked refusal, so
# the repo's own .agents, .claude, .github and .lavish stay untouchable.
test_declared_root_shapes() {
  setup_fake_shim
  local probe shared fixture before after
  probe="$ROOT/.m31f-scratch-purge-probe.$$.ESyxyF"
  shared="$ROOT/.m31f-scratch-purge-shared.$$.agents"

  # 1. A mktemp suffix with NO digit is scratch and must be purged.
  mkdir -p "$probe"
  chmod 0700 "$probe"
  before=$(fake_trash_count)
  fm_purge_scratch --root "$ROOT" "$probe" >/dev/null 2>&1
  after=$(fake_trash_count)
  [ ! -e "$probe" ] || {
    /usr/bin/rm -rf "$probe"
    fail "the helper refused a mktemp-shaped scratch entry whose suffix holds no digit"
  }
  [ "$after" -eq "$before" ] || {
    /usr/bin/rm -rf "$probe"
    fail "the helper relocated a declared-root scratch entry into the trash"
  }
  pass "a declared-root mktemp entry is purged even when its suffix holds no digit"

  # 2. A directory that merely LOOKS like a mktemp entry but is not
  #    owner-private is refused. This is the guard that protects .agents,
  #    .claude, .github and .lavish at the repo root.
  mkdir -p "$shared"
  chmod 0755 "$shared"
  if fm_purge_scratch --root "$ROOT" "$shared" >/dev/null 2>&1; then
    /usr/bin/rm -rf "$shared"
    fail "the helper accepted a shared-permission directory at the repo root"
  fi
  [ -d "$shared" ] || {
    /usr/bin/rm -rf "$shared"
    fail "the helper deleted a shared-permission directory at the repo root"
  }
  /usr/bin/rm -rf "$shared"
  pass "a shared-permission directory at the repo root is refused, not deleted"

  # 3. Tracked material is never scratch, whatever it is named. The fixture is
  #    a nested work tree under a gitignored path, so the outer repo's status
  #    stays clean and the fixture cannot be confused with repo content.
  fixture="$ROOT/data/m3.1f-firstmate-scratchfix/gitfixture"
  mkdir -p "$fixture"
  git init -q "$fixture" >/dev/null 2>&1
  printf 'material\n' > "$fixture/tracked.claim"
  ( cd "$fixture" && git add tracked.claim ) >/dev/null 2>&1
  if fm_purge_scratch --root "$fixture" "$fixture/tracked.claim" >/dev/null 2>&1; then
    /usr/bin/rm -rf "$fixture"
    fail "the helper accepted a git-tracked file inside a declared root"
  fi
  [ -f "$fixture/tracked.claim" ] || {
    /usr/bin/rm -rf "$fixture"
    fail "the helper deleted a git-tracked file inside a declared root"
  }
  # An untracked entry of the very same shape in the very same root IS scratch.
  printf 'scratch\n' > "$fixture/untracked.claim"
  fm_purge_scratch --root "$fixture" "$fixture/untracked.claim" >/dev/null 2>&1
  [ ! -e "$fixture/untracked.claim" ] || {
    /usr/bin/rm -rf "$fixture"
    fail "the helper refused an untracked scratch entry inside a declared root"
  }
  /usr/bin/rm -rf "$fixture"
  pass "tracked material is refused inside a declared root while untracked scratch is purged"
}

# ---------------------------------------------------------------------------
# Static guards: the converted call sites must not silently regress to a plain
# `rm` on PATH.
test_converted_sites_use_the_purge_helper() {
  # Comment lines are excluded: a comment may legitimately mention `rm -rf`.
  # The fallback definition of fm_purge_scratch itself is excluded too: it is
  # deliberately the pre-fix behaviour, for a partial checkout that does not
  # carry the library.
  local f bad
  for f in "$ROOT/tests/lib.sh" "$ROOT/bin/fm-test-run.sh" "$ROOT/bin/fm-wake-lib.sh" \
           "$ROOT/bin/fm-procevent-lib.sh" "$ROOT/bin/fm-secondmate-registry-lib.sh" \
           "$ROOT/bin/fm-lint.sh" "$ROOT/bin/lane-todo-board.test.sh" \
           "$ROOT/tests/fm-secondmate-safety.test.sh"; do
    [ -f "$f" ] || fail "$f is missing"
    bad=$(awk '
      /fm_purge_scratch\(\) *\{/ { infb=1; next }
      infb { if ($0 ~ /^ *\}/) infb=0; next }
      /^[[:space:]]*#/ { next }
      {
        if ($0 ~ /(^|[^-_[:alnum:]])rm[[:space:]]+-[rf]/)
          printf "%s:%d: %s\n", FILENAME, NR, $0
      }
    ' "$f")
    [ -z "$bad" ] || fail "a converted call site still deletes with a plain rm: $bad"
  done
  pass "the converted call sites no longer delete with a plain rm"
}

test_purge_helper_is_sourced_where_it_is_used() {
  local f
  for f in "$ROOT/tests/lib.sh" "$ROOT/bin/fm-test-run.sh" "$ROOT/bin/fm-wake-lib.sh"; do
    grep -q 'fm-scratch-lib.sh' "$f" \
      || fail "$f uses fm_purge_scratch but never sources bin/fm-scratch-lib.sh"
  done
  pass "every converted file sources bin/fm-scratch-lib.sh"
}

test_partial_checkout_still_works() {
  # Several repo tests copy bin/fm-wake-lib.sh, bin/fm-secondmate-registry-lib.sh
  # or bin/fm-test-run.sh into a PARTIAL fixture repo that does not carry
  # bin/fm-scratch-lib.sh. A hard dependency made those fixtures fail, so the
  # dependency must be soft: the file still has to work, and it must fall back
  # to the pre-fix behaviour rather than to a failure.
  local d out
  d=$(fm_test_tmproot m31f-partial)
  mkdir -p "$d/bin" "$d/tests"
  cp "$ROOT/bin/fm-test-run.sh" "$d/bin/fm-test-run.sh"
  chmod +x "$d/bin/fm-test-run.sh"
  cp "$ROOT/bin/fm-wake-lib.sh" "$d/bin/fm-wake-lib.sh"
  cp "$ROOT/bin/fm-secondmate-registry-lib.sh" "$d/bin/fm-secondmate-registry-lib.sh"
  cp "$ROOT/tests/lib.sh" "$d/tests/lib.sh"
  printf '#!/usr/bin/env bash\n# sample\n' >"$d/tests/fm-sample.test.sh"
  chmod +x "$d/tests/fm-sample.test.sh"
  # The runner must still be able to list its inventory without the library.
  out=$("$d/bin/fm-test-run.sh" --list --all 2>&1); rc=$?
  case "$out" in
    *"required library not readable"*)
      fail "a partial checkout without bin/fm-scratch-lib.sh makes the runner fail" ;;
  esac
  [ "$rc" -eq 0 ] || fail "the runner exited $rc in a partial checkout: $out"
  case "$out" in
    *tests/fm-sample.test.sh*) : ;;
    *) fail "the runner produced no inventory in a partial checkout: $out" ;;
  esac
  # The lock library must still source cleanly in a partial checkout.
  ( set -u; . "$d/bin/fm-wake-lib.sh" ) >/dev/null 2>&1 \
    || fail "bin/fm-wake-lib.sh does not source in a partial checkout"
  ( set -u; . "$d/bin/fm-secondmate-registry-lib.sh" ) >/dev/null 2>&1 \
    || fail "bin/fm-secondmate-registry-lib.sh does not source in a partial checkout"
  ( set -u; . "$d/tests/lib.sh" ) >/dev/null 2>&1 \
    || fail "tests/lib.sh does not source in a partial checkout"
  # And the fallback must still purge, so a partial checkout is not a leak.
  mkdir -p "$d/scratch"
  ( set -u; . "$d/tests/lib.sh"; fm_purge_scratch "$d/scratch" ) >/dev/null 2>&1
  [ ! -e "$d/scratch" ] || fail "the partial-checkout fallback did not purge the scratch path"
  /usr/bin/rm -rf "$d"
  pass "a partial checkout without the library still works and still purges"
}

test_declared_scratch_roots_are_in_scope() {
  # A `--root "$VAR"` whose VAR is not in scope in the enclosing function is a
  # latent `set -u` crash: the shell aborts the moment that path is taken.
  # This exact bug was introduced once during this lane (a claim release used
  # a root variable that only existed in a different function), so the guard
  # is permanent.
  local f bad
  for f in "$ROOT/bin/fm-procevent-lib.sh" "$ROOT/bin/fm-secondmate-registry-lib.sh" \
           "$ROOT/bin/fm-wake-lib.sh" "$ROOT/tests/lib.sh"; do
    bad=$(awk '
      /^[a-zA-Z_][a-zA-Z0-9_]*\(\) *\{/ {
        fn=$1; sub(/\(.*/,"",fn); loc=""; next
      }
      fn && /^[ \t]*(local|declare)[ \t]/ {
        line=$0
        gsub(/^[ \t]*(local|declare)[ \t]+/,"",line)
        n=split(line, a, /[ \t,]+/)
        for (i=1;i<=n;i++) if (a[i] != "") loc=loc" "a[i]
        next
      }
      {
        if (match($0, /--root "\$([A-Za-z_][A-Za-z0-9_]*)"/, m)) {
          v=m[1]
          if (v == "ROOT") next
          if (index(" "loc" ", " "v" ") > 0) next
          printf "%s:%d %s uses %s which is not declared in that function\n", FILENAME, NR, fn, v
        }
      }
    ' "$f")
    [ -z "$bad" ] || fail "scratch root variable out of scope: $bad"
  done
  pass "every --root variable is in scope in its enclosing function"
}

test_old_behaviour_is_detected
test_purge_helper_really_unlinks
test_purge_helper_refuses_material
test_purge_helper_never_uses_path_lookup
test_test_lib_cleanup_unlinks_for_real
test_test_lib_cleanup_covers_the_registry_file
test_test_lib_cleanup_covers_the_registered_array
test_test_runner_run_tmp_is_unlinked
test_test_runner_leaves_no_run_tmp_behind
test_lock_churn_does_not_leak_into_the_trash
test_lock_release_leaves_no_owner_dir
test_declared_root_shapes
test_converted_sites_use_the_purge_helper
test_purge_helper_is_sourced_where_it_is_used
test_partial_checkout_still_works
test_declared_scratch_roots_are_in_scope
