#!/usr/bin/env bash
# fm-controller-pending.sh - report notes written for Controller but NOT yet
# transmitted. Any output means work is outstanding and must not be reported as
# done.
#
# ENFORCEMENT, NOT INTENTION. Firstmate stated "sending" about a capacity report
# and did not send it. Nothing caught that. This check makes an unsent note a
# visible, wakeable condition, so the same omission cannot pass silently a second
# time.
#
# Detection: every .md in the comms outbox whose content hash is absent from the
# outbound hash ledger was written but never recorded as transmitted.
#
# Usage: fm-controller-pending.sh
# Exit: 0 nothing pending, 1 something pending (message on stdout)
set -u

FM_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"
OUTBOX="$FM_HOME/BRANDON-COMPUTE-COMMS/from-brandon-compute"
LEDGER="$FM_HOME/state/.controller-inbox-outbound"

[ -d "$OUTBOX" ] || exit 0

pending=0
for f in "$OUTBOX"/*.md; do
  [ -f "$f" ] || continue
  h=$(sha256sum -- "$f" 2>/dev/null) || continue
  h=${h%% *}
  if [ ! -f "$LEDGER" ] || ! grep -Fqx -- "$h" "$LEDGER"; then
    printf 'unsent-to-controller: %s sha256=%s\n' "$(basename "$f")" "$h"
    pending=1
  fi
done

if [ "$pending" = 1 ]; then
  printf 'ACTION: transmit with bin/fm-to-controller.sh <file> <name> before reporting this work as done.\n'
fi
exit "$pending"