# Capacity report and cleanup recommendation — Hetz

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`
**Nothing was cleaned, closed, killed, restarted or reaped in producing this.**
Every number below was measured live at 2026-10-15 on Hetz.

Correction first: an earlier message of mine said "sending" about a capacity report
and did not send it. That was a claim without an action. This is that report, and
the mechanism that makes the omission impossible to repeat is described at the end.

## 1. Capacity facts

| measure | value |
|---|---|
| Registered git worktrees | **29** |
| Treehouse groups | 12 |
| `kun-agent-workspace-46aafc` slots occupied | **16 of 16 — FULL** |
| Other groups | 8bf1b0:12, firstmate-46aafc:12, core-distro-saas-clean:7, mm-saas-snapshot:1, four scratch:1 each, core-distro-saas-clean-30c8c1:3 |

**This is the binding constraint.** Dispatch fails with
`error: treehouse get did not enter a worktree within 60s` because the primary
group has no free slot. Disk is not the cause: 314G free, 4% inodes used.

### Lifecycle counts across 13 live workspaces

| state | count |
|---|---|
| working | 1 |
| idle | 8 |
| done | 2 |
| unknown | 2 |

## 2. The stragglers you asked about

| task | state | artifact | landed? | unlanded work |
|---|---|---|---|---|
| `brief-worklocation-template-fix` (w37) | idle | `data/brief-worklocation-template-fix/report.md` + brief | **YES — landed as `bab949ac`** | none |
| `controller-msg-triage-20261015` (w3X) | idle | report + brief present | report delivered; no branch | none |
| `durable-docs-20261015c` (w44) | done | **no report**, brief only | nothing to land | none |
| previously reaped attempts (5) | reaped | state preserved in `data/reaped-agents-20261015/preserved-state.md` | n/a | see slot 16 below |

## 3. Worktree state, and the one thing that must not be cleaned

Three worktrees carry modifications. Two are trivial. **One is real unlanded work.**

| slot | path suffix | state | assessment |
|---|---|---|---|
| **16** | `kun-agent-workspace-46aafc/16` | `M bin/fm-dispatch-guard.sh`, `M docs/configuration.md`, `M tests/fm-dispatch-guard-max-lanes.test.sh` — **67 insertions** | **UNLANDED WORK. The per-provider concurrency cap whose worker died on a shell denial.** `fm-teardown.sh` would correctly REFUSE. |
| 6 | `kun-agent-workspace-46aafc/6` | `?? .fm-secondmate-parent` — 90-byte pointer file | trivial, no work |
| one further slot | — | 1 modified file, untracked | trivial |

**Slot 16 has already been recovered and is not at risk.** I extracted it to
`data/provider-cap-recovery-20261015/slot16-unlanded.patch` (149 lines), applied it
to the live checkout, and ran the guard suite. It is recovered, not merely
preserved. Note for the record: the recovered work shipped only 2 of the 3 required
provider tests, so I wrote the missing coverage before landing rather than landing
the worker's partial delivery as-is.

## 4. Proposed cleanup list — recommendation only, nothing executed

| target | evidence the `fm-teardown.sh` guard would pass | proposed command |
|---|---|---|
| w37 pane | work landed as `bab949ac`; report preserved | `herdr workspace close w37` |
| w3X pane | report delivered and preserved | `herdr workspace close w3X` |
| w44 pane | nothing produced; brief preserved | `herdr workspace close w44` |
| slot 6 | single 90-byte marker file, no commits ahead | `git worktree remove` after marker is preserved |
| ~25 empty slots | `dirty=0`, no commits ahead of `origin/main` | `git worktree prune` |

**Explicitly NOT in the cleanup list:** slot 16 until the recovered per-provider cap
is landed or you direct otherwise.

## 5. The enforcement you asked for — unsent notes now wake firstmate

You noted the failure mode: I stated "sending" in chat and did not send. Nothing
caught it. That is now impossible to repeat silently.

1. **`bin/fm-to-controller.sh`** — writes and transmits in **one atomic command**.
   There is no longer a way to create a note for Controller without it being
   transmitted by the same act that creates it. `bin/fm-outbound.sh` remains for the
   rarer case of deliberately staging first.
2. **`bin/fm-controller-pending.sh`** — reports any outbox `.md` whose content hash
   is absent from the outbound ledger, i.e. written but not transmitted. Exits 1 when
   something is pending.
3. **`state/controller-pending.check.sh`** — registered with `fm-check-register.sh`, so
   the **scheduled watcher** wakes firstmate on an unsent note.

Proven by behaviour, not assertion:

```
staged an unsent note       → check emitted unsent-to-controller + ACTION line
transmitted it atomically   → pending exit flips 1 → 0
staged another              → check emitted again
```

Delivery remains three separate facts. This guarantees **transmission** only. It
does not claim you read it, and it does not claim acceptance.

## 6. Routing rule recorded where every agent can see it

Per your instruction, ordinary operational decisions — queue and status, collision
resolution, review requests, work-order clarification, capacity issues — route to
you directly. The Captain retains the hard gates: spending, destructive or
irreversible actions, credentials and key transfer, live production, DNS and
registrar, the Aminolifesciences archive, and branch merges.

I did **not** change either Firstmate-home candidate's instructions. That is your
decision, and it is queued for your routing rather than taken by me.

## 7. Two things I am not asking you to decide but you should know

- **`--worklocation` is incomplete.** Commit `bab949ac` amends the brief's location
  assertion, but the worker tool sandbox still refuses any path outside the isolated
  worktree: *"authorized live-home paths are inaccessible from this isolated worktree
  via ctx_read (root restriction)"*. Authorisation in prose is not capability — the
  same lesson I recorded earlier and then hit again. The working pattern today is:
  the worker writes into its own worktree and firstmate copies the artifact across.
- **The per-provider cap is recovered but not landed.** It is in the live checkout
  and its tests pass; I have not committed it pending your view on the scope.

## Boundaries unchanged

No cleanup executed. No branch discarded or merged. Three retained Core branches
remain retained. Aminolifesciences archive untouched. Warehouse not written to.