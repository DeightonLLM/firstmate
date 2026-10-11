#!/usr/bin/env bash
# Campaign workers must not receive the primary-only First Mate session-start
# nudge. That nudge causes a lock-refused worker to replay the primary digest
# instead of executing its marker-scoped task.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NUDGE="$ROOT/bin/fm-sessionstart-nudge.sh"
TURNEND="$ROOT/.senpi/extensions/fm-primary-turnend-guard.ts"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-campaign-worker-session.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

mkdir -p "$TMP_ROOT/state"
# PID 1 is live but is never this shell's ancestor, so this models a genuine
# worker process alongside the lock-holding controller.
printf '1\n' > "$TMP_ROOT/state/.lock"

worker_nudge=$(FM_ROOT_OVERRIDE="$ROOT" \
  FM_HOME="$ROOT" \
  FM_STATE_OVERRIDE="$TMP_ROOT/state" \
  HERDR_CAMPAIGN_WORKER_MARKER="$TMP_ROOT/worker.marker" \
  "$NUDGE" 2>/dev/null) || fail 'campaign worker nudge probe failed'
[ -z "$worker_nudge" ] || fail 'campaign worker received the primary session-start nudge'
pass 'campaign worker suppresses primary session-start nudge'

primary_nudge=$(FM_ROOT_OVERRIDE="$ROOT" \
  FM_HOME="$ROOT" \
  FM_STATE_OVERRIDE="$TMP_ROOT/state" \
  env -u HERDR_CAMPAIGN_WORKER_MARKER "$NUDGE" 2>/dev/null) || fail 'primary nudge probe failed'
case "$primary_nudge" in
  *'session-start:'*) pass 'ordinary primary still receives session-start nudge' ;;
  *) fail 'ordinary primary nudge was suppressed' ;;
esac

guard_source=$(sed -n '1,220p' "$TURNEND")
case "$guard_source" in
  *'isCampaignWorker()'*'if (isCampaignWorker()) return;'*) pass 'primary turn-end guard bypasses campaign workers' ;;
  *) fail 'primary turn-end guard has no campaign-worker isolation' ;;
esac

printf 'CAMPAIGN_WORKER_SESSION_ISOLATION_PASS\n'
