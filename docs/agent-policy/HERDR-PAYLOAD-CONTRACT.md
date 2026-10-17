# Herdr Payload Contract

This document is the single owner of measured Herdr pane payload assumptions used by dispatch gates.

## Measured payloads

On 2026-10-15, read-only `herdr agent get` measurements against Controller pane `wD3:p7J` and registered HD2 pane `wF:p2` confirmed that neither payload contains `model` or `pid` in the agent object.

The registered remote pane returned these `agent` object keys:

- `agent`
- `agent_status`
- `cwd`
- `focused`
- `foreground_cwd`
- `interactive_ready`
- `name`
- `pane_id`
- `revision`
- `state_change_seq`
- `tab_id`
- `terminal_id`
- `terminal_title`
- `terminal_title_stripped`
- `workspace_id`

The Controller pane exposed the same operational fields except `name` and `interactive_ready`, and also exposed adapter/session metadata: `agent_session`, `screen_detection_skipped`, `state_labels`, and `tokens`.

The `agent get` command output is wrapped in an `agent` object; the keys above refer to that object, not the outer CLI response envelope.

The measured `pane process-info` object keys on both panes were `foreground_process_group_id`, `foreground_processes`, `pane_id`, and `shell_pid`.

Each observed `foreground_processes` entry had the keys `argv`, `cmdline`, `cwd`, `name`, and `pid`.

There is no `processes` key in this payload.

Authoritative model identity comes from the foreground process `argv`, including its `--model` argument when present.

Authoritative process identity is the foreground process entry's `pid` in `foreground_processes`, not a nonexistent `agent get` pid field or the pane's shell PID.

Any gate that needs model or process identity must inspect these measured foreground process entries and must handle absent or ambiguous argv evidence as unknown.

## Verification and upgrade rule

`herdr agent get --help` describes the command only as “Show an agent”; the installed skill documentation does not enumerate its payload fields.

Consequently, payload fields must be measured from live responses rather than inferred from help text, skill prose, types seen elsewhere, or prior versions.

Re-run the verification below after every Herdr upgrade and before relying on a changed field in a gate.

The sample uses the Controller pane and registered HD2 pane measured for this contract; substitute currently available read-only pane and machine identifiers when needed.

```sh
herdr agent get wD3:p7J | jq -r '.result.agent | keys | sort[]'
herdr pane process-info --pane wD3:p7J | jq -r '.result.process_info | keys | sort[]'
herdr --machine d8b3aabca5b8c4dcaa54d4bba29f9396 agent get wF:p2 | jq -r '.result.agent | keys | sort[]'
herdr --machine d8b3aabca5b8c4dcaa54d4bba29f9396 pane process-info --pane wF:p2 | jq -r '.result.process_info | keys | sort[]'
herdr --version
```

Compare the returned fields and nested `foreground_processes` entry keys against this contract, and record the Herdr version, host, pane identifiers, command output, and result of the check.

A changed or missing field is an interface change to investigate before any gate is updated or used.

## Machine ownership

Any per-machine state, including receipts, ledgers, and session artifacts, must be both written and read on the host that owns the pane, or explicitly fetched from that host.

A Controller-local path lookup is not evidence that a remote-host artifact is absent.

## Gate authoring rules

- Before a gate reads a field, confirm that field exists in a live payload from the target surface; never author a gate against an assumed schema.
- Exercise every gate end-to-end against a real remote pane at least once, and record the host, pane, commands, outcome, and evidence used.
- A gate that cannot distinguish its own failure from a genuine target defect must not block work.
- Fail-closed means refuse on unknown evidence, never refuse because a guessed schema was wrong.
- When a guard blocks legitimate work, repair its evidence source and retain the safety check; do not delete the check.
- Resolve model and PID identity from `foreground_processes[].argv` and `foreground_processes[].pid` respectively.
- Keep machine-local evidence machine-aware: read and write it on the owning host or explicitly fetch it.
- Re-verify measured assumptions after Herdr upgrades before changing gates.
- Before any Herdr lane dispatch, load `herdr --skill` (the upstream agent-facing contract). Use the **agent** command surface when Herdr must validate agent identity or interpret `idle`/`working`/`blocked`/`done`/`unknown`; use **pane** commands only for ordinary processes. `pane run` types text and registers nothing.

## Recurring failure modes and their permanent fixes

| Defect | Symptom | Root cause | Permanent fix | Confirmation |
|---|---|---|---|---|
| Lane launch used `herdr pane run <pane> -- <cmd>`. Twice (2026-10-16). | Pane showed `-- agy --model ...` then `--: command not found`; no agent ever started, and `herdr agent list` stayed empty so the lane could not be prompted. | Two assumed interfaces. `pane run` takes `<PANE_ID> <COMMAND>...` with **no `--` separator**, so the separator was typed as the first token; and `pane run` only types text — it never registers an agent or validates identity. | Use the agent surface when Herdr must validate agent identity or interpret lifecycle state: `herdr agent start <name> --kind <kind> --pane <ID> [-- <agent-args...>]`, args only after `--`. Use `pane run` only for ordinary processes. `bin/launch-agy-lane.sh` wraps this and re-verifies registration instead of trusting a zero exit. | The launcher returns non-zero when `agent start` succeeds but the pane is absent from `agent list`; a live HD2 run printed `REGISTERED: agy idle`. |
| Dispatch preflight queried `agent get` fields `model` and `pid`. | Dispatch submission was blocked fleet-wide. | Neither field exists in the measured `agent` object. | Read model from foreground process `argv` and process identity from its `pid` entry in `foreground_processes`. | A live remote-pane end-to-end gate run records both identities from the process list and submits only when evidence is valid. |
| Send-submit required an `EXPECTED_MODEL:` task-file line. | Valid byte-bound tasks were rejected before submission. | The required model was assumed to be carried in a task file that does not contain it. | Resolve expected runtime identity from the authoritative live pane/process evidence; do not require unbound task-file metadata. | A representative byte-bound task passes the end-to-end remote-pane gate without an `EXPECTED_MODEL:` line, with the actual identity recorded. |
| Fresh-receipt publisher read a `processes` collection. | Receipt publication could not find the expected process data. | The process-info payload names the collection `foreground_processes`. | Read the foreground process records and use their `argv` and `pid` fields. | A receipt publication test on a real remote pane records the selected foreground process and its PID. |
| Receipt handling assumed Controller-local files were authoritative for remote panes. | A remote receipt appeared missing or could not be validated locally. | The artifact was stored on the target machine but only read on Controller. | Read and write receipts on the pane-owning host, or explicitly fetch them to the Controller before validation. | A remote-pane run confirms the receipt's host, writes it there, and validates it there or records its explicit fetch. |
| Audit facts were derived from PATH lookup or Controller-relative paths. | The audit reported false absence for installed tools or remote files. | The measurement ignored explicit login-shell PATH, known install locations, or target-surface path ownership. | Probe the correct surface and path sources; distinguish reachability from readability and never infer absence from Controller-relative lookup. | Repeat the audit with host-aware probes and verify each reported absence against the owning surface. |

## Cross-references

`HERDR_AGENT_ROUTING.md` points here for payload fields and gate rules.

`SURFACE-IDENTITY.md` points here for pane identity and machine-owned state rules.

VERDICT: PASS
