# Fleet snapshot jq argument-size defect

## Reproduction before the fix

I generated a synthetic backlog with 12,000 structured rows, invoked `bin/fm-fleet-snapshot.sh --json` with that home, and reproduced the failure before editing any code.

Exact reproduction command:

```bash
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
printf 'backlog_bytes=%s\nexit_code=%s\nstderr:\n' "$bytes" "$rc"
awk '{print}' "$scratch/err.log"
printf 'stdout_bytes=%s\n' "$(wc -c < "$scratch/out.json" | tr -d ' ')"
rm -rf "$scratch"
exit 0
```

Observed output was `backlog_bytes=1476033`, `exit_code=1`, and `stdout_bytes=0`.

Exact error:

```text
bin/fm-fleet-snapshot.sh: line 567: /usr/local/bin/jq: Argument list too long
fm-fleet-snapshot: main inventory summary failed
```

## Bulk JSON argument inventory and changes

The fleet snapshot script had bulk values passed through jq command arguments in these paths: `main_inventory_json` passed backlog and task arrays; `secondmate_home_summary_json` passed backlog and task arrays; `secondmate_current_json` passed the registry and task arrays, accumulated record arrays, and packaged registry/records; `parent_evidence_reconciliation_json` passed summary/activity/decision objects; per-secondmate record construction passed structured summaries and activity evidence; `secondmate_landed_from_current_json` passed the full current array; and final snapshot assembly passed six complete JSON documents. `task_json_lines` also passed current-state, status-event, and open-decision JSON values, plus the last event as a string. Those variable-sized inputs now travel over jq stdin and are decoded with `jq -s` or `jq -R`; scalar bounded flags and identifiers remain command arguments.

The sibling Bearings renderer had two more scale-dependent argument-vector paths: appending `rows` and `repo_rows`, and passing the accumulated `candidate_prs` array into the final projection. Both now use stdin. Its other `--argjson` values are numeric flags and counts.

A scan of the other `bin/` jq argument uses found separate variable-sized payload candidates outside the fleet snapshot path: `bin/fm-public-followup-emit.sh:238` passes `DELIVERABLES_JSON`, and `bin/fm-x-reply.sh:118` passes the serialized `chunks` array. They are not used by fleet visibility and were not changed in this scoped repair. `bin/fm-x-lib.sh` uses `--slurpfile` for image payloads; its remaining JSON preview contains metadata and a filesystem path, not image bytes. Other reviewed `--argjson` uses in backends, bootstrap, and spawn pass bounded numeric identifiers, counters, or fixed-schema objects rather than backlog-sized arrays.

## Validation and evidence

The colocated regression builds 12,000 records in a 1,692,028-byte backlog, verifies the canonical snapshot schema and record count, and verifies the secondmate summary still classifies the complete input. It relies on the existing `tests/lib.sh` EXIT cleanup trap and fails on unmet assertions.

Checks and observed exit codes:

- `bash -n bin/fm-fleet-snapshot.sh bin/fm-bearings-snapshot.sh tests/fm-fleet-snapshot-view.test.sh` - exit 0.
- `shellcheck bin/fm-fleet-snapshot.sh bin/fm-bearings-snapshot.sh tests/fm-fleet-snapshot-view.test.sh` using ShellCheck 0.11.0 - exit 0.
- `bash tests/fm-fleet-snapshot-view.test.sh` - exit 0, including the large-input regression.
- `bash tests/fm-bearings-snapshot.test.sh` - exit 0.
- Baseline/current snapshot comparison using `git show HEAD:bin/fm-fleet-snapshot.sh`, fixed observation time, a structured queued+done fixture, and `cmp -s` - baseline exit 0, current exit 0, comparison exit 0; output bytes were identical.
- `git diff --check` - exit 0.
- `bin/fm-lint.sh` - exit 1. It emitted numerous findings in untouched files, including `bin/fm-always-four.sh` and other untouched scripts/tests; the changed scripts and test pass the targeted ShellCheck command above.

`FM_HOME=/home/hd2admin/kun-agent-workspace bash bin/fm-decision-hold.sh complete fleet-snapshot-arg-limit --none` - exit 0; review found no unresolved captain decision.

`bash /home/hd2admin/kun-agent-workspace/bin/fm-ensure-agents-md.sh .` - exit 0; existing project memory was unchanged.

The full repository test suite was not run.

## Delivery

The fix is intended for the local-only branch `fm/fleet-snapshot-arg-limit`; no remote, PR, merge, production, or deployment operation is part of this task.

Commit: `9601685d` (`fix: stream fleet JSON into jq`) on `fm/fleet-snapshot-arg-limit`.

Postflight: `git status --short --branch` showed a clean branch; `git merge-base --is-ancestor main HEAD` exited 0. No push, PR, or merge was performed.

The remaining variable-cardinality `--argjson` candidates found across `bin/` are `bin/backends/herdr.sh:848` (`before_order` workspace IDs), `:892` (`order` workspace IDs), and `:1198` (`desired` workspace IDs), in addition to the public-followup deliverables and X reply chunks above. They are unrelated to fleet visibility and were not changed here.
