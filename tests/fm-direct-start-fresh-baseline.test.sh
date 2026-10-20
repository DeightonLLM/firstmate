#!/usr/bin/env bash
# Regression tests for direct /root/bin/herdr-agent-start-fresh launches.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
START="/root/bin/herdr-agent-start-fresh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-direct-baseline.XXXXXX")
if [ "${KEEP_TEST_TMP:-0}" = "1" ]; then
  trap 'printf "TEST_TMP_PRESERVED=%s\\n" "$TMP_ROOT"' EXIT
else
  trap 'rm -rf "$TMP_ROOT"' EXIT
fi

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }
assert_contains() {
  case "$1" in *"$2"*) ;; *) fail "$3" ;; esac
}
assert_absent() {
  case "$1" in *"$2"*) fail "$3" ;; esac
}

policy=$(sed -n '1,$p' /root/AGENTS.md)
assert_contains "$policy" '### FRESH_AGENT invariant' 'canonical policy is missing the FRESH_AGENT invariant'
assert_contains "$policy" 'fresh-agent-baseline/v1' 'canonical policy is missing the baseline pointer requirement'
project_policy=$(sed -n '1,$p' /root/agent-work/AGENTS.md)
assert_contains "$project_policy" '### FRESH_AGENT invariant' 'project policy is missing the FRESH_AGENT invariant'
pass 'canonical policy declares the FRESH_AGENT invariant'

fake_bin="$TMP_ROOT/fake-bin"
mkdir -p "$fake_bin" "$TMP_ROOT/home/data" "$TMP_ROOT/home/state" "$TMP_ROOT/home/config"
cat > "$fake_bin/pi" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  '--version') printf 'pi 0.16.9\n' ;;
  'update --self --no-approve') printf 'PI_CLI_UPDATED\n' ;;
  'update --extensions --no-approve') printf 'PI_EXTENSIONS_UPDATED\n' ;;
  *) printf 'PI_UNEXPECTED_CALL: %s\n' "$*" >&2; exit 2 ;;
esac
EOF
cat > "$fake_bin/herdr" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-},${2:-}" = "pane,list" ]; then
  printf '{"result":{"panes":[]}}\n'
  exit 0
fi
printf 'HERDR_STARTED %s\n' "$*"
EOF
chmod +x "$fake_bin/pi" "$fake_bin/herdr"
printf '%s\n' '{"defaultProvider":"zai","defaultModel":"glm-5.3-flash"}' > "$TMP_ROOT/pi-settings.json"

direct_out=$(
  HERDR_ENV=1 HERDR_SKIP_SKILL_DRIFT_CHECK=1 HERDR_REAP_BEFORE_START=0 QUOTA_GATE_BYPASS=1 \
  HERDR_FRESH_BASELINE_SCRIPT="$ROOT/bin/fm-session-start.sh" \
  FM_HOME="$TMP_ROOT/home" FM_BASELINE_ROOT="$ROOT" \
  PI_AGENT_SETTINGS="$TMP_ROOT/pi-settings.json" \
  PATH="$fake_bin:$PATH" AGENT_START_FRESH_PI_BIN="$fake_bin/pi" \
  "$START" direct-worker --kind pi --pane w1:pDIRECT 2>&1
) || fail 'direct fresh launch refused a valid baseline handoff'
assert_contains "$direct_out" 'Baseline manifest: fresh-agent-baseline/v1' 'direct launch did not emit baseline manifest version'
# The policy-family roles resolve from the home, so a project-policy role is
# either home-resolved or explicitly declared unavailable. Either way the
# manifest must not name a path belonging to another host's account home.
assert_contains "$direct_out" 'project-policy=' 'direct launch omitted the project policy baseline role'
assert_absent "$direct_out" '/root/' 'direct launch pointed a baseline role at a Controller-rooted path'
assert_contains "$direct_out" "warehouse=$ROOT/docs/system-context/INDEX.md sha256:" 'direct launch omitted warehouse baseline pointer'
assert_contains "$direct_out" "goal-queue=$TMP_ROOT/home/data/backlog.md" 'direct launch omitted current goal/queue pointer'
assert_contains "$direct_out" 'HERDR_STARTED agent start direct-worker' 'direct launch did not start after baseline handoff'
pass 'direct fresh launch emits shared baseline manifest before Herdr start'

missing="$TMP_ROOT/missing-baseline-helper"
direct_status=0
direct_fail=$(
  HERDR_ENV=1 HERDR_SKIP_SKILL_DRIFT_CHECK=1 HERDR_REAP_BEFORE_START=0 QUOTA_GATE_BYPASS=1 \
  HERDR_FRESH_BASELINE_SCRIPT="$missing" \
  PI_AGENT_SETTINGS="$TMP_ROOT/pi-settings.json" \
  PATH="$fake_bin:$PATH" AGENT_START_FRESH_PI_BIN="$fake_bin/pi" \
  "$START" must-refuse --kind pi --pane w1:pMISSING 2>&1
) || direct_status=$?
[ "$direct_status" -eq 79 ] || fail 'direct launch did not fail closed when baseline helper was missing'
assert_contains "$direct_fail" 'REFUSE: fresh-agent baseline manifest helper missing' 'missing baseline helper diagnostic was not explicit'
assert_absent "$direct_fail" 'PI_CLI_UPDATED' 'direct launch refreshed the CLI after missing baseline helper'
case "$direct_fail" in *'HERDR_STARTED'*) fail 'direct launch started Herdr after missing baseline helper' ;; esac
pass 'direct fresh launch fails closed before refresh/start when baseline helper is missing'

printf 'ALL TESTS PASSED\n'
