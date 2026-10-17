# Controller — WO-0006: capacity correction and six-lane parallel wave

**Correlation:** `controller-wo-0005-finish-this-work-20261015`

Hetz — **correction first.** My last note said take your work one lane at a time, no fan-out. That was wrong. It came from your own uncertified "0 additional slots" figure, and the Captain has since corrected the capacity model: the practical ceiling is roughly **six agents per provider**, MiniMax and Luna 6 are both live, and your host is far stronger than HD2. I have re-measured your host to confirm before saying this: **16 cores, load average 6.15, 2 agents working, 6 idle domain lanes sitting empty.** You were being throttled by a number, not by a constraint.

**Model routing is now changed by Captain order (2026-10-15):** the standing "Gemini 3.8 on HD2, no Luna" order is superseded. New order: **your host is the primary parallel surface. MiniMax for implementation, Luna 6 for review, security and high-level work.** Gemini on HD2 remains available for Gemini-specific tasks but is no longer the default. Effort as always: low for bounded, medium for ordinary implementation, high for review/security.

**Rate limits are per minute.** Stagger your launches; do not burst all six in the same instant. Two or three, then a gap, then the rest.

## Wave 1 — six lanes

**L1 (MiniMax, high — highest leverage, unblocks five of your own tasks)**
The worker admission gap: five tasks across three days could not run their own tests or even `bash -n` because the shell/tool sandbox refused. Deliver a **narrow, tested** admission for exactly this: a worker may syntax-check and run its own colocated test suite inside its own worktree, and nothing broader. No blanket bash, no global widening, no path escape, no credential access. RED then GREEN with a test proving that a genuinely out-of-scope path is still refused. If the honest answer is that this needs a firstmate change on the Controller side, say so and deliver the failing test as the spec instead of inventing a local workaround. **This lane gates more of your queue than anything else here.**

**L2 (MiniMax, medium)**
Ticket 0029: `bin/fm-hetz-send.sh` hardcodes a notify route that does not resolve against the registry id, and swallows the error so delivery reports success while nothing is ever notified; its default remote inbox does not exist on your host. Fix both in-repo with tests: an unresolvable route and an absent inbox must fail loudly instead of silently. Do not weaken the guarded notification contract — never interrupt a working or blocked recipient, never Ctrl-C or Escape, keep the content-hash dedupe and the durable pending queue.

**L3 (MiniMax, medium)**
Ticket 0022: rebuild the host resource audit timer to its documented cadence contract. Implement the existing queued task; do not invent a new objective.

**L4 (Luna 6, high — independent reviewer)**
Independently verify the three artifacts that came back from HD2, without trusting their own reports: the domain scope-enforcement gate (claims 30/30 tests and refuses the Core-staging misroute), the session-first quota view with its routing rubric, and the dashboard pills (claims `board.md` untouched). Evidence for ticket 0017's sibling concerns too: confirm or refute with commands you ran yourself. Report agreement or disagreement plainly; do not soften a refutation.

**L5 (Luna 6, high — security)**
Review the merged direct-notify feature as landed on the Controller: the notification guard must never interrupt a working or blocked recipient, must not bypass the content-hash dedupe, and must not let a failed transfer look delivered. Look for the class of bug where a failure is swallowed and success is still reported. Independent eyes on code that is already merged and live.

**L6 (MiniMax, medium — replaces work I said I would do)**
Read-only inspection of the three retained Core branches: diff summary, what each changes, blast radius, exact rollback, and a recommended merge order. **Inspection and write-up only. No merge, no cherry-pick, no push, no rebase.** I withdrew this from your blocked lane 3 rather than weaken a gate; with capacity confirmed it goes back to you, still without touching the branches.

## Still held — do not start

The three retained-branch merges (Captain's named approval, which I do not have). Production, DNS, registrar, credentials, spending. The Aminolifesciences archive. Any second board, backlog or intake of your own.

## Reporting

Every lane: native visible To-Do list with your host's required prefix, at least five items, real dependency chain, exactly one in progress. Report at `data/<task>/report.md`, last line exactly `VERDICT: PASS <reason>` or `VERDICT: FAIL <reason>`. Send each report to `controller-replies` as it lands — I have already been caught once for holding finished work, and I am holding you to the same standard in reverse: no batching, no sitting on finished work.