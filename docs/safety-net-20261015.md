# Safety-net design: every guard must prove it fired

Adopted 2026-10-15. This governs all enforcement on every surface.

## The failure this document exists to prevent

Guards were built that passed their tests, read as working, and **never fired in production**.
Concretely, on 2026-10-15: the STALLED no-silent-stop watchdog was written, registered,
syntax-checked, bound to its trust record — and never emitted once across three separate trigger
attempts. Nobody could tell. Including me.

A guard that cannot prove it fires is decoration. It is worse than no guard, because it creates
confidence where there is none.

## Rule 1 — attestation, not assumption

Every guard MUST write one attestation record per invocation, whether or not it fires:

    state/attestations/<guard-name>.tsv   epoch<TAB>pid<TAB>result<TAB>detail

`result` is one of `FIRED`, `CLEAR`, `ERROR`, or `MISSING`. A guard with no recent attestation
row is reported as `MISSING`, not as healthy. Absence of evidence is not evidence of health — the
same rule that governs host identity now governs our own tooling.

## Rule 2 — prove it fires before calling it done

No guard is reported working, merged, or handed over until it has been **demonstrably tripped**
in a live run, with the `FIRED` row and the output captured as evidence. "Tests pass" is not
proof of firing. A green test suite proves the logic, not that the scheduler, the path
resolution, or the registration actually reach it.

Required before any guard is called live:

1. **Trip test** — deliberately create the condition in a sandbox and observe a real `FIRED`
   attestation and real output. Not a mock of the guard's own internals.
2. **Silent test** — with no condition present, observe `CLEAR` and **no output**.
3. **Idempotency test** — the same condition twice fires once.
4. **Attestation visible** — the row appears in the attestation ledger within one poll interval.

## Rule 3 — one place to see what is actually live

A single status surface answers, per guard: last run, last result, whether it has ever fired, and
when it last fired. Captain must never have to ask whether a guard is working, and must never
learn of a broken guard only when the thing it guards fails.

## Rule 4 — guards degrade to loud, never to silent

If a guard cannot run — missing binary, unreadable path, expired trust binding, blocked quota —
that is a `ERROR` or `MISSING` attestation and a visible alert. It is never an excuse to proceed
quietly, and never grounds to disable the guard.

## Rule 5 — the degradation trip-wire

Two behaviours end a turn and force a handoff, because both were observed in the wild:

1. **Repetition** — re-verifying or re-answering something already settled this session.
2. **No-change wakes** — replying to a wake whose state did not change.

On either, write the handoff, hand back control, and do not continue. This exists because the
2026-10-15 session degraded at 37% of context: outputs repeated, checks re-ran, focus narrowed.
Compaction was never the cause and would never have fixed it.

## Rule 6 — state lives in files, not in memory

Anything needed to resume belongs on disk before the session ends. If the operator has to ask
"what were we doing", the state was not recorded correctly.

## Rollout, step by step

1. Attestation primitive + status surface, built and trip-tested on the Controller.
2. Attach attestation to the existing registered checks (collect/reap, queue, stall, intake).
3. Degradation trip-wire, with its own trip test.
4. Auto-handoff writer invoked by the trip-wire and by pre-compaction.
5. Port the whole layer to hd2stack and brandon-compute; trip-test on each surface independently.

Each step ships with its evidence or it does not ship. A step that cannot trip its own guard is
rolled back, not documented around.