#!/usr/bin/env bash
# Regression tests for the fail-closed campaign-worker authority envelope.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
LIB="$ROOT/bin/fm-campaign-worker-lib.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-campaign-worker-authority.XXXXXX")
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }
assert_contains() {
  case "$1" in *"$2"*) ;; *) fail "$3" ;; esac
}
assert_absent() {
  case "$1" in *"$2"*) fail "$3" ;; esac
}

[ -r "$LIB" ] || fail 'campaign-worker library is missing'
. "$LIB"

home="$TMP_ROOT/home"
state="$home/state"
data="$home/data/CLIENT-AFK-20260916-01"
marker_dir="$TMP_ROOT/campaign-state"
mkdir -p -m 700 "$state" "$data" "$marker_dir"
task="$data/client-audit.prompt"
artifact="$data/client-audit.md"
lease="$data/leases/client-audit.lease"
mkdir -p "$data/leases"
printf '%s\n' 'bounded task bytes' > "$task"
printf '%s\n' "$$" > "$state/.lock"

marker="$(fm_campaign_worker_marker_path "$marker_dir" 'wBF:p49')"
create_out=""
create_status=0
create_out=$(
  HERDR_OPERATOR_APPROVED=1 \
  HERDR_CAMPAIGN_WORKER_MARKER_DIR="$marker_dir" \
  HERDR_CAMPAIGN_WORKER_CONTROLLER_STATE="$state" \
  HERDR_CAMPAIGN_WORKER_RUN_ID='CLIENT-AFK-20260916-01' \
  HERDR_CAMPAIGN_WORKER_TASK_ID='client-audit' \
  HERDR_CAMPAIGN_WORKER_HOST='controller-local' \
  HERDR_CAMPAIGN_WORKER_KIND='senpi' \
  HERDR_CAMPAIGN_WORKER_MODEL='minimax/MiniMax-M3' \
  HERDR_CAMPAIGN_WORKER_PANE='wBF:p49' \
  HERDR_CAMPAIGN_WORKER_TASK_FILE="$task" \
  HERDR_CAMPAIGN_WORKER_ARTIFACT="$artifact" \
  HERDR_CAMPAIGN_WORKER_LEASE="$lease" \
  HERDR_CAMPAIGN_WORKER_MAX_SECONDS=3600 \
  fm_campaign_worker_create_marker
) || create_status=$?
[ "$create_status" -eq 0 ] || fail 'valid campaign marker was not created'
assert_contains "$create_out" 'CAMPAIGN_WORKER_MARKER_CREATED' 'marker creation did not emit a deterministic success signal'
[ -f "$marker" ] || fail 'marker path was not created'
[ "$(stat -c '%a' "$marker")" = 600 ] || fail 'marker permissions are not 0600'

valid_status=0
HERDR_CAMPAIGN_WORKER_MARKER="$marker" \
HERDR_CAMPAIGN_WORKER_MARKER_DIR="$marker_dir" \
HERDR_CAMPAIGN_WORKER_CONTROLLER_STATE="$state" \
HERDR_CAMPAIGN_WORKER_PANE='wBF:p49' \
HERDR_CAMPAIGN_WORKER_KIND='senpi' \
HERDR_CAMPAIGN_WORKER_MODEL='minimax/MiniMax-M3' \
fm_campaign_worker_validate_marker "$marker" "$state" || valid_status=$?
[ "$valid_status" -ne 0 ] || fail 'validator accepted an unverified controller lock process'
pass 'marker creation is bounded and liveness validation fails closed without a live controller lock'

status=0
bad_out=$(
  HERDR_OPERATOR_APPROVED=1 \
  HERDR_CAMPAIGN_WORKER_MARKER_DIR="$marker_dir" \
  HERDR_CAMPAIGN_WORKER_CONTROLLER_STATE="$state" \
  HERDR_CAMPAIGN_WORKER_RUN_ID='OTHER-RUN' \
  HERDR_CAMPAIGN_WORKER_TASK_ID='client-audit' \
  HERDR_CAMPAIGN_WORKER_HOST='controller-local' \
  HERDR_CAMPAIGN_WORKER_KIND='senpi' \
  HERDR_CAMPAIGN_WORKER_MODEL='minimax/MiniMax-M3' \
  HERDR_CAMPAIGN_WORKER_PANE='wBF:p49' \
  HERDR_CAMPAIGN_WORKER_TASK_FILE="$task" \
  HERDR_CAMPAIGN_WORKER_ARTIFACT="$artifact" \
  HERDR_CAMPAIGN_WORKER_LEASE="$lease" \
  HERDR_CAMPAIGN_WORKER_MAX_SECONDS=3600 \
  fm_campaign_worker_create_marker 2>&1
) || status=$?
[ "$status" -ne 0 ] || fail 'marker creation accepted a mismatched run ID'
assert_contains "$bad_out" 'run_id' 'mismatched run ID diagnostic was not field-specific'

sed -i "s/^expires:.*/expires:$(( $(date +%s) - 1 ))/" "$marker"
status=0
expired_out=$(
  HERDR_CAMPAIGN_WORKER_MARKER_DIR="$marker_dir" \
  HERDR_CAMPAIGN_WORKER_CONTROLLER_STATE="$state" \
  HERDR_CAMPAIGN_WORKER_PANE='wBF:p49' \
  HERDR_CAMPAIGN_WORKER_KIND='senpi' \
  HERDR_CAMPAIGN_WORKER_MODEL='minimax/MiniMax-M3' \
  fm_campaign_worker_validate_marker "$marker" "$state" 2>&1
) || status=$?
[ "$status" -ne 0 ] || fail 'validator accepted an expired marker'
assert_contains "$expired_out" 'expires' 'expired marker diagnostic was not explicit'
assert_absent "$expired_out" 'bounded task bytes' 'validator exposed task contents'
pass 'run identity and expiry mismatches fail closed without exposing task content'

printf 'ALL TESTS PASSED\n'
