#!/usr/bin/env bash
# tests/herdr-subagent-cap-check.test.sh - Regression tests for herdr-subagent-cap-check
#
# Verifies that:
#   1. Empty workspace argument omits --workspace flag (bare `herdr pane list`).
#   2. Explicit workspace argument passes --workspace <ws>.
#   3. Unset/empty HERDR_WORKSPACE_ID omits --workspace flag.
#   4. Cap check succeeds (exit 0) when subagent count < 6.
#   5. Cap check refuses (exit 64) with census when subagent count >= 6.
#   6. Cap check fails (exit 3) when herdr service is truly unavailable.

set -euo pipefail

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CAP_CHECK="$ROOT/bin/herdr-subagent-cap-check"

test_empty_workspace_omits_flag() {
  local tmp_root fakebin recorded_args out rc
  tmp_root=$(fm_test_tmproot cap-check-empty-ws)
  fakebin="$tmp_root/fakebin"
  recorded_args="$tmp_root/recorded_args.txt"
  mkdir -p "$fakebin"

  # Mock herdr recording its arguments and returning 1 subagent pane
  cat > "$fakebin/herdr" <<MOCK
#!/usr/bin/env bash
echo "\$*" >> "$recorded_args"
cat <<'JSON'
{"type":"pane_list","result":{"panes":[
  {"pane_id":"wA:p1","agent":"pi","agent_status":"idle"}
]}}
JSON
MOCK
  chmod +x "$fakebin/herdr"

  # Run cap check with explicit empty workspace argument ""
  out=$(PATH="$fakebin:$PATH" HERDR_WORKSPACE_ID="wA" bash "$CAP_CHECK" "" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -eq 0 ] || fail "cap-check with empty ws argument should exit 0, got $rc: $out"
  if grep -q -- "--workspace" "$recorded_args"; then
    fail "expected --workspace to be omitted, but found it in recorded args: $(cat "$recorded_args")"
  fi
  pass "empty workspace argument omits --workspace flag"
}

test_explicit_workspace_passes_flag() {
  local tmp_root fakebin recorded_args out rc
  tmp_root=$(fm_test_tmproot cap-check-explicit-ws)
  fakebin="$tmp_root/fakebin"
  recorded_args="$tmp_root/recorded_args.txt"
  mkdir -p "$fakebin"

  cat > "$fakebin/herdr" <<MOCK
#!/usr/bin/env bash
echo "\$*" >> "$recorded_args"
cat <<'JSON'
{"type":"pane_list","result":{"panes":[
  {"pane_id":"wB:p1","agent":"pi","agent_status":"idle"}
]}}
JSON
MOCK
  chmod +x "$fakebin/herdr"

  out=$(PATH="$fakebin:$PATH" HERDR_WORKSPACE_ID="" bash "$CAP_CHECK" "wB" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -eq 0 ] || fail "cap-check with explicit ws should exit 0, got $rc: $out"
  grep -q -- "--workspace wB" "$recorded_args" || fail "--workspace wB not found in: $(cat "$recorded_args")"
  pass "explicit workspace argument passes --workspace <ws>"
}

test_unset_env_and_no_args_omits_flag() {
  local tmp_root fakebin recorded_args out rc
  tmp_root=$(fm_test_tmproot cap-check-unset-env)
  fakebin="$tmp_root/fakebin"
  recorded_args="$tmp_root/recorded_args.txt"
  mkdir -p "$fakebin"

  cat > "$fakebin/herdr" <<MOCK
#!/usr/bin/env bash
echo "\$*" >> "$recorded_args"
cat <<'JSON'
{"type":"pane_list","result":{"panes":[
  {"pane_id":"wA:p1","agent":"pi","agent_status":"idle"}
]}}
JSON
MOCK
  chmod +x "$fakebin/herdr"

  out=$(PATH="$fakebin:$PATH" HERDR_WORKSPACE_ID="" bash "$CAP_CHECK" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -eq 0 ] || fail "cap-check with unset ws should exit 0, got $rc: $out"
  if grep -q -- "--workspace" "$recorded_args"; then
    fail "expected --workspace to be omitted, but found it in recorded args: $(cat "$recorded_args")"
  fi
  pass "unset workspace env and no args omits --workspace flag"
}

test_cap_reached_census() {
  local tmp_root fakebin out rc
  tmp_root=$(fm_test_tmproot cap-check-at-cap)
  fakebin="$tmp_root/fakebin"
  mkdir -p "$fakebin"

  cat > "$fakebin/herdr" <<'MOCK'
#!/usr/bin/env bash
cat <<'JSON'
{"type":"pane_list","result":{"panes":[
  {"pane_id":"w1:p1","agent":"pi","agent_status":"working"},
  {"pane_id":"w1:p2","agent":"pi","agent_status":"working"},
  {"pane_id":"w1:p3","agent":"pi","agent_status":"working"},
  {"pane_id":"w1:p4","agent":"pi","agent_status":"working"},
  {"pane_id":"w1:p5","agent":"pi","agent_status":"working"},
  {"pane_id":"w1:p6","agent":"pi","agent_status":"working"}
]}}
JSON
MOCK
  chmod +x "$fakebin/herdr"

  out=$(PATH="$fakebin:$PATH" HERDR_WORKSPACE_ID="" bash "$CAP_CHECK" "" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -eq 64 ] || fail "cap-check at cap must exit 64, got $rc: $out"
  assert_contains "$out" "ERR_SUBAGENT_CAP_REACHED" "refusal marker present"
  # The cap census is surfaced by the canonical cap library, which names the
  # count and the bound the way the library itself does: "open_subagent=6" and
  # "MAX_SUBAGENT_PANES=6". The check is that the real census reaches the
  # operator, not that one particular wording survives a library change.
  assert_contains "$out" "open_subagent=6" "census subagent count present"
  assert_contains "$out" "MAX_SUBAGENT_PANES=6" "census max subagent count present"
  pass "cap check reports refusal and real pane census at capacity"
}

test_herdr_unavailable_exits_3() {
  local tmp_root fakebin out rc
  tmp_root=$(fm_test_tmproot cap-check-down)
  fakebin="$tmp_root/fakebin"
  mkdir -p "$fakebin"

  cat > "$fakebin/herdr" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
  chmod +x "$fakebin/herdr"

  out=$(PATH="$fakebin:$PATH" HERDR_WORKSPACE_ID="" bash "$CAP_CHECK" "" 2>&1) || rc=$?
  rc=${rc:-0}

  [ "$rc" -eq 3 ] || fail "cap-check when herdr down must exit 3, got $rc: $out"
  assert_contains "$out" "server unavailable" "server unavailable message surfaced"
  pass "cap check exits 3 when herdr is down"
}

run_suite() {
  test_empty_workspace_omits_flag
  test_explicit_workspace_passes_flag
  test_unset_env_and_no_args_omits_flag
  test_cap_reached_census
  test_herdr_unavailable_exits_3
}

run_suite
