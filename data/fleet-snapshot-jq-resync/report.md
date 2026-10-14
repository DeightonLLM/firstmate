# Fleet snapshot jq argument-limit resync

## Outcome

The prior implementation was available on the local branch `fm/fleet-snapshot-arg-limit` at `9601685d`. Its report was read first from `/home/hd2admin/kun-agent-workspace/data/fleet-snapshot-arg-limit/report.md`. The report's root cause still applies to the current source: `main_inventory_json` (current line 567 before the cherry-pick) passed the complete serialized backlog and tasks as jq `--argjson` command arguments. Final snapshot assembly and several sibling helper paths did likewise. Bulk JSON in argv can exceed the OS argument limit.

`git cherry-pick 9601685d` applied cleanly as commit `0118dd49` (`fix: stream fleet JSON into jq`). Inspection of the commit diff shows the expected stdin/`jq -s` conversions for the full fleet snapshot path, the secondmate summary and aggregation helpers, final assembly, and the Bearings sibling renderer; a regression test for 12,000 backlog rows is included. No cherry-pick abort was needed. The output-shape intention remains the same: values are decoded from stdin in the same jq projection, and the regression asserts schema and full row count. This has not yet been validated in this worktree.

## Reproduction and validation attempts

The requested reproduction was attempted with a synthetic 12,000-row backlog using `ctx_shell`. Exact command submitted:

```sh
set +e
scratch="$PWD/.fleet-snapshot-repro"
rm -rf "$scratch"
mkdir -p "$scratch"/{state,data,projects,config}
{
  printf '## In flight\n'
  for i in $(seq 1 12000); do printf -- '- [ ] task-%05d - Synthetic item with an intentionally long title to amplify JSON payload size (repo: alpha) (kind: ship)\n' "$i"; done
  printf '\n## Queued\n\n## Done\n'
} > "$scratch/data/backlog.md"
bytes=$(wc -c < "$scratch/data/backlog.md" | tr -d ' ')
FM_HOME="$scratch" FM_SNAPSHOT_NOW='2026-10-13T00:00:00Z' FM_SNAPSHOT_NOW_EPOCH=1791849600 bin/fm-fleet-snapshot.sh --json > "$scratch/out.json" 2> "$scratch/err.log"
rc=$?
printf 'repro_exit=%s backlog_bytes=%s\n' "$rc" "$bytes"
printf 'error:\n'; awk '{print}' "$scratch/err.log"
printf 'stdout_bytes=%s\n' "$(wc -c < "$scratch/out.json" | tr -d ' ')"
rm -rf "$scratch"
exit 0
```

Actual exit code: 126. The command was refused because `set` is not in the shell allowlist. Per the invocation restrictions, it was not retried or worked around. Therefore there is no observed reproduction error or input-size measurement from this run.

The sanctioned test command `/bin/bash tests/fm-fleet-snapshot-view.test.sh` was also attempted exactly once. Actual exit code: 126; the shell allowlist refused `bash`. It was not retried. The regression test, large-input proof, shell syntax/lint checks, output comparison, and the remainder of the test suite remain unrun in this worktree. The previous report's 12,000-row / 1,692,028-byte test is prior evidence only, not proof for this current-base commit.

A code search found additional `--argjson` candidates documented by the prior report: `bin/fm-public-followup-emit.sh` deliverables, `bin/fm-x-reply.sh` receipt chunks, and Herdr workspace-id arrays. They were not changed: their relationship to the fleet visibility failure and whether inputs can reach the same size were not verified. They remain a required follow-up audit before claiming all bulk-JSON argv cases are covered.

## Delivery state

This branch is not ready to land. Required tests and large-input proof could not be run because the sanctioned shell invocation was refused. Do not treat this report as completion or the branch as validated. Cherry-pick commit present: `0118dd49`.
