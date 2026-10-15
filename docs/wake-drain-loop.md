# Wake drain loop — every wake, not the first

**Date:** 2026-10-15
**Status:** owning protocol is `docs/supervision-protocols/pi.md` step 1. This is the reasoning and the evidence.

## The failure

A Controller message was delivered while a second `check:` wake arrived in the same watcher cycle.
Firstmate drained once, acted on the wake it read, and proceeded. The Controller message was not acted on
until the Captain prompted it.

Captain's words: **"u never got the message till i prompted u the loop is sticking"**.

He was right.

## It was not a pickup failure

Ruled out by measurement, not assumption:

| check | result |
|---|---|
| inbound routes watched | 5, content-hash deduplicated — verified by canary |
| `controller-inbox.check.sh` registered and trust-bound | yes |
| watcher heartbeat | seconds, not stale |
| wakes delivered in the failing cycle | **two** |

The message arrived. The wake naming it was emitted. **Firstmate consumed only one wake and dropped the other.**

## Why one drain is wrong

`fm-wake-drain.sh` empties what it returns and prints the records. A watcher cycle can enqueue several wakes
before firstmate is invoked — a `check:` per registered check script that fired, plus any signal. Draining once
and reading the first line is a partial read presented as a complete one.

## The rule

**Drain until the drain is empty, and act on every record it names.**

```bash
while :; do
  out=$(bash bin/fm-wake-drain.sh 2>&1)
  [ -z "$out" ] && break
  # handle every record in $out, then drain again
done
```

If it does not converge, say so rather than proceeding on what was read so far.

## Generalisation

This is the same failure shape as four others from the same night: acting on one signal instead of checking
two.

| one signal | the check that catches it |
|---|---|
| tmux empty | `herdr workspace list` |
| note written | outbound hash ledger — did it transmit |
| branch has commits | `git merge-base --is-ancestor` against origin/main |
| idle pane | the task's status tail and artifacts |
| first wake drained | drain again until empty |

The pattern: **a single observation is not a state.** Each row above failed because one convenient signal was
treated as proof of a larger claim.
