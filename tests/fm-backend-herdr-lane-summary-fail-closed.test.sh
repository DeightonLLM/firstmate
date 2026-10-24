#!/usr/bin/env bash
# tests/fm-backend-herdr-lane-summary-fail-closed.test.sh - regression tests
# for the fail-closed lane summary of the herdr adapter (F3 of the 2026-10-24
# no-mistakes review).
#
# The lane summary of a container ("scope + N lanes") is a LIVE count.  The
# relabel helper read three things - the owner list, the current label and
# the lane count - and turned every failed read into an empty string, so the
# helper reported SUCCESS while refreshing nothing.  The close path then
# swallowed that result, and a container whose lane had just gone kept a
# stale "scope + 2 lanes" label: a false statement about the running fleet
# that the naming check cannot catch, because a stale label is syntactically
# valid.
#
# Every assertion marked "regression" FAILS against the pre-fix tree and
# PASSES against the fixed tree.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

command -v jq >/dev/null 2>&1 || { echo "skip: jq not found (required by the herdr adapter)"; exit 0; }

TMP_ROOT=$(fm_test_tmproot fm-backend-herdr-lane-summary)
FM_TEST_CLEANUP_DIRS+=("$TMP_ROOT")
trap fm_test_cleanup EXIT

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# The visible surface-name grammar resolves the host token from the hostname.
# Pin it here so every expected scope is deterministic on any machine.
export FM_SURFACE_HOST=testhost

# --- the herdr stub ----------------------------------------------------------

STUB_DIR="$TMP_ROOT/stub"
mkdir -p "$STUB_DIR"
export HERDR_STUB_DIR="$STUB_DIR"

# make_herdr_stub <dir>: a `herdr` stub whose answers are chosen by the mode
# file in $HERDR_STUB_DIR.  Every workspace rename it is asked for is
# recorded in $HERDR_STUB_DIR/renames.
make_herdr_stub() {  # <dir>
  local dir=$1 fb="$1/fakebin"
  mkdir -p "$fb"
  cat > "$fb/herdr" <<'STUB'
#!/usr/bin/env bash
set -u
DIR="${HERDR_STUB_DIR:?}"
mode=$(cat "$DIR/mode" 2>/dev/null || printf 'ok')
cmd=${1:-}; sub=${2:-}
case "$cmd $sub" in
  "workspace list")
    if [ "$mode" = "workspace-list-fails" ]; then
      echo "stub: workspace list failed" >&2
      exit 7
    fi
    printf '%s\n' '{"result":{"workspaces":[{"workspace_id":"w1","label":"testhost/primary"}]}}'
    ;;
  "workspace get")
    if [ "$mode" = "workspace-get-fails" ]; then
      echo "stub: workspace get failed" >&2
      exit 7
    fi
    if [ "$mode" = "label-already-correct" ]; then
      printf '%s\n' '{"result":{"workspace":{"workspace_id":"w1","label":"testhost/primary · 2 lanes"}}}'
      exit 0
    fi
    printf '%s\n' '{"result":{"workspace":{"workspace_id":"w1","label":"testhost/primary"}}}'
    ;;
  "tab list")
    if [ "$mode" = "tab-list-fails" ]; then
      echo "stub: tab list failed" >&2
      exit 7
    fi
    printf '%s\n' '{"result":{"tabs":[{"tab_id":"t1","workspace_id":"w1","label":"fm-lane-a"},{"tab_id":"t2","workspace_id":"w1","label":"fm-lane-b"}]}}'
    ;;
  "pane get")
    if [ -f "$DIR/pane-closed" ]; then
      printf '%s\n' '{"error":{"code":"pane_not_found","message":"no such pane"}}'
      exit 0
    fi
    printf '%s\n' '{"result":{"pane":{"pane_id":"w1:p1","tab_id":"w1:t1","workspace_id":"w1"}}}'
    ;;
  "pane close")
    : > "$DIR/pane-closed"
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
  rm -f "$STUB_DIR/pane-closed"
  : > "$STUB_DIR/renames"
}

HOME_DIR="$TMP_ROOT/home"
mkdir -p "$HOME_DIR/state" "$HOME_DIR/data"

# relabel <mode> -> prints "<status>|<stderr>"; runs the relabel helper with
# the stub in place.
relabel() {  # <mode>
  local mode=$1 out rc
  stub_mode "$mode"
  out=$(PATH="$FB:$PATH" FM_HOME="$HOME_DIR" bash -c '
    . "$0/bin/backends/herdr.sh"
    fm_backend_herdr_workspace_relabel_lanes default w1
  ' "$ROOT" 2>&1)
  rc=$?
  printf '%s|%s' "$rc" "$out"
}

# --- a failed read is never a successful relabel ------------------------------

result=$(relabel workspace-list-fails)
rc=${result%%|*}
out=${result#*|}
[ "$rc" -ne 0 ] \
  || fail "regression: a failed owner read must not be reported as a successful relabel: $out"
printf '%s' "$out" | grep -q "lane summary" \
  || fail "regression: a failed owner read must be reported: $out"
[ ! -s "$STUB_DIR/renames" ] \
  || fail "regression: a failed owner read must not rename anything: $(cat "$STUB_DIR/renames")"
pass "fm_backend_herdr_workspace_relabel_lanes: a failed owner read is a failure"

result=$(relabel workspace-get-fails)
rc=${result%%|*}
out=${result#*|}
[ "$rc" -ne 0 ] \
  || fail "regression: a failed label read must not be reported as a successful relabel: $out"
[ ! -s "$STUB_DIR/renames" ] \
  || fail "regression: a failed label read must not rename on a guess: $(cat "$STUB_DIR/renames")"
pass "fm_backend_herdr_workspace_relabel_lanes: a failed label read is a failure"

result=$(relabel tab-list-fails)
rc=${result%%|*}
out=${result#*|}
[ "$rc" -ne 0 ] \
  || fail "regression: a failed lane-count read must not be reported as a successful relabel: $out"
printf '%s' "$out" | grep -q "lane count" \
  || fail "regression: a failed lane-count read must be reported: $out"
[ ! -s "$STUB_DIR/renames" ] \
  || fail "regression: a failed lane-count read must never write a lane count: $(cat "$STUB_DIR/renames")"
pass "fm_backend_herdr_workspace_relabel_lanes: a failed lane-count read is a failure"

# --- the live count still works ----------------------------------------------

result=$(relabel ok)
rc=${result%%|*}
out=${result#*|}
[ "$rc" -eq 0 ] || fail "a readable lane count must relabel successfully: $out"
grep -q 'rename' "$STUB_DIR/renames" \
  || fail "a readable lane count must rewrite the container label: $out"
grep -q '2 lanes' "$STUB_DIR/renames" \
  || fail "the rewritten label must carry the live lane count: $(cat "$STUB_DIR/renames")"
pass "fm_backend_herdr_workspace_relabel_lanes: a readable lane count still rewrites the label"

result=$(relabel label-already-correct)
rc=${result%%|*}
out=${result#*|}
[ "$rc" -eq 0 ] || fail "an already correct label must be a successful no-op: $out"
[ ! -s "$STUB_DIR/renames" ] \
  || fail "an already correct label must not be renamed: $(cat "$STUB_DIR/renames")"
pass "fm_backend_herdr_workspace_relabel_lanes: an already correct label is a successful no-op"

# --- the close path reports a failed refresh ---------------------------------

stub_mode workspace-list-fails
out=$(PATH="$FB:$PATH" FM_HOME="$HOME_DIR" bash -c '
  . "$0/bin/backends/herdr.sh"
  fm_backend_herdr_kill_serialized default w1:p1
' "$ROOT" 2>&1)
printf '%s' "$out" | grep -q "lane summary" \
  || fail "regression: the close path must report a failed lane-summary refresh instead of swallowing it: $out"
[ -f "$STUB_DIR/pane-closed" ] \
  || fail "the close path must still close the pane it was asked to close: $out"
pass "fm_backend_herdr_kill_serialized: a failed lane-summary refresh is reported"

# The same close path with a READABLE surface refreshes the summary quietly.
stub_mode ok
out=$(PATH="$FB:$PATH" FM_HOME="$HOME_DIR" bash -c '
  . "$0/bin/backends/herdr.sh"
  fm_backend_herdr_kill_serialized default w1:p1
' "$ROOT" 2>&1)
printf '%s' "$out" | grep -q "lane summary" \
  && fail "a readable surface must not warn about the lane summary: $out"
pass "fm_backend_herdr_kill_serialized: a readable surface refreshes the summary without a warning"

pass "fm-backend-herdr-lane-summary-fail-closed: a failed read is never a successful relabel"
