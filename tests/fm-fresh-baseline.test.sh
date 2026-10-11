#!/usr/bin/env bash
# Regression tests for deterministic fresh-agent baseline loading.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIEF="$ROOT/bin/fm-brief.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-fresh-baseline.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }
assert_contains() {
  local haystack=$1 needle=$2 message=$3
  case "$haystack" in *"$needle"*) ;; *) fail "$message" ;; esac
}
assert_absent() {
  local haystack=$1 needle=$2 message=$3
  case "$haystack" in *"$needle"*) fail "$message" ;; esac
}

assert_manifest() {
  local brief=$1 kind=$2 line
  assert_contains "$brief" '# Fresh-agent baseline' "$kind brief missing baseline heading"
  assert_contains "$brief" 'Baseline manifest: fresh-agent-baseline/v1' "$kind brief missing manifest version"
  assert_contains "$brief" 'policy=/root/AGENTS.md sha256:' "$kind brief missing policy hash pointer"
  assert_contains "$brief" 'project-policy=/root/agent-work/AGENTS.md sha256:' "$kind brief missing project policy hash pointer"
  assert_contains "$brief" 'routing=/root/docs/agent-policy/HERDR_AGENT_ROUTING.md sha256:' "$kind brief missing routing hash pointer"
  assert_contains "$brief" 'bounded=/root/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md sha256:' "$kind brief missing bounded-execution hash pointer"
  assert_contains "$brief" 'lean-ctx=/root/.codex/LEAN-CTX.md sha256:' "$kind brief missing lean-ctx hash pointer"
  assert_contains "$brief" "warehouse=$ROOT/docs/system-context/INDEX.md sha256:" "$kind brief missing warehouse hash pointer"
  assert_contains "$brief" "warehouse-preflight=$ROOT/bin/fm-context-preflight.sh" "$kind brief missing warehouse preflight pointer"
  assert_contains "$brief" "goal-queue=$TMP_ROOT/home/data/backlog.md" "$kind brief missing goal/queue handoff pointer"
  assert_contains "$brief" "state-handoff=$TMP_ROOT/home/state/.wake-queue" "$kind brief missing state handoff pointer"
  assert_contains "$brief" 'Read pointers and hashes above; do not paste or inherit prior conversation history.' "$kind brief missing no-history rule"
  assert_absent "$brief" '## Selection invariant' "$kind brief pasted routing-policy body instead of pointer"
  assert_absent "$brief" '-----BEGIN PRIVATE KEY-----' "$kind brief contains secret-like material"
}

mkdir -p "$TMP_ROOT/home/data" "$TMP_ROOT/home/state" "$TMP_ROOT/home/config"
touch "$TMP_ROOT/home/data/backlog.md"

run_brief() {
  FM_HOME="$TMP_ROOT/home" \
  FM_ROOT_OVERRIDE="$ROOT" \
  FM_BASELINE_ROOT="$ROOT" \
  FM_BASELINE_TODAY=2026-09-15 \
  "$@"
}

scout=$(run_brief "$BRIEF" fresh-scout firstmate --scout 2>/dev/null) || fail 'scout brief generation failed'
scout=$(sed -n '1,$p' "$TMP_ROOT/home/data/fresh-scout/brief.md")
assert_manifest "$scout" scout
pass 'scout brief carries deterministic baseline manifest pointers'

worker=$(run_brief "$BRIEF" fresh-worker firstmate 2>/dev/null) || fail 'worker brief generation failed'
worker=$(sed -n '1,$p' "$TMP_ROOT/home/data/fresh-worker/brief.md")
assert_manifest "$worker" worker
pass 'worker brief carries deterministic baseline manifest pointers'

captain=$(run_brief env FM_SECONDMATE_CHARTER='fresh captain' "$BRIEF" fresh-captain --secondmate --no-projects 2>/dev/null) || fail 'captain brief generation failed'
captain=$(sed -n '1,$p' "$TMP_ROOT/home/data/fresh-captain/brief.md")
assert_manifest "$captain" captain
pass 'captain brief carries deterministic baseline manifest pointers'

missing="$TMP_ROOT/missing-baseline"
mkdir -p "$missing"
if run_brief env FM_BASELINE_ROOT="$missing" "$BRIEF" must-refuse firstmate --scout >"$TMP_ROOT/missing.out" 2>"$TMP_ROOT/missing.err"; then
  fail 'brief generation succeeded with missing required baseline files'
fi
[ ! -e "$TMP_ROOT/home/data/must-refuse/brief.md" ] || fail 'missing baseline still wrote a brief'
assert_contains "$(sed -n '1,$p' "$TMP_ROOT/missing.err")" 'required fresh-agent baseline file is missing' 'missing baseline error was not explicit'
pass 'brief generation fails closed when required baseline files are missing'

session_missing="$TMP_ROOT/missing-session-baseline"
mkdir -p "$session_missing"
session_out="$TMP_ROOT/session.out"
session_status=0
FM_HOME="$TMP_ROOT/home" FM_ROOT_OVERRIDE="$ROOT" FM_BASELINE_ROOT="$session_missing" \
  bash "$ROOT/bin/fm-session-start.sh" >"$session_out" 2>&1 || session_status=$?
[ "$session_status" -eq 2 ] || fail 'session start did not fail closed on a missing baseline'
assert_contains "$(sed -n '1,$p' "$session_out")" 'BASELINE: FAIL required fresh-agent baseline file is missing' 'session start missing-baseline diagnostic was not explicit'
assert_absent "$(sed -n '1,$p' "$session_out")" $'\nLOCK\n' 'session start attempted lock mutation after baseline failure'
pass 'session start fails closed before mutation when required baseline files are missing'

printf 'ALL TESTS PASSED\n'
