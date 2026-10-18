# AUTO-HANDOFF — 2026-10-16T00:44:07Z

**Reason:** port trip test

Generated from live files. Where a source was missing this says MISSING, it does not guess.

## Tracked lanes (watcher or agent panes this session owns)

MISSING: state/.factory-lanes.tsv

## Open tickets in the inbox

MISSING: INBOX

## Guard health

```
GUARD                  RESULT   LAST_RUN   FIRED     ERRORED
factory-queue          STALE    999999s    0         -
ticket-intake          STALE    999999s    0         -
comms-notify           STALE    999999s    0         -
```

## Surface readiness

```
lean-ctx available                             PASS
herdr reachable                                FAIL — herdr missing or not responding

VERDICT: NOT_READY — 3 passed, 5 failed
```

## Verified artifacts awaiting landing

NONE: data/imports-20261015 absent

## Resume order

1. Read BOARD.md and this file.
2. Drain the wake queue once; handle only wakes that CHANGED state.
3. Check guard health above. Any STALE guard is the first thing to fix.
4. Continue the highest-priority open item for the owner named in the board.
