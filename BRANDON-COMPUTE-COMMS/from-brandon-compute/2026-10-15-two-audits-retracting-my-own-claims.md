# Two audits complete. Both contradict claims I made. Here is the corrected picture.

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`

I asked for adversarial audits of my own work rather than grading my own homework. Both refused to give me the
answer I wanted, and both were right. Nothing below is a new finding I am reporting first - it is me
retracting things I said earlier tonight.

## 1. `9601685d` is NOT landed. I said it was, repeatedly.

```
9601685d  "fix: stream fleet JSON into jq"    ancestor of main: NO (exit=1)
                                            still on: fm/fleet-snapshot-arg-limit
```

I reported this commit as landed for much of tonight. It came from a status line. A `git merge-base
--is-ancestor` says otherwise. **That is the same failure I have made repeatedly - one signal treated as the
state - and this time it was about work I claimed was already finished.**

## 2. `c51cf8d9` also unlanded, and I had never mentioned it

```
c51cf8d9  "Add fm-brandon-queue-push helper and colocated test"  -> overnight/queue-push-helper
```

Visible only because something audited my claims instead of accepting them.

## 3. The work is not lost, and that distinction matters

`973ff553` was verified as the same change as the original `50abe4e0` by tree comparison, under a different
sha. So for the order-delivery feature, the work is present in main and merely re-landed. **That is the
difference between work lost and work re-derived**, and it is why provenance had to be checked at the object
level rather than by commit name.

## 4. Six of seven secondmates are gone. Not misregistered - gone.

```
system-ops          LIVE AND REGISTERED CORRECTLY   (the only one)
elevate-p0-repair   GONE
core-ops            GONE
whoosh-ops          GONE
cbddata-ops         GONE
hetzner-compute     GONE
backup-dr           GONE
```

**No entry is "live but misregistered".** The audit looked for a relocated home and found no evidence tying any
candidate to a registered identity. So these are not stale paths pointing at moved homes; the homes are not
there.

**I have been escalating "five domain experts cannot read their own files" for days.** That was wrong in
substance. Four of them were absent directories presenting as permission errors, and I never checked the
filesystem behind the symptom.

## What I need from you

1. **Are those six decommissioned, or is the registry simply out of date?** I will not seed homes or rewrite
   `data/secondmates.md` on a guess. Until this settles, the seven-lane model is one real lane.
2. **`9601685d` and `c51cf8d9`** - is either wanted in main? I will not port them by copying patches without a
   decision, and I will not call them landed again.
3. The stale `default` decision key that has blocked five scout completions tonight.

## What I am not doing

Not editing the secondmate registry. Not porting unlanded commits. Not forcing attestations. Every one of those
is a decision that is not mine, and I have spent tonight making too many of them alone.
