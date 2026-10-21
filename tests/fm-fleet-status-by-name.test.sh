#!/usr/bin/env bash
# Behavior tests for bin/fm-fleet-status-by-name.sh
set -u

# shellcheck source=tests/lib.sh
# shellcheck disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CMD="$ROOT/bin/fm-fleet-status-by-name.sh"
TMP_ROOT=$(fm_test_tmproot fm-fleet-status-by-name)

command -v jq >/dev/null 2>&1 || { echo "skip: jq not found"; exit 0; }

# Test 1: The tool detects a crew whose pane label claims one thing while live agent status says another.
# Pane label: "working", but live agent_status: "idle".
# The tool must report agent_status "idle" and NOT conflate it with working.
test_label_vs_live_status() {
  local dir="$TMP_ROOT/test1"
  mkdir -p "$dir/bin" "$dir/home/state"
  
  # Fake beacon (fresh)
  touch "$dir/home/state/.last-watcher-beat"

  # Fake herdr
  cat << 'MOCK' > "$dir/bin/herdr"
#!/usr/bin/env bash
case "$*" in
  "tab list")
    cat << 'JSON'
{"id":"cli:tab:list","result":{"tabs":[{"agent_status":"idle","focused":true,"label":"fm-supposedly-running","number":1,"pane_count":1,"tab_id":"w1:t1","workspace_id":"w1"}],"type":"tab_list"}}
JSON
    ;;
  "pane list")
    cat << 'JSON'
{"id":"cli:pane:list","result":{"panes":[{"agent":"pi","agent_status":"idle","label":"working","pane_id":"w1:p1","tab_id":"w1:t1","workspace_id":"w1"}],"type":"pane_list"}}
JSON
    ;;
  *"pane read w1:p1"*)
    printf '✓ gpt-6.1-sol · w1:p1 · READY\n'
    ;;
  *)
    echo "unhandled mock herdr command: $*" >&2
    exit 1
    ;;
esac
MOCK
  chmod +x "$dir/bin/herdr"

  local out="$dir/out.txt"
  PATH="$dir/bin:$PATH" "$CMD" --host-override "local:localhost:$dir/home" > "$out" || fail "cmd failed"

  assert_contains "$(cat "$out")" "fm-supposedly-running" "must identify crew by tab label"
  assert_contains "$(cat "$out")" "idle" "must report live agent status idle despite label saying working"
  assert_not_contains "$(cat "$out")" "w1:p1" "must never print bare pane id as crew identity"
  pass "detected live idle status despite label claiming working"
}

# Test 2: Unreachable host fails loudly
test_unreachable_host() {
  local dir="$TMP_ROOT/test2"
  mkdir -p "$dir"
  local out="$dir/out.txt" err="$dir/err.txt"
  local code=0
  "$CMD" --host-override "unreachable:192.0.2.1:/nonexistent" > "$out" 2> "$err" || code=$?
  [ "$code" -ne 0 ] || fail "must fail on unreachable host"
  assert_contains "$(cat "$err")" "unreachable" "must name unreachable host in error output"
  pass "fails loudly on unreachable host"
}

# Test 3: Stale watcher beacon detected against FM_GUARD_GRACE
test_stale_watcher() {
  local dir="$TMP_ROOT/test3"
  mkdir -p "$dir/bin" "$dir/home/state"

  # Create an 8315s stale beacon
  touch -d "8315 seconds ago" "$dir/home/state/.last-watcher-beat" 2>/dev/null || \
  perl -e 'utime time - 8315, time - 8315, shift' "$dir/home/state/.last-watcher-beat"

  cat << 'MOCK' > "$dir/bin/herdr"
#!/usr/bin/env bash
case "$*" in
  "tab list")
    cat << 'JSON'
{"id":"cli:tab:list","result":{"tabs":[],"type":"tab_list"}}
JSON
    ;;
  "pane list")
    cat << 'JSON'
{"id":"cli:pane:list","result":{"panes":[],"type":"pane_list"}}
JSON
    ;;
esac
MOCK
  chmod +x "$dir/bin/herdr"

  local out="$dir/out.txt"
  PATH="$dir/bin:$PATH" FM_GUARD_GRACE=300 "$CMD" --host-override "local:localhost:$dir/home" > "$out" || fail "cmd failed"

  assert_contains "$(cat "$out")" "stale" "must detect stale watcher"
  pass "detected stale watcher"
}

# Test 4: Tab without label prints explicit "(no label)"
test_unlabeled_tab() {
  local dir="$TMP_ROOT/test4"
  mkdir -p "$dir/bin" "$dir/home/state"
  touch "$dir/home/state/.last-watcher-beat"

  cat << 'MOCK' > "$dir/bin/herdr"
#!/usr/bin/env bash
case "$*" in
  "tab list")
    cat << 'JSON'
{"id":"cli:tab:list","result":{"tabs":[{"agent_status":"working","focused":true,"label":"","number":1,"pane_count":1,"tab_id":"w1:t1","workspace_id":"w1"}],"type":"tab_list"}}
JSON
    ;;
  "pane list")
    cat << 'JSON'
{"id":"cli:pane:list","result":{"panes":[{"agent":"agy","agent_status":"working","pane_id":"w1:p1","tab_id":"w1:t1","workspace_id":"w1"}],"type":"pane_list"}}
JSON
    ;;
  *"pane read"*)
    printf 'Gemini 3.8 Flash · medium\n'
    ;;
esac
MOCK
  chmod +x "$dir/bin/herdr"

  local out="$dir/out.txt"
  PATH="$dir/bin:$PATH" "$CMD" --host-override "local:localhost:$dir/home" > "$out" || fail "cmd failed"

  assert_contains "$(cat "$out")" "(no label)" "must explicitly state no label rather than falling back to pane id"
  assert_not_contains "$(cat "$out")" "w1:p1" "must not print bare pane id as crew identity"
  pass "unlabeled tab reported as (no label)"
}

test_label_vs_live_status
test_unreachable_host
test_stale_watcher
test_unlabeled_tab
