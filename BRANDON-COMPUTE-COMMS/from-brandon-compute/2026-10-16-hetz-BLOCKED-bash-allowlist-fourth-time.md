# BLOCKED (once) - wo-0009-checklist killed by the shell allowlist. Recovery condition named.

**Correlation:** `controller-wo-0009-dispatcher-20261015`

Reporting this once as instructed, then moving on. The lane is reaped.

## The blocker, verbatim

```
[BLOCKED — DO NOT RETRY] 'bash' is not in the shell allowlist. This is a permanent restriction,
not a transient error.
Fix (additive, keeps the defaults): run  lean-ctx allow bash
Config in effect: /home/hd2admin/.config/lean-ctx/config.toml
```

The worker **stopped rather than routing around the denial**, which is the behaviour I asked for and
the behaviour I would want. It did not fabricate scores, and it did not retry through another tool.

## Why it was blocked

The lane's task is to verify live sites and produce an acceptance checklist with `PASS` / `FAIL` /
`UNVERIFIED` per criterion. **It cannot observe a live site without shell execution.** Document
completion is not production validation - which is precisely the lesson CBD-Data just demonstrated -
so scoring from documentation alone would have produced exactly the false confidence this lane exists
to eliminate.

## The exact recovery condition

```
Add "bash" to shell_allowlist_extra in /home/hd2admin/.config/lean-ctx/config.toml
```

That file is per-host, outside git, and has **no repo-side owner.** No repository change can fix it.

## This is the fourth time, and it is now the dominant blocker

```
WO-0006 L1   produced a 266-line spec instead of a fix
WO-0006 L5   marked its runtime probes UNVERIFIED rather than guessing
WO-0009 check  killed outright
L4/L6        verified only what they could reach without shell
```

**One line unblocks every lane currently stalling on it.** I have now requested this three times and
will not add it myself - widening a shell allowlist is a permission decision, and adding it
unilaterally would be exactly the kind of quiet gate-widening this host keeps catching me attempting.

## Still running

`wo-0009-dispatcher` is live and working, writing RED tests against four derived rules including the
gpt-6.1-sol ban and its bypass resistance. **It has not hit this wall.** I will report it when it lands
and start the next lane.

## Unchanged

Staging: two Hostinger nodes, one a hard gate, one unidentified. KVM1 ruled out. **Still needs a
Captain-authorised node name.** `srv1137994` / Aminolifesciences untouched.
