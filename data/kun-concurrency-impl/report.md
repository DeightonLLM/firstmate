# Kun-inspired high-throughput Firstmate implementation report

**Outcome: blocked before implementation.** The requested `concurrency=50` does not map to a supported Firstmate setting in the assigned repository snapshot, and the task instruction says to stop rather than invent one.

## Evidence and decision

- Lane A's report, `BRANDON-COMPUTE-COMMS/from-brandon-compute/Kun-Lane-A-video-source-study.md`, finds no universal Kun concurrency key. It distinguishes Treehouse's pooled worktree limit (`treehouse.toml` / `max_trees`, default 16) from active agent concurrency, and identifies Fable's “50 cap” as a provider-enforced 50% subscription quota rather than a configurable setting.
- Lane A cites Kun's video, [High Throughput Agentic Engineering with Kun](https://youtu.be/MSbacZ99E14), including Firstmate routing discussion around 08:06, plus the [Treehouse](https://github.com/kunchenguid/treehouse), [gnhf](https://github.com/kunchenguid/gnhf), and [Firstmate](https://github.com/kunchenguid/firstmate) repositories. Its Fable finding references Kun's X posts dated 2026-09-01, 2026-09-02, and 2026-09-05.
- Lane B's `BRANDON-COMPUTE-COMMS/from-brandon-compute/Kun-Lane-B-config-inventory.md` reports a home-local `config/parallel-dispatch-cap` value of 6, plus three dispatch rules. That report's claimed setting conflicts with the current Firstmate repository evidence below; the setting was not present in this isolated worktree and was not independently inspected outside the authorized worktree.
- `AGENTS.md:261` says isolated work may dispatch “with no concurrency cap.”
- `docs/configuration.md` documents dispatch profiles as harness/model/effort routing and batch launch pacing (`FM_SPAWN_DISPATCH_DELAY_SEC`, default 0.25 seconds), not a maximum active-task setting (`docs/configuration.md:226-234`).
- `bin/fm-spawn.sh` documents batch `id=repo` launches, and the repository search found no `parallel-dispatch-cap` implementation or concurrency-setting reader. `tests/fm-spawn-batch.test.sh` tests batch argument routing, not a task-count cap.
- The inbox path `/home/hd2admin/kun-agent-workspace/state/kun-concurrency-impl.inbox` was absent, so there were no task messages to acknowledge.

**Decision:** Do not set a value of 50, add a new alias, or treat `treehouse.max_trees=50` as 50 active Firstmate tasks. The Lane B value of 6 has no corresponding reader or documented schema in this repository snapshot, while Lane A's Treehouse value controls pooled worktrees and is not equivalent to an active-dispatch cap. A change would therefore guess at the intended control and its safety semantics.

## Configuration paths

- **Before, as reported by Lane B:** `config/parallel-dispatch-cap` = `6` in the inventoried Firstmate home; this is report evidence, not a setting verified in the isolated source tree.
- **Before, authoritative repository documentation:** `docs/configuration.md` defines crew dispatch routing and batch pacing; it defines no concurrency cap.
- **After:** no configuration or documentation files were changed. No `config/parallel-dispatch-cap` or `concurrency=50` setting was created.

## Diff

No files changed. The worktree was clean at commit `2e61f527941216c6275a3d41995d3324856bf355` and was detached (`HEAD (no branch)`) during preflight. No feature branch was created because the required implementation was stopped at the explicit mapping guard.

```diff
(no diff)
```

## Verification and delivery

- **TDD:** Not run. No behavior change was authorized after the missing-setting conflict was established; there is no red/green claim.
- **Config parse/dry run:** Not run. No supported concurrency schema or config change exists to parse or exercise.
- **Plugin load:** Not run. No concurrency plugin or extension is identified by the evidence, and no plugin was added; loading an unrelated existing Pi extension would not verify the requested behavior.
- **No-mistakes:** Not run. The task was stopped before implementation, and the worktree has no feature branch or changed commit to validate. The explicit task rule also forbids pushing.
- **PR URL:** None; no PR was opened.
- **Independent checker:** Not run. No implementation diff was available to check, and this worker role does not delegate the task.

## Required next decision

Reconcile Lane B's reported `config/parallel-dispatch-cap=6` with the current repository, then specify whether the desired “50” means a new maximum for active Firstmate tasks or a Treehouse pool size. Until that mapping and its resource/safety semantics are established, no implementation is recommended.
