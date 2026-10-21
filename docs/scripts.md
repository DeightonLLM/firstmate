# The bin/ toolbelt

The first mate drives these; interactive entrypoints work by hand too, while `*-lib.sh` files are sourced helpers.
Each row is one purpose clause only: the script's own header comment is the authoritative description of its behavior, flags, and contracts, so read the header before first use.
If you have changed away from the firstmate home in an interactive shell, invoke these scripts by absolute path through the repo's `bin/` directory; the scripts self-locate internally after they start.
The shared no-mistakes gate refusal for fleet lifecycle entrypoints is summarized in [architecture.md](architecture.md#no-mistakes-gate-authority-boundary), while `docs/sessionstart-nudge.md` covers the silent hook-nudge use; `fm-gate-refuse-lib.sh`'s header owns its exact contract.

| Script                   | Purpose                                                                              |
| ------------------------ | ------------------------------------------------------------------------------------ |
| `fm-session-start.sh`    | Compose lock, bootstrap, and wake drain into the single ordered session-start digest |
| `fm-sessionstart-nudge.sh` | Print the native session-start hook nudge when the primary has not already run the digest |
| `fm-operational-input.sh` | Construct and parse the canonical cross-language operational-input protocol |
| `fm-bootstrap.sh`        | Detect toolchain and fleet problems, run the locked session-start sweeps, and install approved tools |
| `fm-fleet-sync.sh`       | Refresh project clones with safe fast-forwards, self-heals, `STUCK:` reports, branch pruning, and bounded recovery from an orphaned `.git/packed-refs.lock` |
| `fm-fleet-snapshot.sh`   | Print the read-only structured fleet snapshot JSON (schema `fm-fleet-snapshot.v1`)   |
| `fm-fleet-view.sh`       | Render the fleet snapshot as a human Markdown view                                   |
| `fm-bearings-snapshot.sh` | Project the fleet snapshot to the compact TOON bearings view; local-only unless `--include-prs` |
| `fm-update.sh`           | Fast-forward-only self-update of firstmate and secondmate homes from origin          |
| `fm-backlog-handoff.sh`  | Validate and delegate queued backlog-item moves into a secondmate home               |
| `fm-decision-hold.sh`    | Create, verify, complete, and resolve durable captain-held decisions                 |
| `fm-brief.sh`            | Scaffold ship, scout, secondmate-charter, and Herdr-lab briefs                       |
| `fm-herdr-lab.sh`        | Provision and guardedly operate an isolated, never-default Herdr lab session         |
| `fm-install-herdr.sh`    | Install CI's exact-version Herdr pin with official asset URL, SHA-256, and protocol checks |
| `fm-install-treehouse.sh`| Install CI's exact-version Treehouse pin for real-Herdr E2E that needs spawn worktrees |
| `fm-herdr-ci-cleanup.sh` | Snapshot and tear down only job-owned `fm-lab-*` sessions in the Herdr CI lane       |
| `fm-test-run.sh`         | Behavior-test runner: selection, portable lanes, proven-isolated `--jobs`, coverage guard, timing/JSON |
| `fm-test-isolation-proof.sh` | Concurrent isolation proof and proven-isolated candidate set owner |
| `fm-ensure-agents-md.sh` | Ensure a project's real `AGENTS.md`, its `CLAUDE.md` symlink, and the canonical self-governance section |
| `fm-coord-drift-check.sh` | Verify documented production host coordinates against live external DNS and fail loudly on drift |
| `fm-guard.sh`            | Warn on primary-checkout tangles, pending queued wakes, and stale watcher liveness   |
| `fm-primary-scope-lib.sh` | Shared marker-or-plain-checkout primary-home predicate for tracked hooks             |
| `fm-session-lock-lib.sh` | Shared session-lock harness identity (ancestry walk and holder liveness) for fm-lock.sh and the Claude Stop auto-arm |
| `fm-claude-stop-autoarm.sh` | Claude Stop `asyncRewake` hook owning tokenless watcher continuity with single-flight exit-2 rewake (docs/watcher-continuity.md) |
| `fm-turnend-guard.sh`    | Shared primary turn-end guard predicate so no turn ends blind (docs/turnend-guard.md) |
| `fm-turnend-guard-grok.sh` | Grok Stop-hook adapter for the primary turn-end guard                              |
| `fm-kimi-turnend-hook.sh` | Surgically install or remove Kimi's guarded global crew turn-end hook                |
| `fm-arm-pretool-check.sh` | Stable PreToolUse transport for the watcher-arm command policy (docs/arm-pretool-check.md) |
| `fm-arm-command-policy.mjs` | Semantic owner of the watcher-arm PreToolUse policy (docs/arm-pretool-check.md)   |
| `fm-subagent-pretool-check.sh` | Primary-home delegation-shape PreToolUse guard (docs/subagent-guard.md) |
| `fm-supervision-instructions.sh` | Render the session-start primary-harness supervision block or the one-line repair instruction |
| `fm-home-seed.sh`        | Transactionally provision a secondmate home and maintain `data/secondmates.md`       |
| `fm-spawn.sh`            | Spawn crewmates, scouts, `id=repo` batches, and secondmates on the resolved harness and runtime backend |
| `fm-backend.sh`          | Runtime-backend selection, meta helpers, selector resolution, and operation dispatch |
| `fm-backend-hometag-lib.sh` | Shared per-installation home-tag derivation for zellij tab and cmux workspace titles |
| `fm-composer-lib.sh`     | Single fleet-wide owner of composer-content classification for all backends          |
| `backends/tmux.sh`       | Verified tmux session-provider adapter                                               |
| `backends/herdr.sh`      | Experimental herdr session-provider adapter                                          |
| `backends/zellij.sh`     | Experimental zellij session-provider adapter                                         |
| `backends/orca.sh`       | Experimental Orca backend adapter owning both worktree and terminal                  |
| `backends/cmux.sh`       | Experimental cmux session-provider adapter                                           |
| `fm-config-push.sh`      | Push declared inherited local material to live secondmates mid-session and send a pointer to the literal-content config reread when config changed |
| `fm-project-mode.sh`     | Resolve a project's delivery mode and `+yolo` flag from `data/projects.md`           |
| `fm-quota-gate.sh`       | Fail-closed provider-quota admission for crew dispatch; wired into `fm-spawn.sh` (refuse exit 3 exhausted, exit 4 unmeasurable) |
| `fm-merge-local.sh`      | Fast-forward a `local-only` project's local default branch after approval            |
| `fm-review-diff.sh`      | Review a crewmate branch or resolved PR head against the authoritative base          |
| `fm-marker-lib.sh`       | Compatibility entry point for the from-firstmate carrier owned by `fm-operational-input.sh` |
| `fm-pending-reply-lib.sh` | Parent-owned secondmate pending-reply expectations, recovery, and one-shot escalation |
| `fm-secondmate-report.sh` | Optional helper to append a correlated parent status or document-pointer report       |
| `fm-comms-ingest.sh`     | Receive, receipt, and acknowledge remote file-drop replies from one or more source folders |
| `fm-hetz-send.sh`        | Send one outbound Hetz message and report the real `ssh` return code                   |
| `fm-comms-notify.sh`     | Send immediate guarded notification for delivered inter-home communication via Herdr   |
| `fm-gate-refuse-lib.sh`  | Shared no-mistakes gate-context refusal for fleet lifecycle entrypoints               |
| `fm-watch-arm.sh`        | Verified home-scoped watcher arm wrapper with loud cycle endings and bounded lifecycle ledger |
| `fm-watch-checkpoint.sh` | Run one bounded foreground watcher checkpoint for Codex-style supervision            |
| `fm-watch.sh`            | Singleton-safe always-on watcher: absorb benign wakes, queue and exit on actionable ones |
| `fm-afk-start.sh`        | Run the common sourceable away-mode daemon entry in the foreground                      |
| `fm-afk-launch.sh`       | Own away-mode entry, exit, rollback, and any backend terminal lifecycle                 |
| `fm-afk-return.sh`       | Own deterministic return shutdown, catch-up evidence, and the firstmate-actionable blocker gate |
| `fm-supervisor-target-lib.sh` | Resolve the shared supervisor target and backend for the daemon and launcher       |
| `fm-supervise-daemon.sh` | Presence-gated away-mode sub-supervisor: self-handle routine wakes, guard injection by the detected primary harness, escalate batched digests, alert on failed delivery |
| `fm-crew-state.sh`       | Print one deterministic current-state line for a crew                                |
| `fm-tangle-lib.sh`       | Shared default-branch resolution and primary-checkout tangle classification          |
| `fm-supervision-lib.sh`  | Shared in-flight-work-without-fresh-watcher-beacon predicate                         |
| `fm-ff-lib.sh`           | Shared guarded fast-forward helper for origin pulls and local secondmate syncs       |
| `fm-lock-lib.sh`         | Shared "is this git lock provably abandoned?" proof used by teardown and fleet-sync   |
| `fm-config-inherit-lib.sh` | Shared primary-to-secondmate inherited local-material propagation and config-reread delivery |
| `fm-tasks-axi-lib.sh`    | Shared backlog-backend selector and `tasks-axi` compatibility probe                  |
| `fm-quota-axi-lib.sh`    | Shared `quota-axi` compatibility floor for the bootstrap diagnostic                  |
| `fm-vendor-auth-probe.sh`| Run one hard-bounded, non-destructive authentication probe of a named vendor CLI and report the fact |
| `fm-wake-drain.sh`       | Atomically drain queued watcher wakes, emit bounded best-effort status-event annotations, then assert watcher liveness |
| `fm-wake-lib.sh`         | Shared durable wake queue, portable locks, and watcher identity/health helpers       |
| `fm-classify-lib.sh`     | Shared captain-relevant and declared-external-wait wake classification vocabulary    |
| `fm-send.sh`             | Send one verified literal line or supported key through the target's recorded backend |
| `fm-busy-lib.sh`         | Single owner of the semantic busy-state contract: verdicts, source attribution, and per-harness sources |
| `fm-busy-event.sh`       | The only writer of a task's semantic busy-state record; arms an incarnation and applies lifecycle events |
| `fm-tmux-lib.sh`         | Shared tmux pane primitives for composer capture, verified submit, and the submit-time busy check |
| `fm-peek.sh`             | Print a bounded tail of a crewmate endpoint                                          |
| `fm-check-register.sh`   | Bind an intentional custom watcher check to its current bytes                       |
| `fm-check-lib.sh`        | Validate custom-check registrations and prepare private execution snapshots          |
| `fm-pr-lib.sh`           | Own canonical task and PR validation plus private atomic PR-poll publication and identity-bound retirement |
| `fm-pr-poll.sh`          | Provide the byte-static watcher program for validated PR/MR-poll sidecars           |
| `fm-pr-check-migrate.sh` | Quarantine older task polls without execution and rebuild only canonical polls       |
| `fm-pr-check.sh`         | Record validated `pr=` and `pr_head=` values, then atomically arm a static merge poll |
| `fm-pr-merge.sh`         | Record PR metadata, then merge a task's canonical full GitHub URL                    |
| `fm-promote.sh`          | Promote a scout task in place to a protected ship task                               |
| `fm-teardown.sh`         | Fail-closed teardown: return landed ship worktrees, require completed scout deliverables, retire secondmate homes |
| `fm-harness.sh`          | Detect the running harness and resolve crew or secondmate harness, model, and effort |
| `fm-lock.sh`             | Per-home firstmate session lock                                                      |
| `fm-x-lib.sh`            | Shared X-mode config, relay, and reply-threading helpers                             |
| `fm-x-poll.sh`           | One bounded X relay poll: stash newly offered mentions and emit their once-only wake |
| `fm-x-reply.sh`          | Post or dry-run preview a composed X-mode reply or follow-up                         |
| `fm-x-dismiss.sh`        | Dismiss a skipped X-mode mention at the relay without replying                       |
| `fm-x-link.sh`           | Link a spawned task to its originating X-mode mention in task meta                   |
| `fm-x-followup.sh`       | Detect, post, and cap completion follow-ups for an X-mode-linked task                |
| `fm-public-followup-lib.sh` | Shared relay-activation gate, O(1) presence checks, and private transport paths for promised public replies |
| `fm-public-followup.sh`  | Reconcile typed terminal work results into a public commitment and deliver its final reply once |
| `fm-public-followup-emit.sh` | Report one typed terminal work result into the home that owes the public reply    |
| `controller-resource-audit.sh` | Read-only Controller resource sampler on the documented six-hour cadence; overwrite `latest.md`, trim the event ledger, delegate its disk verdict to `fm-capacity-gate.sh`, classify off-allowlist candidates for operator approval |
| `fm-capacity-gate.sh` | Single shared owner of the disk-capacity ladder and of the reclaim-then-refuse admission decision; consulted by `fm-spawn.sh` before every fresh placement |
| `fm-capacity-reclaim.sh` | Tiered reclaimer: real-`rm` unlink of regenerable caches and build litter, dead lock scratch, bounded log rotation, the merged worktree pool via `treehouse prune`, age-gated transcripts on request, and an archive-class inventory that is reported and never deleted |
| `fm-lock-reclaim-lib.sh` | Reclaims DEAD lock scratch (owner dirs and reclaim pointers) from outside the lock: the start-time-vs-dir-mtime test that tells a live holder from a recycled pid, and the lock shapes mirrored from `fm-wake-lib.sh` |
| `fm-log-rotate.sh` | Bounds an append-only log: copytruncate when the log is quiescent, rename when a writer is active, every generation capped |

## The disk-capacity ceiling

The Captain's hard ceiling is that the root filesystem must not go past **80%** used.
`bin/fm-capacity-gate.sh` is the **single shared owner** of that ladder and of the decision it
drives. It owns the thresholds, so there is exactly one copy of them in the repo:

| Root usage | Verdict |
| ---------- | ------- |
| `>= 80%`   | `CAPACITY_BLOCK_NEW_PLACEMENT` |
| `>= 75%`   | `CAPACITY_REVIEW_REQUIRED` |
| `>= 70%`   | `CAPACITY_EARLY_WARNING` |
| `< 70%`    | `CAPACITY_OK` |

`bin/controller-resource-audit.sh` is the read-only six-hourly sampler and **delegates** its
`verdict` subcommand to the gate, so a second copy of the thresholds cannot drift. The gate is
also the portable contract for any other surface that needs the ladder: `fm-capacity-gate.sh
verdict <percent>` answers with the token and nothing else.

**One ladder, one reader, no third gate.** `bin/fm-spawn.sh` is the reader: before any fresh
placement it consults the gate, and it refuses on `CAPACITY_BLOCK_NEW_PLACEMENT`. The project's
*declared* worker capacity is a different axis and stays where it is, in
`bin/fm-project-capacity-lib.sh`; that library is never widened to mean disk.

**Reclaim first, then refuse.** At or over the ceiling the gate does not simply refuse. It runs
`bin/fm-capacity-reclaim.sh --apply` (tiers 1-2), re-measures the disk itself, and re-reads the
verdict. A disk that came back under the ceiling is **admitted**, and the reclaim is logged. Only
a disk that is *still* at or over the ceiling afterwards is refused, and the refusal says what the
reclaim did, what the disk reads now, and what the operator can do.

The reclaim is **bounded** (a wall-clock timeout) and **serialised** (an exclusive `flock` on a
host-level lock file, with a portable `mkdir` fallback for surfaces without `flock`), so a
dispatch can never hang on it and two concurrent spawns can never both reclaim. An **unmeasurable
disk fails closed**: it is refused and the refusal says so.

The bypass is narrow, documented, and logged - never silent:

| Variable | Effect |
| -------- | ------ |
| `FM_CAPACITY_GATE_BYPASS=1` | Skip only the disk-capacity check; logged as `BYPASS_CAPACITY` and printed on stderr |
| `FM_DISPATCH_GUARD_CAPACITY_BYPASS=1` | The same check under its originally briefed name |
| `FM_CAPACITY_GATE_RECLAIM_TIMEOUT_S` | Wall-clock bound on the reclaim (default 90) |
| `FM_CAPACITY_GATE_LOCK` | Lock file path (default `/var/lock/fm-capacity-gate.lock`, else `${TMPDIR}/fm-capacity-gate.lock`) |
| `FM_CAPACITY_GATE_LOCK_WAIT_S` | How long to wait for the reclaim lock (default 30) |
| `FM_CAPACITY_GATE_DF` | Test seam: a command whose output is parsed like `df -P /` |
| `FM_CAPACITY_GATE_RECLAIMER` | Test seam: the reclaimer to run |

`tests/fm-capacity-refuse.test.sh` asserts the whole rule by observed behaviour: a reclaim that
frees nothing refuses, a reclaim that frees space allows, an unmeasurable disk refuses and is
disclosed, the bypass is logged and skips only this rule, and the reclaim is bounded by its
timeout.

**The reclaimer is honest about bytes.** `rm` on this host is a recoverable-delete shim that moves
its target into the trash, which on a single filesystem frees nothing - that is how a guard once
reported `freedKB=340864` having freed nothing. The reclaimer resolves the **real** `rm` by
absolute path (and rejects the shim even at those paths) and reports the **measured `df` before and
after delta**, never a sum of what it believes it deleted. A negative delta is reported honestly as
"gave back NOTHING" rather than clamped to zero.

Tiers: **1** caches and build litter (always safe to apply) and **2** the worktree pool, delegated
to `treehouse prune`, which refuses leased, dirty, in-use and unmerged slots. **3** age-gated agent
transcripts stay opt-in (`--tier 3`). **4** archive-class material - cold but valuable - is
**reported, never deleted**; `fm-capacity-reclaim.sh --inventory` prints that inventory alone.

### Tier 1b: dead lock scratch

Tier 1 carries two more classes, because both of them were invisible to the reclaimer when the
biggest reclaimable thing on the host was a lock leak.

**`1b` reclaims DEAD lock owner dirs and stale lock pointers.** A lock owner dir is scratch by
construction: `mktemp` made it, it holds only the lock's own pid file, and it is unreferenced the
moment its pointer goes. The reclaim is safe-and-automatic because the safety is a **proof**, not a
heuristic: a dir is reclaimed only when its recorded pid is provably not the process that created
it.

"Is that pid alive?" is **not** that proof, because the kernel recycles pids. Measured on the
Controller on 2026-10-21: 21,201 of the leaked dirs recorded a pid that happened to be running
again as an unrelated process, so a naive liveness test would have kept every one of them alive
forever; only 6 were held by a genuinely live process. The correct test compares the process's
**start time** with the owner dir's own **mtime** - a process that started after the dir was created
cannot be the process that created it. When the dir carries a `pid-identity` file the match is
exact, and that strictly stronger test wins.

A live holder is **never** touched. A lock pointer is removed only when its owner dir is one this
sweep reclaimed, or when the pointer's own target is provably dead - never while a live owner
references it. The pointer goes *before* its dir, so there is never a moment where a lock pointer
points at a dir that is being destroyed.

Only the lock shapes this repo creates are eligible, and the rules are **mirrored** from
`bin/fm-wake-lib.sh` (the owner of the lock protocol) rather than invented a second time:
`*.lock.owner.??????` and `*.lock.steal.owner.??????` at any steal depth, plus the `*.lock` and
`*.lock.steal` pointer symlinks. Three gates must all pass: the name is a lock shape, a pointer is
a **symlink** (a plain `.lock` file belongs to another lock family), and an owner dir is
**owner-private** (mode 0700 - tracked repository content never is). The mirroring is
cross-checked against the lock library by `tests/fm-lock-reclaim-disk.test.sh` so it cannot drift.

The reclaim unlinks with the **real** `rm`, resolved by absolute path, and refuses the
recoverable-delete shim even when it is found at one of those paths - the shim would move the
target into the trash and free nothing.

### Tier 1c: bounded logs

**`1c` rotates an append-only log that grew past its cap.** It never blind-truncates: the most
recent tail is kept for diagnosis and the rest is rotated out. `state/fm-comms-ingest.log`
reached 40 MB because an oversize file was re-reported on every scan and nothing ever rotated it.

The rotation lives in `bin/fm-log-rotate.sh` so it can also run on its own. It **copytruncates**
when the log is quiescent - nothing written for `FM_LOG_ROTATE_QUIESCE_S` seconds and the size
unchanged while the snapshot was taken - because that is provably lossless. When a writer **is**
active it **renames** instead: the writer's open descriptor follows the renamed inode, so every
byte it writes is preserved in the generation, and the generation is capped on a later pass once
the writer has finished. The whole family (the live file and every generation) is capped, so the
total on disk is bounded by numbers the operator chose.

| Variable | Effect |
| -------- | ------ |
| `FM_RECLAIM_STATE_ROOTS` | Colon-separated state roots the lock sweep and the log rotation look under |
| `FM_RECLAIM_TIERS` | Which tier groups this run executes (default `1,1b,1c,2`, plus `3` with `--tier 3`) |
| `FM_RECLAIM_LOCK_GRACE_S` | Age before dead lock scratch may be reclaimed (default 5) |
| `FM_RECLAIM_LOCK_MAXDEPTH` | How deep under a root the lock sweep looks (default 6) |
| `FM_RECLAIM_LOCK_MAX` | Owner dirs reclaimed per sweep (default 100000) |
| `FM_LOG_ROTATE_MAX_BYTES` | Cap on the live log (default 5242880) |
| `FM_LOG_ROTATE_KEEP_BYTES` | How much of the tail a generation keeps (default 262144) |
| `FM_LOG_ROTATE_GENERATIONS` | How many generations to keep (default 3) |
| `FM_LOG_ROTATE_GRACE_S` | Age before a generation may be capped (default 120) |
| `FM_LOG_ROTATE_QUIESCE_S` | How quiet a log must be for copytruncate to be provably lossless (default 2) |

`tests/fm-lock-reclaim-disk.test.sh` asserts all of it by observed behaviour: a dead owner dir is
reclaimed, a live holder is not, a recycled pid is (with the start-time comparison read from
`/proc`), a non-lock-shaped path is never touched, the shim `rm` is refused, the result line
reports a **measured** `df` delta, a reclaim that removed nothing never claims freed bytes, and an
active writer's output survives the rotation.

## Controller resource cadence units

`controller-resource-audit.sh` ships with the two units that give it the documented cadence:

| Unit | Path | Role |
| ---- | ---- | ---- |
| `controller-resource-audit.service` | `bin/systemd/controller-resource-audit.service` | `Type=oneshot`, runs the sampler, `ProtectSystem=strict` with `ReadWritePaths=/root/resource-audit` |
| `controller-resource-audit.timer` | `bin/systemd/controller-resource-audit.timer` | `OnCalendar=*-*-* 0/6:00:00`, the documented six-hour boundary |

`bin/controller-resource-audit.sh --check-timer-unit <unit>` is the machine check that keeps the shipped
timer honest: it accepts only a six-hourly `OnCalendar` and refuses anything that overrides the calendar
with a shorter `OnUnitActiveSec`/`OnUnitInactiveSec`, printing `CADENCE_DRIFT` and exiting non-zero.
`tests/controller-resource-audit.test.sh` asserts that contract, including the refusal path.
