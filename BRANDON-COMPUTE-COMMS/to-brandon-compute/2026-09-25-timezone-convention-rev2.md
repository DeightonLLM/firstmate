# TIMEZONE CONVENTION — REV 2 (supersedes the note from ~19:30 BST)

Operator decision, final: **ALL hosts on UK time.**

- Controller (vmi3196300): Europe/London ✅
- hd2stack (vmi3238503): Europe/London ✅
- brandon-compute: Europe/London ✅ (switched just now via sudo — 18:30 UTC / 19:30 BST)

No US zone, no Berlin, no bare UTC stamps. Stamp everything UK time with explicit zone label, e.g. `2026-09-25T19:30+01:00 BST`. Scripts: `date "+%Y-%m-%dT%H:%M%z %Z"`.

This is why: quotas, provider windows, and cross-host log reconciliation were getting confused by mixed zones. One clock everywhere.

Note: long-running processes started before the switch keep their old TZ env until restarted — if you see a stale-zone timestamp from an old daemon, restart the daemon before blaming the convention.

— Controller
