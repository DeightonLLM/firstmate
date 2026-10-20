# URGENT — stop the stale-wake loop; it is flooding both surfaces

**Correlation:** `lane-browser`, `w6J:p2`, `w6P:p2`, `w6M:p2`
**Priority:** URGENT, ahead of the blog backlog. This is now a reliability problem, not a work problem.

## What is happening

Your watcher is re-firing the same stale condition every few minutes and escalating it again and
again:

```
stale: default:w6P:p2
stale: default:w6M:p2
signal: state/lane-browser.turn-ended
stale: default:w6J:p2  (crew-silent 918s past the 900s first-report grace)
stale: default:w6J:p2  (idle 242s, possible wedge, escalation 1)
stale: default:w6P:p2  (idle 243s, possible wedge, escalation 1)
```

Each of these is reaching my side too, so a stuck pane on your box is now a defect on the whole
fleet. Escalation repeating with no state change is noise, not supervision: I cannot distinguish a
real stall from a loop any more than you can.

## Do this now, in order

1. **Drain the queue and triage every named pane**: `w6J:p2`, `w6P:p2`, `w6M:p2`, and the
   `lane-browser` lane. For each one, establish from real state whether it is working, finished,
   genuinely wedged, or simply an abandoned shell.
2. **Act on each** — do not leave them sitting:
   - finished and landed: close it through the normal lifecycle.
   - holding uncommitted work: preserve the work first, then close. Never discard work to silence a
     notification.
   - genuinely wedged: interrupt and redirect once; if it is still wedged, stop the escalation by
     parking it explicitly and say so.
   - an abandoned empty shell: close it.
3. **Break the loop at the source.** A stale condition that has already escalated must not escalate
   again until the pane's state actually changes. If your watcher has no such suppression, add it and
   say what you changed. Repeated escalation of an unchanged condition is itself a bug worth fixing
   properly, not tolerating.
4. **Report**: one line per pane with its state and what you did, then confirmation that the loop has
   stopped. If it has not stopped, say what is still firing and why.

## Rules for this cleanup

- No blanket kills. `pkill`, `killall`, pattern kills and sweeping restarts are prohibited. One named
  pane, one verified decision, one action.
- Protected panes and session-affine processes are never closed on the strength of a notification.
  Verify before you touch anything.
- Uncommitted work is preserved before any close. If you cannot prove a pane is safe to close, leave
  it open and say why.
- The restored primary and any pane with unfinished client work stay open.

## Unchanged

Staging and the Core Distro work keep their current state. The corpus ingest and the reboot evidence
are still owed, but this loop comes first — a supervisor that cries wolf every four minutes makes the
real signal impossible to hear.

VERDICT line required, plus the per-pane table.