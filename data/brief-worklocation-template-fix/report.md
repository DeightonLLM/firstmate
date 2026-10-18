# Brief worklocation template fix - validation report

## Change

`bin/fm-brief.sh` now accepts `--worklocation <absolute-path>` for ship and scout briefs.
The path must name an existing directory, is resolved to its physical absolute path, and is rendered in a narrow authorization clause that changes only the worklocation/isolation requirement.
The clause directs the worker to operate only in that path and says every other brief boundary remains in force.
The existing worktree isolation assertion and location rules remain unchanged by default.

`tests/fm-brief.test.sh` covers ship and scout opt-in output, preserved location boundaries, rejection of an absent path, an unrelated environment variable not enabling the option, and byte-stable repeat generation without the flag.
The implementation is committed as `23f0468e` on `fm/brief-worklocation-template-fix`, directly above the available `origin/main` ref.

## Validation

- `bash tests/fm-brief.test.sh` - exit 0.
  All tests passed, including the new worklocation cases.
- `bin/fm-test-run.sh --all` - exit 1.
  Summary: `FM_TEST_SUMMARY total=135 failed=39 skipped_gate=12 duration_ms=1183966`.
  The target `tests/fm-brief.test.sh` passed in this run.
  Other observed failures include unavailable test/runtime tooling, missing expected test infrastructure, and environment-specific watcher paths; examples include `fm-spawn-cap-enforcement.test.sh` (Treehouse did not enter a worktree within 60 seconds), `fm-test-run.test.sh` (portable shard union mismatch), and `herdr-secret-input-guard.test.sh` (expected exit 0, got 127).
  The 12 gate-skipped tests were `fm-afk-pi-herdr-return-e2e.test.sh`, `fm-backend-cmux-smoke.test.sh`, `fm-backend-zellij-smoke.test.sh`, `fm-claude-stop-autoarm-live-e2e.test.sh`, `fm-codex-continuity-live-e2e.test.sh`, `fm-grok-continuity-live-e2e.test.sh`, `fm-grok-stop-live-e2e.test.sh`, `fm-opencode-primary-live-e2e.test.sh`, `fm-pi-primary-live-e2e.test.sh`, `fm-pi-primary-types.test.sh`, `fm-quota-array-dispatch-live-e2e.test.sh`, and `fm-send-secondmate-marker-herdr-e2e.test.sh`.
  Watcher tests also emitted repeated errors that `/root/agent-work/deightonllm-firstmate/state/` does not exist.
- `bin/fm-lint.sh` - exit 1.
  It reported numerous warnings across unrelated files; no diagnostic named `bin/fm-brief.sh`.
- `shellcheck -x bin/fm-brief.sh` - exit 0, no output.
- `bash -n bin/fm-brief.sh tests/fm-brief.test.sh` - exit 0, no output.
- `git diff --check` - exit 0, no output.
- Manual old-vs-new executable comparison for default ship and scout briefs - both `cmp` exit 0 (`ship default output: byte-identical`; `scout default output: byte-identical`).

## Outstanding completion blockers

The full suite and repository-wide lint did not pass, so this task is not reported as complete.
The decision-hold completion command `FM_HOME="$PWD" bin/fm-decision-hold.sh complete brief-worklocation-template-fix --none` exited 1 with `origin brief-worklocation-template-fix is not owned by the active home`.
The task requires the report at `/home/hd2admin/kun-agent-workspace/data/brief-worklocation-template-fix/report.md`, but its explicit rule also forbids modifying anything outside this disposable worktree; this report is therefore kept at the matching relative path inside the worktree, and the requested absolute path was not written.
No remote, PR, merge, production, credential, database, permission, host, or `projects/` operation was performed.
