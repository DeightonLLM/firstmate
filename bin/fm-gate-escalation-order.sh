#!/usr/bin/env bash
# fm-gate-escalation-order.sh - enforce that Crisp-R is contacted FIRST and the
# Captain is the fallback when Crisp-R is unavailable.
#
# WHY THIS EXISTS
# 2026-10-15. Captain first said the escalation loop was broken and asked me to
# stop asking him; I read that as "never contact the Captain" and built the
# inverse gate. He corrected it: "i want iu to contact crispr at all times when
# hes not available contact me simple."
#
# So the rule is an ORDER, not a prohibition:
#   1. Contact Crisp-R at all times. He is the primary route.
#   2. When Crisp-R is unavailable, contact the Captain. He is the fallback.
#
# The real failure was routing AROUND Crisp-R and treating the Captain as the
# default, because he answers. This gate makes the order visible rather than
# leaving it to judgement at 3am.
#
# WHAT IT REPORTS
# - An outbound note to Controller that has not been transmitted: the primary
#   route has an undelivered message, so contact him now rather than the Captain.
# - A recent successful exchange with Controller, which is proof the primary route
#   is working and the Captain should not be used as a substitute.
# - A prolonged lack of Controller delivery, which is precisely the condition
#   under which the Captain IS the correct escalation target.
#
# Exit: 0 always. A gate that refused would wedge supervision.
set -u

FM_HOME="${FM_HOME:-/home/hd2admin/kun-agent-workspace}"
PENDING="$FM_HOME/bin/fm-controller-pending.sh"
STALE_S="${FM_GATE_CONTROLLER_STALE_S:-21600}"

unsent=$(bash "$PENDING" 2>/dev/null | grep -c 'unsent-to-controller' || true)

last_seen=0
for d in /home/hd2admin/controller-replies \
         "$FM_HOME/BRANDON-COMPUTE-COMMS/to-brandon-compute" \
         /home/hd2admin/agent-work/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute \
         /home/hd2admin/agent-work/firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute \
         /home/hd2admin/brandon-inbox; do
  [ -d "$d" ] || continue
  f=$(ls -t "$d"/*.md 2>/dev/null | head -1)
  [ -n "$f" ] || continue
  m=$(stat -c %Y -- "$f" 2>/dev/null) || continue
  if [ "$m" -gt "$last_seen" ]; then last_seen=$m; fi
done

now=$(date +%s)
if [ "$last_seen" -gt 0 ]; then age=$(( now - last_seen )); else age=999999; fi

if [ "${unsent:-0}" -gt 0 ]; then
  printf 'GATE escalation-order: %s note(s) for Controller NOT transmitted.\n' "$unsent"
  printf '  PRIMARY ROUTE: send it to Crisp-R now. bash bin/fm-to-controller.sh <file> <name>\n'
  printf '  Do not substitute the Captain while the primary route is undelivered.\n'
fi

if [ "$age" -le "$STALE_S" ]; then
  printf 'GATE escalation-order: Controller route live (%ss since last delivery). PRIMARY ROUTE.\n' "$age"
  printf '  Contact Crisp-R. Reachability to him is the default, not the exception.\n'
else
  printf 'GATE escalation-order: no Controller delivery for %ss (threshold %ss).\n' "$age" "$STALE_S"
  printf '  Crisp-R is UNAVAILABLE. The Captain is the CORRECT fallback now.\n'
  printf '  Contact the Captain: he said "when hes not available contact me".\n'
fi

exit 0