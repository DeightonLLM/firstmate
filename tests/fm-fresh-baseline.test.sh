#!/usr/bin/env bash
# Regression tests for deterministic fresh-agent baseline loading.
#
# These tests are hermetic by construction: every candidate home is created
# under a temporary directory and HOME is pinned for each invocation, so the
# assertions never depend on whatever account-home policy tree the machine
# running them happens to have. They are equally meaningful when run as root and
# as an ordinary user.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIEF="$ROOT/bin/fm-brief.sh"
SESSION_START="$ROOT/bin/fm-session-start.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-fresh-baseline.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

fail() { printf 'not ok - %s\n' "$1" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
pass() { printf 'ok - %s\n' "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
assert_contains() {
  local haystack=$1 needle=$2 message=$3
  case "$haystack" in *"$needle"*) pass "$message" ;; *) fail "$message" ;; esac
}
assert_absent() {
  local haystack=$1 needle=$2 message=$3
  case "$haystack" in *"$needle"*) fail "$message" ;; *) pass "$message" ;; esac
}

# Every pointer a manifest actually resolved must name a regular file that is
# readable right now and whose recorded digest still matches its bytes. This is
# the property that makes a fresh-agent baseline usable on the home that
# emitted it, and it is asserted from the manifest rather than from any expected
# literal so it holds on every host.
verify_resolved_pointer() {
  local manifest=$1 role=$2 label=$3 line path digest actual
  # The path is captured before the scope label. Every emitted pointer now
  # carries scope=<home|account|cross-home:NAME> between the path and the digest,
  # so a greedy match would fold the label into the path and the readability
  # check would then fail on a path that exists.
  line=$(printf '%s\n' "$manifest" | sed -n "s/^${role}=\([^ ]*\) scope=\([^ ]*\) \(sha256:[0-9a-f]\{64\}\)\$/\1/p" | head -1)
  scope=$(printf '%s\n' "$manifest" | sed -n "s/^${role}=\([^ ]*\) scope=\([^ ]*\) \(sha256:[0-9a-f]\{64\}\)\$/\2/p" | head -1)
  if [ -z "$line" ]; then
    fail "$label: $role has no resolved content-pinned pointer with a scope label"
    return
  fi
  case "$scope" in
    home|account) : ;;
    cross-home:?*) : ;;
    *) fail "$label: $role has an invalid scope label: '$scope'"; return ;;
  esac
  path=$line
  digest=$(printf '%s\n' "$manifest" | sed -n "s/^${role}=.* \(sha256:[0-9a-f]\{64\}\)$/\1/p" | head -1)
  if [ ! -f "$path" ]; then
    fail "$label: $role resolved to a file that does not exist: $path"
    return
  fi
  if [ ! -r "$path" ]; then
    fail "$label: $role resolved to a file that is not readable: $path"
    return
  fi
  actual="sha256:$(sha256sum "$path" | cut -d' ' -f1)"
  if [ "$actual" != "$digest" ]; then
    fail "$label: $role digest $digest does not match resolved file $actual"
    return
  fi
  pass "$label: $role resolves to a readable existing file with a matching digest"
}

# A pointer into a scope this home does not own must carry an explicit
# cross-home label. The accepted contract is an explicit scope label, not
# absence: the policy family genuinely lives in a root-owned scope that is
# readable from this host, and reporting a readable file as missing discards a
# real contract. So the rule is that a pointer outside this home and outside
# the account scope is labelled cross-home:NAME. The warehouse, goal-queue and
# state pointers are firstmate-owned and carry no scope label, so the rule
# covers the policy family only.
assert_no_manifest_pointer_to_other_home() {
  local manifest=$1 label=$2 home=$3 account=${4:-$3} line role path scope offender=''
  while IFS= read -r line; do
    case "$line" in
      policy=*|project-policy=*|routing=*|bounded=*|'lean-ctx='*) : ;;
      *) continue ;;
    esac
    role=${line%%=*}
    path=${line#*=}
    path=${path%% *}
    case "$path" in
      unavailable*) continue ;;
    esac
    scope=$(printf '%s\n' "$line" | sed -n 's/.* scope=\([^ ]*\) .*/\1/p')
    case "$path" in
      "$home"/*|"$account"/*) continue ;;
    esac
    case "$scope" in
      cross-home:*) : ;;
      *) offender="$offender $role=$path(scope=${scope:-none})" ;;
    esac
  done <<EOF
$manifest
EOF
  if [ -n "$offender" ]; then
    fail "$label: manifest has a cross-home pointer with no scope label: $offender"
    return
  fi
  pass "$label: every cross-home pointer carries a scope label"
}

# Build a home that owns every policy-family role.
make_populated_home() {
  local home=$1
  mkdir -p "$home/data" "$home/state" "$home/config" "$home/.codex" \
    "$home/agent-work" "$home/docs/agent-policy"
  touch "$home/data/backlog.md"
  printf '# canonical agent policy\n' > "$home/AGENT-POLICY.md"
  printf '# worker surface standing rules\n' > "$home/agent-work/AGENTS.md"
  printf '# lean-ctx rules\n' > "$home/.codex/LEAN-CTX.md"
  printf '# herdr agent routing\n' > "$home/docs/agent-policy/HERDR_AGENT_ROUTING.md"
  printf '# herdr bounded execution\n' > "$home/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md"
}

run_brief() {
  local home=$1
  shift
  env HOME="$home" \
    FM_HOME="$home" \
    FM_ROOT_OVERRIDE="$ROOT" \
    FM_BASELINE_ROOT="$ROOT" \
    FM_BASELINE_TODAY=2026-09-15 \
    "$@"
}

# ---------------------------------------------------------------- resolved case
POPULATED="$TMP_ROOT/populated-home"
make_populated_home "$POPULATED"

labels=(scout worker captain)
ids=(fresh-scout fresh-worker fresh-captain)

run_brief "$POPULATED" "$BRIEF" fresh-scout firstmate --scout >/dev/null 2>&1 || {
  printf 'not ok - scout brief generation failed\n' >&2
  exit 1
}
run_brief "$POPULATED" "$BRIEF" fresh-worker firstmate >/dev/null 2>&1 || {
  printf 'not ok - worker brief generation failed\n' >&2
  exit 1
}
run_brief "$POPULATED" env FM_SECONDMATE_CHARTER='fresh captain' \
  "$BRIEF" fresh-captain --secondmate --no-projects >/dev/null 2>&1 || {
  printf 'not ok - captain brief generation failed\n' >&2
  exit 1
}

for i in 0 1 2; do
  label=${labels[$i]}
  manifest=$(sed -n '1,$p' "$POPULATED/data/${ids[$i]}/brief.md")
  assert_contains "$manifest" '# Fresh-agent baseline' "$label brief missing baseline heading"
  assert_contains "$manifest" 'Baseline manifest: fresh-agent-baseline/v1' "$label brief missing manifest version"
  assert_contains "$manifest" "policy=$POPULATED/AGENT-POLICY.md scope=home sha256:" "$label brief policy not resolved from the home"
  assert_contains "$manifest" "project-policy=$POPULATED/agent-work/AGENTS.md scope=home sha256:" "$label brief project policy not resolved from the home"
  assert_contains "$manifest" "routing=$POPULATED/docs/agent-policy/HERDR_AGENT_ROUTING.md scope=home sha256:" "$label brief routing not resolved from the home"
  assert_contains "$manifest" "bounded=$POPULATED/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md scope=home sha256:" "$label brief bounded-execution not resolved from the home"
  assert_contains "$manifest" "lean-ctx=$POPULATED/.codex/LEAN-CTX.md scope=home sha256:" "$label brief lean-ctx not resolved from the home"
  assert_contains "$manifest" "warehouse=$ROOT/docs/system-context/INDEX.md sha256:" "$label brief missing warehouse hash pointer"
  assert_contains "$manifest" "warehouse-preflight=$ROOT/bin/fm-context-preflight.sh" "$label brief missing warehouse preflight pointer"
  assert_contains "$manifest" "goal-queue=$POPULATED/data/backlog.md" "$label brief missing goal/queue handoff pointer"
  assert_contains "$manifest" "state-handoff=$POPULATED/state/.wake-queue" "$label brief missing state handoff pointer"
  assert_contains "$manifest" 'Read pointers and hashes above; do not paste or inherit prior conversation history.' "$label brief missing no-history rule"
  assert_absent "$manifest" '## Selection invariant' "$label brief pasted routing-policy body instead of pointer"
  assert_absent "$manifest" '-----BEGIN PRIVATE KEY-----' "$label brief contains secret-like material"
  assert_no_manifest_pointer_to_other_home "$manifest" "$label brief" "$POPULATED"
  verify_resolved_pointer "$manifest" policy "$label brief"
  verify_resolved_pointer "$manifest" project-policy "$label brief"
  verify_resolved_pointer "$manifest" routing "$label brief"
  verify_resolved_pointer "$manifest" bounded "$label brief"
  verify_resolved_pointer "$manifest" lean-ctx "$label brief"
done

# The session-start emitter must resolve the same roles from the same home, and
# must keep pinning both warehouse pointers with a digest. That digest shape is
# contract, so it is asserted rather than assumed.
populated_session=$(env HOME="$POPULATED" FM_HOME="$POPULATED" FM_ROOT_OVERRIDE="$ROOT" \
  "$SESSION_START" --baseline-manifest 2>&1)
assert_contains "$populated_session" "policy=$POPULATED/AGENT-POLICY.md scope=home sha256:" 'session-start policy not resolved from the home'
assert_contains "$populated_session" "routing=$POPULATED/docs/agent-policy/HERDR_AGENT_ROUTING.md scope=home sha256:" 'session-start routing not resolved from the home'
assert_contains "$populated_session" "lean-ctx=$POPULATED/.codex/LEAN-CTX.md scope=home sha256:" 'session-start lean-ctx not resolved from the home'
assert_contains "$populated_session" "warehouse=$ROOT/docs/system-context/INDEX.md sha256:" 'session-start missing warehouse hash pointer'
assert_contains "$populated_session" "warehouse-preflight=$ROOT/bin/fm-context-preflight.sh sha256:" 'session-start dropped the warehouse preflight digest'
assert_no_manifest_pointer_to_other_home "$populated_session" 'populated session-start manifest' "$POPULATED"

# ------------------------------------------------------------- account-scope case
# A firstmate home that is not a checkout of this repo owns no policy document
# of its own. The canonical policy then belongs to the ACCOUNT scope, which is
# where the Hetz lane keeps it, at <account>/agent-work/AGENT-POLICY.md. This
# case proves the account scope is consulted before any cross-home scope: the
# cross-home scope is pointed at an empty directory, so only the account
# candidate can answer.
ACCOUNT="$TMP_ROOT/account-home"
LANE="$TMP_ROOT/lane-home"
ACCOUNT_SCOPE="$TMP_ROOT/empty-cross-home-scope"
mkdir -p "$ACCOUNT/agent-work" "$LANE/data" "$LANE/state" "$ACCOUNT_SCOPE"
touch "$LANE/data/backlog.md"
printf '# account-scoped canonical agent policy\n' > "$ACCOUNT/agent-work/AGENT-POLICY.md"

env HOME="$ACCOUNT" FM_HOME="$LANE" FM_ROOT_OVERRIDE="$ROOT" FM_BASELINE_ROOT="$ROOT" \
  FM_BASELINE_ROOT_SCOPE="$ACCOUNT_SCOPE" FM_BASELINE_TODAY=2026-09-15 \
  "$BRIEF" account-worker firstmate >/dev/null 2>&1 || {
  printf 'not ok - brief generation failed with the policy owned by the account scope\n' >&2
  exit 1
}

account_brief=$(sed -n '1,$p' "$LANE/data/account-worker/brief.md")
account_session=$(env HOME="$ACCOUNT" FM_HOME="$LANE" FM_ROOT_OVERRIDE="$ROOT" \
  FM_BASELINE_ROOT_SCOPE="$ACCOUNT_SCOPE" \
  "$SESSION_START" --baseline-manifest 2>&1)
assert_contains "$account_brief" "policy=$ACCOUNT/agent-work/AGENT-POLICY.md scope=account sha256:" \
  'brief policy did not resolve from the account scope'
assert_contains "$account_session" "policy=$ACCOUNT/agent-work/AGENT-POLICY.md scope=account sha256:" \
  'session-start policy did not resolve from the account scope'
verify_resolved_pointer "$account_brief" policy 'account-scoped brief'
verify_resolved_pointer "$account_session" policy 'account-scoped session-start manifest'
assert_no_manifest_pointer_to_other_home "$account_brief" 'account-scoped brief' "$LANE" "$ACCOUNT"

# The unavailable marker must carry the role name, must state the gap, and must
# never carry a path or a digest that would read as a content-pinned pointer.
assert_unavailable_line() {
  local manifest=$1 role=$2 label=$3 line
  line=$(printf '%s\n' "$manifest" | sed -n "s/^${role}=\(.*\)$/\1/p" | head -1)
  if [ -z "$line" ]; then
    fail "$label: $role emitted no line at all"
    return
  fi
  case "$line" in
    unavailable*) ;;
    *)
      fail "$label: $role should be unavailable but emitted: $line"
      return
      ;;
  esac
  case "$line" in
    *sha256:*|*/*)
      fail "$label: unavailable $role line carries a path or digest: $line"
      return
      ;;
  esac
  pass "$label: $role declares itself unavailable with no path and no digest"
}

# --------------------------------------------------------------- unavailable case
# A home that owns none of the policy-family documents must still produce a
# manifest, and must say which contracts are missing rather than dropping the
# roles or mislabeling another scope's contract as its own.
#
# The cross-home scope is pointed at an EMPTY temporary directory for this case,
# via FM_BASELINE_ROOT_SCOPE. Otherwise the real /root scope is readable from this
# host and the roles resolve to it with a cross-home:root label, which is correct
# behaviour and not the unavailable case under test. Pointing the scope at an empty
# directory is what makes "no readable file in ANY scope" reproducible.
BARE="$TMP_ROOT/bare-home"
BARE_SCOPE="$TMP_ROOT/bare-root-scope"
mkdir -p "$BARE/data" "$BARE/state" "$BARE_SCOPE"
touch "$BARE/data/backlog.md"

run_brief "$BARE" env FM_BASELINE_ROOT_SCOPE="$BARE_SCOPE" "$BRIEF" bare-worker firstmate >/dev/null 2>&1 || {
  printf 'not ok - brief generation failed with no readable policy files in any scope\n' >&2
  exit 1
}

bare_brief=$(sed -n '1,$p' "$BARE/data/bare-worker/brief.md")
bare_session=$(env HOME="$BARE" FM_HOME="$BARE" FM_ROOT_OVERRIDE="$ROOT" \
  FM_BASELINE_ROOT_SCOPE="$BARE_SCOPE" \
  "$SESSION_START" --baseline-manifest 2>&1)

assert_contains "$bare_brief" 'Baseline manifest: fresh-agent-baseline/v1' 'bare brief missing manifest version'
assert_no_manifest_pointer_to_other_home "$bare_brief" 'bare brief' "$BARE"
assert_no_manifest_pointer_to_other_home "$bare_session" 'bare session-start manifest' "$BARE"
for role in policy project-policy routing bounded lean-ctx; do
  assert_unavailable_line "$bare_brief" "$role" 'bare brief'
  assert_unavailable_line "$bare_session" "$role" 'bare session-start manifest'
done
assert_contains "$bare_brief" "warehouse=$ROOT/docs/system-context/INDEX.md sha256:" 'bare brief still pins the warehouse'

# The two emitters must agree on the unavailable contract.
if [ "$bare_brief" = "$bare_session" ]; then
  fail 'brief and session-start baseline blocks are byte-identical, so one is not generated'
else
  pass 'brief and session-start emit the baseline independently'
fi

# --------------------------------------------------------- fail-closed preserved
# The warehouse pointer and its preflight hook are firstmate-owned and must
# still fail the whole manifest closed when they are absent.
missing="$TMP_ROOT/missing-baseline"
mkdir -p "$missing"
if run_brief "$POPULATED" env FM_BASELINE_ROOT="$missing" "$BRIEF" must-refuse firstmate --scout >"$TMP_ROOT/missing.out" 2>"$TMP_ROOT/missing.err"; then
  fail 'brief generation succeeded with missing required baseline files'
else
  pass 'brief generation fails closed when required baseline files are missing'
fi
[ ! -e "$POPULATED/data/must-refuse/brief.md" ] || fail 'missing baseline still wrote a brief'
assert_contains "$(sed -n '1,$p' "$TMP_ROOT/missing.err")" 'required fresh-agent baseline file is missing' 'missing baseline error was not explicit'

session_missing="$TMP_ROOT/missing-session-baseline"
mkdir -p "$session_missing"
session_out="$TMP_ROOT/session.out"
session_status=0
env HOME="$POPULATED" FM_HOME="$POPULATED" FM_ROOT_OVERRIDE="$ROOT" FM_BASELINE_ROOT="$session_missing" \
  bash "$SESSION_START" >"$session_out" 2>&1 || session_status=$?
[ "$session_status" -eq 2 ] || fail 'session start did not fail closed on a missing baseline'
assert_contains "$(sed -n '1,$p' "$session_out")" 'BASELINE: FAIL required fresh-agent baseline file is missing' 'session start missing-baseline diagnostic was not explicit'
assert_absent "$(sed -n '1,$p' "$session_out")" $'\nLOCK\n' 'session start attempted lock mutation after baseline failure'

printf 'PASS=%s FAIL=%s\n' "$PASS_COUNT" "$FAIL_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
printf 'ALL TESTS PASSED\n'