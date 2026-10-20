---
name: tdd-red-green-refactor
description: Enforce a test-first red-green-refactor loop for behavior changes, bug fixes, and refactors; require executable evidence before acceptance and stop cleanly when TDD cannot be demonstrated.
---

# TDD: red → green → refactor

Use this skill for implementation work that changes executable behavior. It is
not required for documentation-only edits, static planning, or emergency
containment; those still need their appropriate validation. Do not turn a
missing test harness into permission to fabricate a green result.

## Operating contract

1. **Preflight** — State the behavior/acceptance criterion, the smallest
   relevant test command, and the evidence path. Read repository instructions
   first. Under `/root`, use `lean-ctx` for reads, searches, listings, and shell
   commands. Use the To-Do List extension and create at least these dependent
   items before the first task action: preflight, red proof, green change,
   refactor verification, and postflight/closeout.
2. **RED** — Add or change the narrowest test that expresses the missing or
   broken behavior. Run the targeted test before changing implementation code.
   Record the command, exit status, and a sanitized failure signature. The
   failure must be caused by the requested behavior, not by a broken harness or
   an unrelated baseline failure. If a meaningful red proof cannot run, stop as
   `TDD_BLOCKED` and name the exact missing fixture/tool/authority.
3. **GREEN** — Make the smallest implementation change that satisfies the red
   test. Do not weaken, delete, skip, reorder, or broaden the assertion merely
   to obtain a pass. Run the targeted test, then the narrow relevant suite.
4. **REFACTOR** — Refactor only after green. Preserve behavior and test intent;
   make one coherent refactor at a time and rerun the relevant tests after each
   meaningful change. If refactoring breaks green, revert the refactor or fix it
   before continuing; never leave a red tree at handoff.
5. **POSTFLIGHT** — Run the full relevant test/lint/type/static suite, inspect
   the final diff, and record red, green, refactor, and final results in the
   task's existing evidence artifact. Include hashes when the task requires
   pinned evidence. Never put secrets, tokens, cookies, or raw production
   responses in the evidence.

## Agent-loop rules

- Keep one implementation owner for a test/change. A separate checker may
  inspect the test and evidence read-only, but must not share the implementation
  context or silently edit it.
- A reviewer must verify that the red command genuinely failed before the
  implementation change, the green command passed afterward, and the final
  suite still exercises the behavior. A report that only says “tests pass” is
  insufficient TDD evidence.
- Use deterministic fixtures, mocks, or local fakes for external services.
  Do not make live network, credential, deployment, database, or browser calls
  just to manufacture a red or green result.
- Keep changes bounded to the declared write boundary. Do not use unrelated
  cleanup as a refactor phase, and do not run competing edits in parallel.
- Preserve existing failing tests and report unrelated baseline failures
  separately. Do not hide failures with `|| true`, broad skips, altered test
  discovery, or environment-dependent assertions.

## Stop conditions

Stop with `TDD_BLOCKED` when the test cannot execute, the failure is unrelated
and cannot be isolated safely, required authority or credentials are missing,
or the requested change would cross its declared boundary. Stop with
`REVISION_REQUIRED` when red/green/refactor evidence is missing, the test was
weakened, or the final relevant suite is not green. Resume only after the
specific condition changes; do not repeat an unchanged command loop.

## Handoff format

Report these four checkpoints tersely:

- `RED`: test path/command, expected failure class, exit status.
- `GREEN`: implementation paths, targeted test status, relevant-suite status.
- `REFACTOR`: what changed structurally and the tests rerun afterward.
- `CLOSEOUT`: final validation, diff/evidence path, known limitations, and
  rollback.

The skill governs the coding loop; it does not grant permission for production
mutation, credential handling, deployment, or scope expansion.
