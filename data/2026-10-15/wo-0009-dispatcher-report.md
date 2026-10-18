# WO-0009 dispatcher evidence

## Preflight and discovery

- Worktree: `/tmp/wt-wo0009-dispatcher-r2`.
- Branch: `wo-0009/dispatcher-r2`.
- Initial tracked working tree was clean.
- `bin/fm-always-four.sh` already provides a queued-task selector and lane spawning. Its selector excludes every queued row containing `blocked-by:` without resolving whether the dependency is complete; it has no scope-owner routing. Existing `bin/fm-dispatch-guard.sh` enforces a per-provider live-lane ceiling and refuses on saturation.
- `data/agent-scopes.tsv` is absent from this worktree. `bin/fm-scope-check.sh` defaults to `/home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv`; that registry was readable and contains seven owners, but no current backlog ticket-to-domain contract was available here to safely map a ticket to its charter.
- `config/crew-dispatch.json` is absent from this worktree.
- `.tasks.toml` points the markdown backend to `data/backlog.md`, but that backlog file is absent from this worktree.

## Validation

- RED: not run. No test was added because the canonical backlog and mode-B dispatch configuration needed to define ticket eligibility and ownership were unavailable. Fabricating these inputs would not prove the requested dispatcher behavior against the Controller's queue.
- GREEN: not run; no implementation was made.
- Full-suite counts: not run; there is no implementation or meaningful test contract to validate.
- Commit: none.

## Outcome

The existing system has a lane scheduler and per-provider guard, but this attempt did not establish a verified dispatcher that selects by dependency and charter scope.

blocked: [key=canonical-dispatch-inputs] Provide or identify the canonical backlog available to this isolated worktree and the current mode-B `config/crew-dispatch.json` schema/contents (or explicitly authorize sanitized fixtures and define the ticket-to-scope field); then rerun discovery and TDD against those inputs. No code, tests, guard changes, or commits were made.
