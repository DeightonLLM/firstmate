#!/usr/bin/env bash
# fm-guard-attest-install.sh - install the guard attestation surface on a host.
#
# Two things get installed, and the second one is the point:
#   1. /root/bin/guard-attest          the guard itself (canonical source: this repo)
#   2. $FM_HOME/state/guard-attest.check.sh (+ .check-trust)
#      the watcher-visible poll. The controller watcher runs every registered
#      state/*.check.sh on its CHECK_INTERVAL cadence; this one calls
#      `guard-attest status`, which maintains the operator-facing status file.
#      Without it nothing calls `status` and a STALE verdict is never produced.
#
# The check script prints NOTHING on purpose. Its stdout is the watcher's `check:`
# wake path, and printing the status table on every poll would wake the operator
# every cycle. The delivery is the status file the guard writes, which the
# watcher's signal scan surfaces once per transition.
#
# Usage: fm-guard-attest-install.sh [--dry-run] [--tag <backup-tag>]
#                              [--only guard|check]
#
# --only guard installs just the guard; --only check installs just the
# watcher-visible poll. They are separable because the safe order on a live
# host is guard first (so the registered guards start refreshing their
# liveness), one watcher cycle later, then the poll. Installing the poll first
# would report every registered guard STALE exactly once, on the strength of a
# timestamp the old guard froze.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_GUARD="$SCRIPT_DIR/fm-guard-attest.sh"
FM_HOME="${FM_HOME:-/root/agent-work/deightonllm-firstmate}"
TARGET_GUARD="${FM_GUARD_ATTEST_BIN:-/root/bin/guard-attest}"
STATE_DIR="${FM_ATTEST_STATE_ROOT:-$FM_HOME/state}"
CHECK_ID="guard-attest"
CHECK_SCRIPT="$STATE_DIR/$CHECK_ID.check.sh"
CHECK_TRUST="$STATE_DIR/$CHECK_ID.check-trust"
DRY_RUN=0
ONLY="both"
TAG="stale-guard-$(date +%Y%m%d)"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --only) ONLY="${2:?--only needs guard|check|both}"; shift 2 ;;
    --tag) TAG="${2:?--tag needs a value}"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -f "$SOURCE_GUARD" ] || { printf 'missing source guard: %s\n' "$SOURCE_GUARD" >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { printf 'sha256sum unavailable\n' >&2; exit 1; }

CHECK_BODY=$(cat <<'CHECK_EOF'
#!/usr/bin/env bash
# guard-attest.check.sh - watcher-visible poll of the guard attestation surface.
#
# Prints nothing: the delivery is the operator-facing status file the guard
# maintains (state/guard-attest.status). A captain-relevant verb in that file is
# what the watcher's signal scan turns into an operator wake, so this poll must
# never put a verdict on stdout - stdout is the watcher's `check:` wake path and
# would wake the operator on every cycle.
set -u
GUARD_ATTEST="${FM_GUARD_ATTEST_BIN:-/root/bin/guard-attest}"
[ -x "$GUARD_ATTEST" ] || exit 0
"$GUARD_ATTEST" status >/dev/null 2>&1 || true
exit 0
CHECK_EOF
)

install_guard() {
  mkdir -p "$(dirname "$TARGET_GUARD")"
  if [ -f "$TARGET_GUARD" ]; then
    cp -p "$TARGET_GUARD" "$TARGET_GUARD.bak-$TAG"
    printf 'backup: %s.bak-%s\n' "$TARGET_GUARD" "$TAG"
  fi
  cp "$SOURCE_GUARD" "$TARGET_GUARD.tmp.$$"
  chmod 0700 "$TARGET_GUARD.tmp.$$"
  mv -f "$TARGET_GUARD.tmp.$$" "$TARGET_GUARD"
  printf 'installed guard: %s\n' "$TARGET_GUARD"
}

install_check() {
  mkdir -p "$STATE_DIR"
  local tmp="$CHECK_SCRIPT.tmp.$$"
  printf '%s\n' "$CHECK_BODY" > "$tmp"
  chmod 0700 "$tmp"
  mv -f "$tmp" "$CHECK_SCRIPT"
  local hash
  hash="$(sha256sum "$CHECK_SCRIPT" | cut -d' ' -f1)"
  local ttmp="$CHECK_TRUST.tmp.$$"
  printf 'fm-custom-check-v1\n%s\n' "$hash" > "$ttmp"
  chmod 0600 "$ttmp"
  mv -f "$ttmp" "$CHECK_TRUST"
  printf 'installed check: %s (sha256:%s)\n' "$CHECK_SCRIPT" "$hash"
}

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'dry-run: would install %s -> %s\n' "$SOURCE_GUARD" "$TARGET_GUARD"
  printf 'dry-run: would install %s + %s\n' "$CHECK_SCRIPT" "$CHECK_TRUST"
  exit 0
fi

[ "$ONLY" = "guard" ] || [ "$ONLY" = "both" ] || [ "$ONLY" = "check" ] || {
  printf 'unknown --only value: %s\n' "$ONLY" >&2; exit 2; }

if [ "$ONLY" = "guard" ] || [ "$ONLY" = "both" ]; then
  install_guard
fi
if [ "$ONLY" = "check" ] || [ "$ONLY" = "both" ]; then
  install_check
fi

printf '\nverify:\n'
printf '  %s --selftest\n' "$TARGET_GUARD"
"$TARGET_GUARD" --selftest | tail -2
printf '\nnext: the watcher polls %s on its CHECK_INTERVAL cadence; a STALE/MISSING\n' "$CHECK_SCRIPT"
printf '      verdict is written to %s/guard-attest.status and wakes the operator.\n' "$STATE_DIR"
