#!/usr/bin/env bash
# tests/fm-surface-lane-summary-e2e.test.sh - isolated real-herdr regression
# test for the two halves of the live lane summary (six-findings R36 + R37).
#
# R36: fm_backend_herdr_create_task leaked the tab and pane it created.
#      `tab create` is the moment ownership of a live herdr endpoint starts,
#      and every step after it can fail.  A failure that returned WITHOUT
#      removing the tab left a LIVE pane with NO owner: bin/fm-spawn.sh exits
#      before it writes the task meta, so the scheduler's rollback saw no
#      meta and cleaned nothing.  This test drives ONE real post-create
#      failure (the workspace rename) and asserts that no pane survives it.
#
# R37: the lane summary was a SNAPSHOT.  The create path wrote
#      "scope + N lanes" and the shared close path never recomputed it, so
#      closing one of two lanes left a syntactically valid but FALSE
#      "scope + 2 lanes" on the running surface.  The summary is a LIVE
#      COUNT maintained by BOTH the create and the close path.
#
# Safety (tests/herdr-test-safety.sh): this suite runs against its own
# private, throwaway HERDR_SESSION - never the captain's default - and
# cleanup uses ONLY herdr_safe_stop_and_delete, never a bare/inline-prefixed
# `herdr server stop`.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CLEANED=0
fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

command -v herdr >/dev/null 2>&1 || { echo "skip: herdr not found"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "skip: jq not found (required by the herdr adapter)"; exit 0; }

# shellcheck source=tests/herdr-test-safety.sh
. "$ROOT/tests/herdr-test-safety.sh"

# This suite runs against its own isolated lab session, so a Herdr pane
# inherited from the terminal it was launched in must not follow spawn into
# it as a cross-session parent identity (tests/herdr-test-safety.sh).
herdr_forget_inherited_pane

SESSION="fm-lab-lane-summary-e2e-$$"
export HERDR_SESSION="$SESSION"
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/fm-herdr-lane-summary.XXXXXX")
cleanup_all() {
  [ "$CLEANED" = 1 ] && return 0
  CLEANED=1
  herdr_safe_stop_and_delete "$SESSION"
  rm -rf "$SCRATCH"
}
trap cleanup_all EXIT
fm_herdr_lab_prepare "$SESSION" || fail "could not prepare isolated Herdr lab session"

# A private home, so the lab container's scope is the lab's own and can never
# be confused with a container of the captain's real home.
LAB_HOME="$SCRATCH/home"
mkdir -p "$LAB_HOME/state" "$LAB_HOME/data" "$LAB_HOME/projects"
export FM_HOME="$LAB_HOME"
export FM_SURFACE_HOST=lab

# shellcheck source=/dev/null
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr || fail "fm_backend_source herdr failed"
fm_backend_herdr_version_check || fail "version_check failed against the real installed herdr"
fm_backend_herdr_server_ensure "$SESSION" || fail "could not start the isolated session's server"

SCOPE=$(fm_backend_herdr_workspace_label)
[ -n "$SCOPE" ] || fail "the lab scope could not be resolved"

# --- helpers ----------------------------------------------------------------

LAB_WSID=""
lab_workspace() {
  local out
  out=$(fm_backend_herdr_cli "$SESSION" workspace create --cwd "$SCRATCH" --label "$SCOPE" --no-focus 2>/dev/null) \
    || fail "could not create the lab workspace"
  LAB_WSID=$(printf '%s' "$out" | jq -r '.result.workspace.workspace_id // empty')
  [ -n "$LAB_WSID" ] || fail "could not parse the lab workspace id"
}

# lab_tabs: the tab labels the lab workspace holds, one per line.
lab_tabs() {
  fm_backend_herdr_cli "$SESSION" tab list --workspace "$LAB_WSID" 2>/dev/null \
    | jq -r '.result.tabs[]? | .label' 2>/dev/null
}

# lab_lane_count: how many TASK tabs (fm-<lane>) the lab workspace holds.
# This is the "active lane" count the surface shows.
lab_lane_count() {
  fm_backend_herdr_cli "$SESSION" tab list --workspace "$LAB_WSID" 2>/dev/null \
    | jq -r '[.result.tabs[]? | select((.label // "") | startswith("fm-"))] | length' 2>/dev/null
}

lab_label() {
  fm_backend_herdr_cli "$SESSION" workspace get "$LAB_WSID" 2>/dev/null \
    | jq -r '.result.workspace.label // empty' 2>/dev/null
}

# lab_pane_count: how many panes the lab workspace holds.  A leaked create
# shows up here as a pane with no owner.
lab_pane_count() {
  fm_backend_herdr_cli "$SESSION" pane list --workspace "$LAB_WSID" 2>/dev/null \
    | jq -r '[.result.panes[]?] | length' 2>/dev/null
}

# lab_pane_for_label: the pane id of the tab carrying <label>.
lab_pane_for_label() {
  local label=$1 tab_id
  tab_id=$(fm_backend_herdr_cli "$SESSION" tab list --workspace "$LAB_WSID" 2>/dev/null \
    | jq -r --arg want "$label" '.result.tabs[]? | select((.label // "") == $want) | .tab_id' 2>/dev/null | head -1)
  [ -n "$tab_id" ] || return 1
  fm_backend_herdr_cli "$SESSION" pane list --workspace "$LAB_WSID" 2>/dev/null \
    | jq -r --arg tab "$tab_id" '.result.panes[]? | select(.tab_id == $tab) | .pane_id' 2>/dev/null | head -1
}

# === R36: a failed post-create step must not leak the tab it created ========

lab_workspace

# A herdr shim that forwards EVERY command to the real herdr except
# `workspace rename`, which it fails.  That drives the exact post-create
# failure this branch added: the create succeeds, the rename fails, and the
# create path must return a failure WITHOUT leaving the created tab behind.
SHIM_BIN="$SCRATCH/shim"
mkdir -p "$SHIM_BIN"
REAL_HERDR=$(command -v herdr)
cat > "$SHIM_BIN/herdr" <<SHIM
#!/usr/bin/env bash
for arg in "\$@"; do
  if [ "\$arg" = "rename" ]; then
    echo "shim: refusing every workspace rename" >&2
    exit 7
  fi
done
exec "$REAL_HERDR" "\$@"
SHIM
chmod +x "$SHIM_BIN/herdr"

before_tabs=$(lab_tabs | grep -c . || true)
before_panes=$(lab_pane_count)

FAILED_OUT=$(PATH="$SHIM_BIN:$PATH" fm_backend_herdr_create_task "$SESSION:$LAB_WSID" fm-r36-leak-probe "$SCRATCH" 2>&1)
FAILED_STATUS=$?
[ "$FAILED_STATUS" -ne 0 ] || fail "the create path must FAIL when the workspace rename fails (status $FAILED_STATUS)"

after_tabs=$(lab_tabs | grep -c . || true)
after_panes=$(lab_pane_count)
after_lanes=$(lab_lane_count)

printf 'R36 failed-create probe: status=%s tabs %s->%s panes %s->%s lanes=%s\n' \
  "$FAILED_STATUS" "$before_tabs" "$after_tabs" "$before_panes" "$after_panes" "$after_lanes"
printf 'R36 failed-create probe output: %s\n' "$(printf '%s' "$FAILED_OUT" | tr '\n' ' ')"

if printf '%s\n' "$after_tabs" >/dev/null && lab_tabs | grep -qx 'fm-r36-leak-probe'; then
  fail "the failed create left its tab behind: $(lab_tabs | tr '\n' ' ')"
fi
[ "$after_panes" = "$before_panes" ] \
  || fail "the failed create leaked a pane: panes went $before_panes -> $after_panes"
[ "$after_lanes" = "0" ] \
  || fail "the failed create left a lane behind: lane count is $after_lanes"
pass "R36: a failed post-create step removes the tab and pane it created (no orphan endpoint)"

# === R36: the successful create still creates exactly one lane ===============

OK_OUT=$(fm_backend_herdr_create_task "$SESSION:$LAB_WSID" fm-r36-happy "$SCRATCH")
OK_STATUS=$?
[ "$OK_STATUS" -eq 0 ] || fail "the happy-path create failed: $OK_OUT"
[ -n "$OK_OUT" ] || fail "the happy-path create returned no tab/pane ids"
happy_lanes=$(lab_lane_count)
[ "$happy_lanes" = "1" ] || fail "the happy-path create should leave exactly one lane, got $happy_lanes"
printf 'R36 happy create: ids=[%s] lanes=%s label=[%s]\n' "$OK_OUT" "$happy_lanes" "$(lab_label)"
pass "R36: a successful create leaves exactly one live lane"

# Close the probe lane again, so the R37 section starts from a clean
# container, and so the close path is exercised on the way.
HAPPY_PANE=$(lab_pane_for_label fm-r36-happy || true)
[ -n "$HAPPY_PANE" ] || fail "could not read the happy lane's pane"
fm_backend_herdr_kill "$SESSION:$HAPPY_PANE" || true
[ "$(lab_lane_count)" = "0" ] || fail "the probe lane did not close"

# === R37: the summary is a LIVE count, kept by the create AND the close path

# Two lanes in the container.
fm_backend_herdr_create_task "$SESSION:$LAB_WSID" fm-r37-lane-a "$SCRATCH" >/dev/null || fail "could not create lane a"
fm_backend_herdr_create_task "$SESSION:$LAB_WSID" fm-r37-lane-b "$SCRATCH" >/dev/null || fail "could not create lane b"
two_lanes=$(lab_lane_count)
[ "$two_lanes" = "2" ] || fail "expected two lanes, got $two_lanes"
two_label=$(lab_label)
[ "$two_label" = "$SCOPE · 2 lanes" ] \
  || fail "two lanes should read '$SCOPE · 2 lanes', got '$two_label'"
printf 'R37 two lanes: lanes=%s label=[%s]\n' "$two_lanes" "$two_label"
pass "R37: two lanes read '$SCOPE · 2 lanes'"

# Close ONE lane through the shared close path.  The container must now say
# ONE lane, not two.
PANE_A=$(lab_pane_for_label fm-r37-lane-a || true)
[ -n "$PANE_A" ] || fail "could not read lane a's pane"
fm_backend_herdr_kill "$SESSION:$PANE_A" || true
one_lanes=$(lab_lane_count)
one_label=$(lab_label)
printf 'R37 after closing one lane: lanes=%s label=[%s]\n' "$one_lanes" "$one_label"
[ "$one_lanes" = "1" ] || fail "after closing one of two lanes one lane should remain, got $one_lanes"
# The summary names the LANE (the task tab label "fm-<lane-id>" without its
# "fm-" prefix), exactly as the create path writes it.
[ "$one_label" = "$SCOPE · r37-lane-b" ] \
  || fail "after closing one of two lanes the container should read '$SCOPE · r37-lane-b', got '$one_label'"
pass "R37: closing one of two lanes relabels the container to '$one_label'"

# Close the LAST lane: the container returns to the authorised scope-only
# no-lanes form.
PANE_B=$(lab_pane_for_label fm-r37-lane-b || true)
[ -n "$PANE_B" ] || fail "could not read lane b's pane"
fm_backend_herdr_kill "$SESSION:$PANE_B" || true
zero_lanes=$(lab_lane_count)
zero_label=$(lab_label)
printf 'R37 after closing the last lane: lanes=%s label=[%s]\n' "$zero_lanes" "$zero_label"
[ "$zero_lanes" = "0" ] || fail "expected zero lanes after the last close, got $zero_lanes"
[ "$zero_label" = "$SCOPE" ] \
  || fail "after the last lane closes the container should read the scope-only form '$SCOPE', got '$zero_label'"
pass "R37: closing the last lane restores the scope-only form '$zero_label'"

printf 'fm-surface-lane-summary-e2e.test.sh: all assertions passed\n'
