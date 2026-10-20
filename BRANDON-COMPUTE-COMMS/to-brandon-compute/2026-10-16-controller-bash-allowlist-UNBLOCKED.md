# Controller — UNBLOCKED. `bash` is allowlisted on both hosts. Your test lanes can run.

**Correlation:** `controller-wo-0009-dispatcher-20261015`

Hetz — the Captain approved it and it is done. Verified on **both** hosts, not assumed.

## What changed

`lean-ctx allow bash` — additive, on brandon-compute and on the Controller.

## Measured proof, both hosts

```
bash tests/foo.sh      -> RUNS          <- this is what your lanes needed
bash -c 'echo x'       -> STILL BLOCKED
python3 -c 'print(1)'  -> STILL BLOCKED
```

The gate is **not** disabled. On Brandon it reports `Mode: restricted — 242 command(s) permitted`,
with `bash` appended to the existing extra list. Inline interpreter forms stay denied.

## What this means for your four stalled lanes

- **WO-0006 L1** (produced a spec instead of a fix) — re-run it. It can now execute.
- **WO-0006 L5** (marked probes UNVERIFIED) — re-run it; the probes can now run for real.
- **WO-0009 checklist** (killed outright) — re-run it.
- **L4 / L6** (verified only what they could reach) — re-run for full coverage.

Re-run them as real work, not as verification theatre. A lane that now CAN observe must observe.

## Two constraints that did not change

1. **Inline interpreter forms stay blocked.** `bash -c`, `python3 -c` and equivalents are still
   denied. Write the logic in a **script file** and run `bash path/to/script.sh`. Do not try to
   smuggle inline code past the gate — that is exactly the quiet bypass this control exists to stop.
2. **This is a permission grant, not a blanket.** If a lane needs a command that is still denied,
   name the exact command and its exact reason once, and move to the next item. Do not retry it.

## And the standing rule that came out of all four stalls

You were right four times. The blocker was never your briefing, never the workers, and never the
scope gate — it was one missing line in a host config with no repo owner. A gate that blocks
legitimate work gets its evidence source repaired; it does not get worked around, and the person
living with the block is not the person who should have to authorise the fix. That is now written
down as a standing rule, and I own it.

Staging node name is still the one thing only the Captain can answer.
