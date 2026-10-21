#!/usr/bin/env bash
# Read-only installed contract checks for the Controller resource audit.
#
# Contract: 69 -> CAPACITY_OK, 70 -> CAPACITY_EARLY_WARNING,
# 75 -> CAPACITY_REVIEW_REQUIRED, 80 -> CAPACITY_BLOCK_NEW_PLACEMENT.
# The Captain's hard ceiling is 80% root usage: at 80% the disk is blocked for
# new placement, and the early warning at 70% is the window in which there is
# still room to reclaim.
set -euo pipefail
SCRIPT=/root/bin/controller-resource-audit.sh
TIMER=/etc/systemd/system/controller-resource-audit.timer
SERVICE=/etc/systemd/system/controller-resource-audit.service
PASS=0
assert_eq() {
  local got=$1 expected=$2 label=$3
  if [ "$got" != "$expected" ]; then
    printf 'not ok - %s: expected <%s>, got <%s>\n' "$label" "$expected" "$got" >&2
    exit 1
  fi
  PASS=$((PASS+1))
  printf 'ok - %s\n' "$label"
}
assert_has() {
  local file=$1 needle=$2 label=$3
  if ! grep -Fq -- "$needle" "$file"; then
    printf 'not ok - %s: missing <%s> in %s\n' "$label" "$needle" "$file" >&2
    exit 1
  fi
  PASS=$((PASS+1))
  printf 'ok - %s\n' "$label"
}
[ -x "$SCRIPT" ] && [ -r "$TIMER" ] && [ -r "$SERVICE" ]
assert_eq "$("$SCRIPT" --print-verdict --root-used-percent 69)" CAPACITY_OK '69 percent is below the early warning threshold'
assert_eq "$("$SCRIPT" --print-verdict --root-used-percent 70)" CAPACITY_EARLY_WARNING '70 percent early warning boundary'
assert_eq "$("$SCRIPT" --print-verdict --root-used-percent 74)" CAPACITY_EARLY_WARNING '74 percent is still early warning, below review'
assert_eq "$("$SCRIPT" --print-verdict --root-used-percent 75)" CAPACITY_REVIEW_REQUIRED '75 percent review boundary'
assert_eq "$("$SCRIPT" --print-verdict --root-used-percent 79)" CAPACITY_REVIEW_REQUIRED '79 percent is still review, not block'
assert_eq "$("$SCRIPT" --print-verdict --root-used-percent 80)" CAPACITY_BLOCK_NEW_PLACEMENT '80 percent placement block boundary'
assert_eq "$("$SCRIPT" --print-verdict --root-used-percent 85)" CAPACITY_BLOCK_NEW_PLACEMENT '85 percent placement boundary'
# The guard owns no thresholds: it asks this script for the verdict, so the
# verdict subcommand is the contract between the two and must stay callable.
assert_eq "$("$SCRIPT" verdict 69)" CAPACITY_OK 'verdict subcommand: 69 percent is below the early warning threshold'
assert_eq "$("$SCRIPT" verdict 70)" CAPACITY_EARLY_WARNING 'verdict subcommand: 70 percent early warning boundary'
assert_eq "$("$SCRIPT" verdict 74)" CAPACITY_EARLY_WARNING 'verdict subcommand: 74 percent is still early warning, below review'
assert_eq "$("$SCRIPT" verdict 75)" CAPACITY_REVIEW_REQUIRED 'verdict subcommand: 75 percent review boundary'
assert_eq "$("$SCRIPT" verdict 79)" CAPACITY_REVIEW_REQUIRED 'verdict subcommand: 79 percent is still review, not block'
assert_eq "$("$SCRIPT" verdict 80)" CAPACITY_BLOCK_NEW_PLACEMENT 'verdict subcommand: 80 percent placement block boundary'
assert_eq "$("$SCRIPT" verdict 85)" CAPACITY_BLOCK_NEW_PLACEMENT 'verdict subcommand: 85 percent placement boundary'
assert_eq "$("$SCRIPT" verdict 96)" CAPACITY_BLOCK_NEW_PLACEMENT 'verdict subcommand: 96 percent placement block'
if "$SCRIPT" verdict 200 >/dev/null 2>&1; then
  printf 'not ok - verdict subcommand: an out-of-range percent must be refused\n' >&2
  exit 1
fi
PASS=$((PASS+1))
printf 'ok - verdict subcommand: an out-of-range percent is refused\n'
assert_has /root/bin/capacity-guard '"$AUDIT" verdict "$DISK_PCT"' 'the guard asks the audit for the verdict subcommand'
assert_eq "$("$SCRIPT" --next-run 2026-10-15T06:00:00Z)" 2026-10-15T12:00:00Z 'exact six-hour boundary advances to next interval'
assert_has "$TIMER" 'OnCalendar=*-*-* 0/6:00:00' 'timer declares six-hour cadence'
assert_has "$SERVICE" 'ExecStart=/root/bin/controller-resource-audit.sh --report-dir /root/agent-work/resource-audit' 'service uses canonical report directory'
assert_has "$SERVICE" 'ReadWritePaths=/root/agent-work/resource-audit' 'service write access is limited to canonical report directory'
assert_eq "$("$SCRIPT" --check-timer-unit "$TIMER" | cut -d: -f1)" CADENCE_OK 'sampler accepts installed timer cadence'
printf '\npassed=%s failed=0\n' "$PASS"
