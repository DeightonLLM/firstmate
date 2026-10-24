#!/usr/bin/env bash
# tests/fm-surface-census-fail-closed.test.sh - regression tests for the
# fail-closed lane count (F2 of the 2026-10-24 no-mistakes review).
#
# Two defects, one family:
#
#   1. bin/fm-surface-name-check.sh's task_tab_lanes returned the exit status
#      of its own WHILE LOOP instead of the status of the census read behind
#      it.  A census read that FAILED therefore looked like "this workspace
#      holds no lanes", and --apply renamed a two-lane container to a
#      "no lanes" label - a false statement about the running fleet, written
#      onto the live surface.
#   2. bin/fm-surface-census-lib.sh emitted tab rows without validating the
#      fields its consumers read (.workspace_id and .label).  A row that lost
#      one of them stopped being a TASK tab, which hid a live lane - and the
#      lane count with it.
#
# Every assertion marked "regression" FAILS against the pre-fix tree and
# PASSES against the fixed tree.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-surface-census-fail-closed)
FM_TEST_CLEANUP_DIRS+=("$TMP_ROOT")
trap fm_test_cleanup EXIT

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# The scope token comes from the hostname on a real host; pin it so every
# expected label is deterministic on any machine.
export FM_SURFACE_HOST=testhost

# shellcheck source=bin/fm-surface-census-lib.sh
. "$ROOT/bin/fm-surface-census-lib.sh"

# --- the herdr stub ----------------------------------------------------------

STUB_DIR="$TMP_ROOT/stub"
mkdir -p "$STUB_DIR"
export HERDR_STUB_DIR="$STUB_DIR"

# make_herdr_stub <dir>: a `herdr` stub whose answers are chosen by the mode
# file in $HERDR_STUB_DIR.  Every workspace rename it is asked for is
# recorded in $HERDR_STUB_DIR/renames, so a test can prove that NO rename
# happened.
make_herdr_stub() {  # <dir>
  local dir=$1 fb="$1/fakebin"
  mkdir -p "$fb"
  cat > "$fb/herdr" <<'STUB'
#!/usr/bin/env bash
set -u
DIR="${HERDR_STUB_DIR:?}"
mode=$(cat "$DIR/mode" 2>/dev/null || printf 'ok')
cmd=${1:-}; sub=${2:-}
count_tab_call() {
  local n
  n=$(cat "$DIR/tabs.calls" 2>/dev/null || printf 0)
  n=$((n + 1))
  printf '%s' "$n" > "$DIR/tabs.calls"
  printf '%s' "$n"
}
case "$cmd $sub" in
  "workspace list")
    printf '%s\n' '{"result":{"workspaces":[{"workspace_id":"w1","label":"firstmate"}]}}'
    ;;
  "tab list")
    n=$(count_tab_call)
    if [ "$mode" = "tab-list-fails-after-first" ] && [ "$n" -gt 1 ]; then
      echo "stub: tab list failed" >&2
      exit 7
    fi
    case "$mode" in
      tabs-missing-workspace)
        printf '%s\n' '{"result":{"tabs":[{"tab_id":"t1","label":"fm-lane-a"}]}}'
        ;;
      tabs-missing-label)
        printf '%s\n' '{"result":{"tabs":[{"tab_id":"t1","workspace_id":"w1"}]}}'
        ;;
      tabs-empty-label)
        printf '%s\n' '{"result":{"tabs":[{"tab_id":"t1","workspace_id":"w1","label":""}]}}'
        ;;
      tabs-mixed)
        printf '%s\n' '{"result":{"tabs":[{"tab_id":"t1","workspace_id":"w1","label":"fm-lane-a"},{"tab_id":"t2","label":"fm-lane-b"}]}}'
        ;;
      *)
        printf '%s\n' '{"result":{"tabs":[{"tab_id":"t1","workspace_id":"w1","label":"fm-lane-a"},{"tab_id":"t2","workspace_id":"w1","label":"fm-lane-b"}]}}'
        ;;
    esac
    ;;
  "pane list")
    printf '%s\n' '{"result":{"panes":[]}}'
    ;;
  "workspace rename")
    printf 'rename %s\n' "$*" >> "$DIR/renames"
    printf '%s\n' '{"result":{"ok":true}}'
    ;;
  *) : ;;
esac
exit 0
STUB
  chmod +x "$fb/herdr"
  printf '%s\n' "$fb"
}

FB=$(make_herdr_stub "$TMP_ROOT/stubroot")

# stub_mode <mode>: choose the stub's answers and clear its counters.
stub_mode() {  # <mode>
  printf '%s' "$1" > "$STUB_DIR/mode"
  : > "$STUB_DIR/tabs.calls"
  : > "$STUB_DIR/renames"
}

# --- the census validates the fields its consumers read -----------------------

stub_mode tabs-missing-workspace
out=$(PATH="$FB:$PATH" fm_surface_census_tabs default 2>&1)
rc=$?
[ "$rc" -ne 0 ] \
  || fail "regression: a tab row without its workspace must make the tab census unreadable, got rc=0: $out"
pass "fm_surface_census_tabs: a tab row without its workspace fails the census"

stub_mode tabs-missing-label
out=$(PATH="$FB:$PATH" fm_surface_census_tabs default 2>&1)
rc=$?
[ "$rc" -ne 0 ] \
  || fail "regression: a tab row without its label must make the tab census unreadable, got rc=0: $out"
pass "fm_surface_census_tabs: a tab row without its label fails the census"

stub_mode tabs-mixed
out=$(PATH="$FB:$PATH" fm_surface_census_tabs default 2>&1)
rc=$?
[ "$rc" -ne 0 ] \
  || fail "regression: one incomplete row must fail the whole census instead of hiding a task tab, got rc=0: $out"
pass "fm_surface_census_tabs: one incomplete row fails the whole census"

stub_mode tabs-empty-label
out=$(PATH="$FB:$PATH" fm_surface_census_tabs default 2>&1)
rc=$?
[ "$rc" -eq 0 ] \
  || fail "an EMPTY label is readable data and must not fail the census: $out"
pass "fm_surface_census_tabs: an empty tab label is still a readable census"

stub_mode ok
rows=$(PATH="$FB:$PATH" fm_surface_census_tabs default 2>&1)
rc=$?
[ "$rc" -eq 0 ] || fail "a healthy tab census must succeed: $rows"
count=$(printf '%s\n' "$rows" | grep -c '[^[:space:]]' || true)
[ "$count" = 2 ] || fail "a healthy tab census must emit one row per tab, got $count"
printf '%s\n' "$rows" | grep -q 'fm-lane-b' \
  || fail "a healthy tab census must carry the task tab labels: $rows"
pass "fm_surface_census_tabs: a healthy census still emits every task tab"

# --- the name check never derives a lane count from a failed read -------------

HOME_DIR="$TMP_ROOT/home"
mkdir -p "$HOME_DIR/state" "$HOME_DIR/data"

stub_mode tab-list-fails-after-first
out=$(PATH="$FB:$PATH" FM_HOME="$HOME_DIR" \
  bash "$ROOT/bin/fm-surface-name-check.sh" --session default --apply 2>&1)
rc=$?
[ "$rc" -ne 0 ] \
  || fail "regression: a check that could not read the lane census must not report success: $out"
printf '%s' "$out" | grep -q "lane count is unknown" \
  || fail "regression: a failed lane census must be reported as an unknown lane count: $out"
printf '%s' "$out" | grep -q "no lanes" \
  && fail "regression: a failed lane census must never become a 'no lanes' label: $out"
printf '%s' "$out" | grep -q "should read" \
  && fail "regression: a failed lane census must never produce a replacement label: $out"
[ ! -s "$STUB_DIR/renames" ] \
  || fail "regression: --apply must not rename a workspace on a lane count nobody read: $(cat "$STUB_DIR/renames")"
pass "fm-surface-name-check.sh: a failed lane census yields an unknown lane count, never a false zero"

# The same check with a READABLE census still computes and applies the real
# lane count: the fix must not turn every rename into an unknown.
stub_mode ok
out=$(PATH="$FB:$PATH" FM_HOME="$HOME_DIR" \
  bash "$ROOT/bin/fm-surface-name-check.sh" --session default --apply 2>&1)
rc=$?
[ "$rc" -ne 0 ] || fail "a legacy label must still be reported as a violation: $out"
printf '%s' "$out" | grep -q "2 lanes" \
  || fail "a readable lane census must still produce the real lane count: $out"
printf '%s' "$out" | grep -q "no lanes" \
  && fail "a readable lane census must never produce a 'no lanes' label: $out"
grep -q 'rename' "$STUB_DIR/renames" \
  || fail "a readable lane census must still let --apply rename the workspace"
pass "fm-surface-name-check.sh: a readable lane census still produces the live lane count"

pass "fm-surface-census-fail-closed: the lane count is never derived from a failed or incomplete read"
