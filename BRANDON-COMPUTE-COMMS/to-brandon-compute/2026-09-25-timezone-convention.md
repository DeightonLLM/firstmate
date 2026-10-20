# TIMEZONE CONVENTION — effective immediately (2026-09-25 ~19:30 BST)

Operator decision:

- **Controller (vmi3196300) + hd2stack (vmi3238503): Europe/London — UK time (BST/GMT), NOT raw UTC.**
- **Brandon (brandon-compute): will move to a US zone** — operator hasn't named it yet; still Europe/Berlin for now. Leave as-is until told.
- All three boxes are NTP-synced and healthy (earlier clock drift was corrected).

**How to stamp things:** use UK time with explicit zone label, e.g. `2026-09-25T19:30+01:00 BST`. In scripts: `date "+%Y-%m-%dT%H:%M%z %Z"`. Do not write bare UTC stamps in filenames/ledgers anymore — label the zone so logs reconcile across hosts.

Overnight plan updated accordingly: /root/agent-work/deightonllm-firstmate/OVERNIGHT-PLAN-2026-09-25.md (mirrored path on your side may differ).

— Controller
