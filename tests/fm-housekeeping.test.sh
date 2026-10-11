#!/usr/bin/env bash
# Regression tests for First Mate control-plane housekeeping.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
HK="$ROOT/bin/fm-housekeeping.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/fm-hk-test.XXXXXX")
trap 'find "$TMP" -type f -delete; rmdir "$TMP" 2>/dev/null || true' EXIT
pass() { printf 'ok - %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
run_hk() { bash "$HK" "$@"; }

out=$(run_hk --help)
grep -q 'commands:' <<<"$out" || fail 'help missing commands'
pass 'fm-housekeeping: --help renders usage'

read -r -d '' BASE_FIXTURE <<'JSON' || true
{
  "result": {"panes": [
    {"pane_id":"w1:p0","agent":"codex","agent_status":"working","workspace_id":"w1","tab_id":"w1:t1"},
    {"pane_id":"w1:p1","agent":"agy","agent_status":"idle","workspace_id":"w1","tab_id":"w1:t1"},
    {"pane_id":"w1:p2","agent":"pi","agent_status":"idle","workspace_id":"w1","tab_id":"w1:t1"},
    {"pane_id":"w1:p3","agent":"pi","agent_status":"done","workspace_id":"w1","tab_id":"w1:t1"}
  ]}
}
JSON

out=$(FM_HOUSEKEEPING_PANES_JSON="$BASE_FIXTURE" run_hk invariants)
grep -q 'HOUSEKEEPING_INVARIANTS: 7/7 PASS' <<<"$out" || fail 'dynamic invariants did not report 7/7 PASS'
pass 'fm-housekeeping: invariants verify live fixture and report 7/7 PASS'

out=$(FM_HOUSEKEEPING_PANES_JSON="$BASE_FIXTURE" run_hk status)
grep -q 'HOUSEKEEPING STATUS:' <<<"$out" || fail 'status missing header'
grep -q 'subagents=3' <<<"$out" || fail 'status counted Codex coordinator as a subagent'
grep -q 'unreviewed_or_stale=0' <<<"$out" || fail 'status missing review/stale count'
pass 'fm-housekeeping: status reports cap, lifecycle, and coordinator-aware counts'

out=$(FM_HOUSEKEEPING_PANES_JSON="$BASE_FIXTURE" run_hk preflight)
grep -q 'PERMITTED' <<<"$out" || fail 'preflight failed when under cap'
pass 'fm-housekeeping: preflight succeeds under cap'

read -r -d '' CAP_FIXTURE <<'JSON' || true
{"result":{"panes":[
 {"pane_id":"w1:p0","agent":"codex","agent_status":"working"},
 {"pane_id":"w1:p1","agent":"pi","agent_status":"working"},
 {"pane_id":"w1:p2","agent":"pi","agent_status":"working"},
 {"pane_id":"w1:p3","agent":"pi","agent_status":"idle"},
 {"pane_id":"w1:p4","agent":"pi","agent_status":"idle"},
 {"pane_id":"w1:p5","agent":"pi","agent_status":"done"},
 {"pane_id":"w1:p6","agent":"pi","agent_status":"done"}
]}}
JSON
set +e
out=$(FM_HOUSEKEEPING_PANES_JSON="$CAP_FIXTURE" run_hk preflight 2>&1)
rc=$?
set -e
[ "$rc" -eq 64 ] || fail "preflight at cap did not exit 64 (got $rc)"
grep -q 'ERR_SUBAGENT_CAP_REACHED' <<<"$out" || fail 'preflight missing cap refusal marker'
pass 'fm-housekeeping: preflight exits 64 at subagent and total caps'

read -r -d '' BLOCKED_FIXTURE <<'JSON' || true
{"result":{"panes":[
 {"pane_id":"w1:p0","agent":"codex","agent_status":"working","workspace_id":"w1","tab_id":"w1:t1"},
 {"pane_id":"w1:p1","agent":"pi","agent_status":"blocked","workspace_id":"w1","tab_id":"w1:t1"},
 {"pane_id":"w1:p2","agent":"pi","agent_status":"idle","unreconciled":true,"workspace_id":"w1","tab_id":"w1:t1"}
]}}
JSON
set +e
out=$(FM_HOUSEKEEPING_PANES_JSON="$BLOCKED_FIXTURE" run_hk preflight 2>&1)
rc=$?
set -e
[ "$rc" -eq 65 ] || fail "preflight did not fail closed on blocked/unreconciled state (got $rc)"
grep -q 'ERR_UNRECONCILED_STATE' <<<"$out" || fail 'preflight missing unreconciled refusal marker'
pass 'fm-housekeeping: preflight fails closed on blocked/unreconciled state'

FAKE_REAPER="$TMP/fake-reaper"
cat >"$FAKE_REAPER" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
  if [[ "$arg" == *working* || "$arg" == *blocked* ]]; then
    echo 'VIOLATION: attempted to reap protected pane' >&2
    exit 1
  fi
done
echo 'REAP_SUMMARY closed=0 failed=0'
EOF
chmod 755 "$FAKE_REAPER"

set +e
out=$(FM_HOUSEKEEPING_PANES_JSON="$CAP_FIXTURE" HERDR_SETTLED_PANES='w1:p1' HERDR_REAPER_BIN="$FAKE_REAPER" run_hk reap-stale 2>&1)
rc=$?
set -e
[ "$rc" -eq 65 ] || fail "reap accepted a working settled target (got $rc)"
grep -q 'protected pane=w1:p1' <<<"$out" || fail 'reap missing protected-pane refusal'
pass 'fm-housekeeping: reap-stale refuses working settled targets'

IDLE_FIXTURE='{"result":{"panes":[{"pane_id":"w1:p3","agent":"pi","agent_status":"idle"}]}}'
out=$(FM_HOUSEKEEPING_PANES_JSON="$IDLE_FIXTURE" HERDR_SETTLED_PANES='w1:p3' HERDR_REAPER_BIN="$FAKE_REAPER" run_hk reap-stale)
grep -q 'REAP_SUMMARY' <<<"$out" || fail 'settled idle target was not passed to reaper'
pass 'fm-housekeeping: reap-stale permits explicitly settled idle target'

printf 'PASS: all First Mate housekeeping regression tests succeeded\n'
