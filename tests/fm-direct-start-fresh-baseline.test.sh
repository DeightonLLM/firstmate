#!/usr/bin/env bash
# Regression tests for the direct fresh-agent launch baseline handoff.
#
# Two parts of this contract are host artifacts rather than tracked files: the
# launch helper (herdr-agent-start-fresh) and the policy-family documents the
# baseline gate resolves. Both are resolved here the way the fleet resolves
# them - per host, and under the role that is actually running this suite -
# instead of naming one host's account home. A helper the running role cannot
# read is reported with the reason and the paths that were tried: it is never
# counted as covered, and it never silently passes.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION_START="$ROOT/bin/fm-session-start.sh"
# shellcheck source=bin/fm-baseline-lib.sh
. "$ROOT/bin/fm-baseline-lib.sh"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-direct-baseline.XXXXXX")
if [ "${KEEP_TEST_TMP:-0}" = "1" ]; then
  trap 'printf "TEST_TMP_PRESERVED=%s\\n" "$TMP_ROOT"' EXIT
else
  trap 'rm -rf "$TMP_ROOT"' EXIT
fi

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

fail() { printf 'not ok - %s\n' "$1" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
pass() { printf 'ok - %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
skip() { printf 'skip - %s\n' "$1"; SKIP_COUNT=$((SKIP_COUNT + 1)); }
assert_contains() {
  case "$1" in *"$2"*) pass "$3" ;; *) fail "$3" ;; esac
}
assert_absent() {
  case "$1" in *"$2"*) fail "$3" ;; *) pass "$3" ;; esac
}

# The canonical policy the gate hands a fresh agent is the document the policy
# role resolves to under THIS role. It must declare the FRESH_AGENT invariant
# and the baseline pointer, whatever host and whatever account scope that is.
policy_role_document() {
  local resolved
  resolved="$(fm_baseline_resolve_role policy)" || return 1
  printf '%s\n' "$resolved"
}

# The launch helper is a host artifact. Resolve it under this role: an explicit
# override, then this role's own bin directory, then the Controller account
# scope the canonical policy named before homes owned their own. A candidate
# this role cannot execute is skipped, not used and not counted as covered.
LAUNCH_HELPER_CANDIDATES=''
for _candidate in \
  "${FM_DIRECT_START_HELPER:-}" \
  "/root/bin/herdr-agent-start-fresh"; do
  [ -n "$_candidate" ] || continue
  case " $LAUNCH_HELPER_CANDIDATES " in *" $_candidate "*) continue ;; esac
  LAUNCH_HELPER_CANDIDATES="$LAUNCH_HELPER_CANDIDATES $_candidate"
done
if [ -n "${HOME:-}" ]; then
  LAUNCH_HELPER_CANDIDATES="$LAUNCH_HELPER_CANDIDATES $HOME/bin/herdr-agent-start-fresh"
fi

resolve_launch_helper() {
  local candidate
  for candidate in $LAUNCH_HELPER_CANDIDATES; do
    if [ -x "$candidate" ] && [ -r "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# The Pi default route a launch enforces is HOST state, not repo state: the
# HD2Stack helper accepts one route and the Controller helper accepts another.
# The accepted set is read from the helper's own case block, so the suite never
# hard-codes one host's routing and never fails because the fleet moved its
# Pi default between hosts.
launch_helper_routes() {
  local pattern
  # The pattern is a literal from the host helper's own source, so the dollar
  # sign must not expand here.
  # shellcheck disable=SC2016
  pattern=$(sed -n '/case "\$_pi_default_route" in/{n;p;}' "$1" 2>/dev/null | head -1)
  [ -n "$pattern" ] || return 1
  pattern="${pattern%)}"
  printf '%s\n' "$pattern" | tr '|' '\n' | sed '/^[[:space:]]*$/d'
}

# A pointer into a scope this role does not own must carry an explicit
# cross-home label. An absolute path is not itself evidence of a wrong scope:
# on the Controller and on the HD2Stack worker surface the account scope IS
# /root, so a /root pointer there is this role's own contract.
assert_no_unlabelled_foreign_pointer() {
  local manifest=$1 label=$2 line role path scope offender=''
  while IFS= read -r line; do
    case "$line" in
      policy=*|project-policy=*|routing=*|bounded=*|'lean-ctx='*) : ;;
      *) continue ;;
    esac
    role=${line%%=*}
    path=${line#*=}
    path=${path%% *}
    scope=$(printf '%s\n' "$line" | sed -n 's/.* scope=\([^ ]*\) .*/\1/p')
    case "$path" in
      "$FM_HOME"/*|"${HOME:-__none__}"/*) continue ;;
    esac
    case "$scope" in
      cross-home:*) : ;;
      *) offender="$offender $role=$path(scope=${scope:-none})" ;;
    esac
  done <<EOF
$manifest
EOF
  if [ -n "$offender" ]; then
    fail "$label: pointer(s) into a foreign scope with no cross-home label:$offender"
    return
  fi
  pass "$label: every pointer into a foreign scope carries a cross-home label"
}

# The repo-owned half of the handoff: the baseline helper the launch helper
# calls must emit a content-pinned manifest on this host, and must fail closed
# when a required baseline file is missing. This half is assertable on every
# host, including one where the launch helper is not readable.
assert_repo_owned_handoff() {
  local manifest status
  manifest="$(FM_HOME="$ROOT" "$SESSION_START" --baseline-manifest 2>&1)" || {
    fail 'baseline helper did not emit a manifest'
    return
  }
  assert_contains "$manifest" 'Baseline manifest: fresh-agent-baseline/v1' \
    'baseline helper emits the manifest version'
  assert_contains "$manifest" "warehouse=$ROOT/docs/system-context/INDEX.md sha256:" \
    'baseline helper pins the warehouse pointer'
  assert_contains "$manifest" "goal-queue=$ROOT/data/backlog.md" \
    'baseline helper pins the goal/queue pointer'

  local missing="$TMP_ROOT/missing-baseline-root"
  mkdir -p "$missing"
  status=0
  FM_HOME="$ROOT" FM_BASELINE_ROOT="$missing" "$SESSION_START" --baseline-manifest \
    >"$TMP_ROOT/missing.out" 2>&1 || status=$?
  if [ "$status" -eq 0 ]; then
    fail 'baseline helper succeeded with a missing required baseline file'
  else
    pass 'baseline helper fails closed when a required baseline file is missing'
  fi
  assert_contains "$(sed -n '1,$p' "$TMP_ROOT/missing.out")" \
    'required fresh-agent baseline file is missing' \
    'baseline helper names the missing required file'
}

# ---------------------------------------------------------------- policy contract
# The policy contract is read through the same resolution the gate uses, under
# the role that runs this suite. No host's account home is named here.
FM_HOME="$ROOT"
if policy_doc="$(policy_role_document)"; then
  policy_body="$(sed -n '1,$p' "$policy_doc")"
  assert_contains "$policy_body" '### FRESH_AGENT invariant' \
    "canonical policy declares the FRESH_AGENT invariant: $policy_doc"
  assert_contains "$policy_body" 'fresh-agent-baseline/v1' \
    "canonical policy declares the fresh-agent baseline pointer: $policy_doc"
  pass "canonical policy declares the FRESH_AGENT invariant ($policy_doc)"
else
  fail 'the policy role resolved to no readable document under this role'
fi

if project_policy_doc="$(fm_baseline_resolve_role project-policy)"; then
  if [ -r "$project_policy_doc" ] && [ -f "$project_policy_doc" ]; then
    pass "project policy resolves to a readable document under this role ($project_policy_doc)"
  else
    fail "project policy resolved to an unreadable document: $project_policy_doc"
  fi
else
  fail 'the project-policy role resolved to no readable document under this role'
fi

assert_repo_owned_handoff

# ------------------------------------------------------------- direct launch path
# The launch helper is exercised only where this role can read and execute it.
# Where it cannot, the host-dependent assertion is reported as a skip with the
# reason, and the repo-owned contract above still stands.
if START="$(resolve_launch_helper)"; then
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

  launch_route=''
  route_list="$(launch_helper_routes "$START")" || route_list=''
  for route in $route_list; do
    launch_route="$route"
    break
  done
  if [ -z "$launch_route" ]; then
    skip "direct launch path not exercised: the launch helper at $START exposes no readable Pi default-route contract"
  else
    printf '%s\n' "{\"defaultProvider\":\"${launch_route%%/*}\",\"defaultModel\":\"${launch_route#*/}\"}" \
      > "$TMP_ROOT/pi-settings.json"

    direct_out=$(
      HERDR_ENV=1 HERDR_SKIP_SKILL_DRIFT_CHECK=1 HERDR_REAP_BEFORE_START=0 QUOTA_GATE_BYPASS=1 \
      HERDR_FRESH_BASELINE_SCRIPT="$ROOT/bin/fm-session-start.sh" \
      FM_HOME="$TMP_ROOT/home" FM_BASELINE_ROOT="$ROOT" \
      PI_AGENT_SETTINGS="$TMP_ROOT/pi-settings.json" \
      PATH="$fake_bin:$PATH" AGENT_START_FRESH_PI_BIN="$fake_bin/pi" \
      "$START" direct-worker --kind pi --pane w1:pDIRECT 2>&1
    ) || fail 'direct fresh launch refused a valid baseline handoff'
    assert_contains "$direct_out" 'Baseline manifest: fresh-agent-baseline/v1' 'direct launch emits the baseline manifest version'
    # The policy-family roles resolve from the role that runs the launch, so a
    # role is either resolved or explicitly declared unavailable. Either way the
    # manifest must not name a foreign scope without saying so.
    assert_contains "$direct_out" 'project-policy=' 'direct launch carries the project policy baseline role'
    assert_no_unlabelled_foreign_pointer "$direct_out" 'direct launch manifest'
    assert_contains "$direct_out" "warehouse=$ROOT/docs/system-context/INDEX.md sha256:" 'direct launch pins the warehouse baseline pointer'
    assert_contains "$direct_out" "goal-queue=$TMP_ROOT/home/data/backlog.md" 'direct launch pins the current goal/queue pointer'
    assert_contains "$direct_out" 'HERDR_STARTED agent start direct-worker' 'direct launch starts after the baseline handoff'
    pass 'direct fresh launch emits shared baseline manifest before Herdr start'

    # The document the launch actually handed over must be the policy this role
    # owns, and it must declare the invariant the launch exists to enforce.
    handed_policy=$(printf '%s\n' "$direct_out" | sed -n 's/^policy=\([^ ]*\) scope=\([^ ]*\) .*/\1/p' | head -1)
    if [ -n "$handed_policy" ] && [ -r "$handed_policy" ]; then
      assert_contains "$(sed -n '1,$p' "$handed_policy")" '### FRESH_AGENT invariant' \
        "the policy handed to the fresh agent declares the FRESH_AGENT invariant: $handed_policy"
    else
      fail "the direct launch handed over no readable policy document: ${handed_policy:-none}"
    fi

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
    assert_contains "$direct_fail" 'REFUSE: fresh-agent baseline manifest helper missing' 'direct launch names the missing baseline helper'
    assert_absent "$direct_fail" 'PI_CLI_UPDATED' 'direct launch does not refresh the CLI after a missing baseline helper'
    case "$direct_fail" in *'HERDR_STARTED'*) fail 'direct launch started Herdr after missing baseline helper' ;; esac
    pass 'direct fresh launch fails closed before refresh/start when baseline helper is missing'
  fi
else
  skip "direct launch path not exercised: no launch helper is readable and executable by role $(id -un) (tried:${LAUNCH_HELPER_CANDIDATES:- none})"
  skip 'direct launch refusal path not exercised for the same reason'
fi

printf 'PASS=%s FAIL=%s SKIP=%s\n' "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
printf 'ALL TESTS PASSED\n'
