# The reliability trio is blocked on four things that are all yours or the harness's, not the workers'

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`

Four entries have been sitting in_flight for three days. I checked every one against its own status rather than
the backlog label. All four name a real external dependency. None is a worker failing to do its job.

```
reliability-routing-20261012      blocked: exact Controller source handoff is absent; current source/delivery
                                  admission remains unresolvable          -> needs YOUR handoff
reliability-reporting-20261012    blocked: focused test and required completion attestation could not run
                                  because shell execution is denied      -> harness capability
reliability-permission-20261012   blocked: shared decision-hold completion gate requires primary-home backlog
                                  operation outside the permitted write set -> write-scope decision
controller-watcher-tdd            needs-decision: No-mistakes lint reports four out-of-scope warnings; green PR
                                  checks also need the skipped p...      -> a decision
```

Their reports are complete: 50, 38, 52 and 81 lines. The work is done; the gate is not passed.

## The shell-denial gap is now four separate incidents

`reliability-reporting-20261012` (3 days old), `provider-cap-20261014`, `worklocation-reland-20261014`, and
the two agents that produced the order-delivery and wake-drain recoveries. **Five tasks, across three days,
could not run their own tests.** That is not a briefing problem and I have stopped treating it as one.

`--worklocation` is the same class: it amends the brief but not the tool sandbox, so an authorised path is
still refused. Two more tasks hit that.

## What I am asking, concretely

1. **The Controller source handoff** for `reliability-routing-20261012`. It cannot resolve admission without it.
2. **The shell allowlist**, or a sanctioned way to run a test suite from a worker. Five tasks, three days.
3. **A decision on `controller-watcher-tdd`** - four lint warnings described as out-of-scope. Dismiss them or
   fix them; the task cannot proceed green otherwise.
4. **The write-scope question** for `reliability-permission-20261012`: whether a secondmate may operate the
   primary backlog, or whether the design should stop requiring it.

## What I am not doing

Not closing these, and not re-dispatching them into the same four walls. Their reports are complete and their
blockers are named. Re-running them would produce identical refusals and would look like progress while
changing nothing.

That is the specific pattern I spent tonight eliminating, and these four are the remaining instances of it.
