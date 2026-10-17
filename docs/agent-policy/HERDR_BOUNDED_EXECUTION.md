# OPERATOR RULING 2026-09-29: lane-prompt boilerplate enforcement (routing banner, literal
# "Use the To-Do List extension", PROGRESSIVE_DISCLOSURE) is RETIRED as launch friction.
# validate-herdr-lane-prompt and brandon-herdr-layout-guard are ADVISORY (warn + exit 0);
# opt back in with HERDR_LANE_PROMPT_ENFORCE=1 / HERDR_LAYOUT_ENFORCE=1.
# Safety gates (secret-scan, intent-guard, send-submit, cap-check, fresh-receipt) unchanged.
# See /root/agent-work/firstmate/docs/audits-20260928/GATE-AUDIT-20260929.md.
# Herdr Bounded Execution

This contract prevents failed loops, repeated tests, aimless discovery, and token burn in authorized Herdr work. It limits execution; it does not authorize delegation, browser access, live-system access, or mutation.

## Default budget

Unless the operator explicitly supplies different limits, every Herdr lane uses:

| Control | Default |
|---|---:|
| Meaningful attempts per failing step | 3 maximum |
| Network or DNS retries after the initial attempt | 1 maximum |
| Transient browser-tooling retries after the initial attempt | 1 maximum |
| Coordinator revision rounds after initial submission | 2 maximum |
| Same blocker with no new evidence | Stop on occurrence 2 |
| Unchanged test or unchanged mutation reruns | 0 allowed |

A meaningful attempt tests a distinct evidence-backed hypothesis or applies a materially different, scoped correction. Rewording the same hypothesis, rerunning an unchanged command, restarting the same tool, or waiting without a named external-state reason does not reset or increment the budget; it is prohibited repetition.

Long-running lanes may have a larger task-specific time or item budget, but only when the dispatch prompt states it explicitly. A larger duration never removes the attempt, no-progress, authorization, or scope limits.

## Immediate stop conditions

Stop without consuming the remaining attempt budget when any of these occurs:

- required coordinates, target identity, comparison source, or expected state are missing;
- execution needs authorization not present in the operator's current instruction;
- a required rollback, backup, credential pointer, or approved access path is missing;
- host, application, repository, branch, live path, or browser-profile ownership does not match the prompt;
- the next action would broaden filesystem, network, browser, live-system, SaaS, database, DNS, or credential scope;
- another lane owns the same file, live resource, browser profile, port, or exclusive test account;
- a secret scan finds an unresolved new finding; or
- the same blocker occurs twice without materially new evidence.

## Browser stop contract

Browser prompts must name the exact routes, browsers, viewports, authentication boundary, and evidence outputs before execution.

- Run the specified matrix once.
- Retry once only when the failure is demonstrably transient browser/tooling instability.
- A reproducible product failure is evidence, not a reason to rerun the matrix.
- Capture the smallest sufficient screenshot, console/page-error output, DOM state, and reproduction steps.
- QA-only lanes must not repair source or production.
- Stop if the named browser profile or finite resource is owned by another lane.
- Clean up only processes and profiles created by the lane.

## Coordinator review loop

The coordinator reads the pane response and actual artifact, then sends one of:

- `ACCEPTED` — evidence and deliverable satisfy the lane contract;
- `REVISION_REQUIRED` — an interim decision containing bounded, enumerated corrections; or
- a terminal blocker/failure classification.

After the initial submission, no more than two revision rounds are allowed by default. If the same material defect survives two rounds, stop as `FAILED_VERIFICATION` or the specific blocking classification. Do not keep rewriting prompts or asking the worker to restate unchanged conclusions.

### Post-verdict pane lifecycle

After sending a terminal verdict (`ACCEPTED` or `TERMINAL`) via `herdr-review-send`, the coordinator must close the reviewed pane so it stops occupying a visible Herdr slot. `herdr-review-send` calls `herdr-subagent-cap-reap` automatically; callers of `herdr-review-send` do not need an extra step. `REVISION_REQUIRED` is excluded because the lane remains active and must stay open.

MiniMax M3 is an ordinary runtime with no protected-lane status or guardian gate; `herdr-subagent-cap-reap` closes stale done/idle panes normally under ordinary reaper rules.

## Terminal classifications

Every lane must end in exactly one of these states:

| Classification | Meaning |
|---|---|
| `ACCEPTED` | Required evidence and deliverable passed coordinator review. |
| `BLOCKED_OPERATOR_INPUT` | A material operator decision or value is required. |
| `COORDINATES_MISSING` | Exact target, source, owner, or comparison coordinates are missing. |
| `COORDINATES_CONFLICT` | Named coordinates disagree and cannot be safely reconciled. |
| `BLOCKED_AUTHORIZATION` | The next action crosses the currently authorized boundary. |
| `BLOCKED_ACCESS` | Approved access failed within the retry budget. |
| `BLOCKED_HOST_RESOLUTION` | The approved hostname did not resolve within the network retry budget. |
| `FAILED_NETWORK` | A non-DNS network operation failed within the approved retry budget. |
| `FAILED_VERIFICATION` | The required acceptance condition failed or could not be proven within budget. |
| `SUPERSEDED` | Another accepted lane or operator decision made this lane unnecessary. |

`REVISION_REQUIRED` is not terminal. `working`, `idle`, `done`, and `blocked` are Herdr lifecycle indicators, not evidence classifications.

Use the more specific `BLOCKED_HOST_RESOLUTION` or `FAILED_NETWORK` state when required by `NETWORK_AND_ACCESS_FAILURE_POLICY.md`; use `BLOCKED_ACCESS` for other approved-access failures.

## Evidence-preserving stop report

Before stopping, the worker must report:

1. terminal classification;
2. attempts used per failed step and retries used;
3. last materially new evidence;
4. files, screenshots, logs, hashes, or reports produced;
5. mutations performed and rollback/cleanup state;
6. exact unresolved blocker; and
7. precise condition or authorization required to resume.

The coordinator must review this report directly in Herdr and either accept it or issue a bounded correction. Do not ask the operator to relay worker output.

## Subagent cap (FIRSTMATE_OP v1)

The canonical source-of-truth is `/root/lib/subagent-cap/cap.sh`. Every
authorized Herdr run enforces these rules without exception:

| Constant | Value |
|---|---:|
| `MAX_SUBAGENT_PANES` | 6 |
| `MAX_TOTAL_PANES`    | 7 (includes Codex coordinator) |
| `OPEN_STATES`        | `working|blocked|idle|done` |
| `REAP_STATES`        | `done|idle` only |
| Refusal exit code    | 64 (`ERR_SUBAGENT_CAP_REACHED`) |

Enforcement points:

- **`fm-spawn.sh`** MUST source `cap.sh`, run `subagent_cap_reap_stale`, and
  call `subagent_cap_assert_can_spawn` before any backend creation. On refusal,
  it MUST exit 64 with `ERR_SUBAGENT_CAP_REACHED` on stderr. Bypass is the
  single explicit env `FM_SPAWN_CAP_BYPASS=1`.
- **`/root/bin/herdr-subagent-cap-check`** is the canonical pre-spawn hook. It
  asserts the cap without mutating existing panes. Hooks and supervisors
  MUST call it instead of re-implementing the count.
- **`/root/bin/herdr-subagent-cap-reap`** is the canonical post-closeout
  reaper. It closes only `done`/`idle` panes via `herdr-pane-close-safe`; it
  never touches `working`/`blocked`. MiniMax M3 is an ordinary runtime with
  no protected-lane status.
- **`herdr-heartbeat`** logs `SUBAGENT_CAP_REACHED` observationally when
  `open_subagent >= 6` or `open_total >= 7`. The heartbeat never auto-closes
  working/blocked panes.

Counting rules:

- Open pane = lifecycle in `{working, blocked, idle, done}`.
- Subagent pane = any pane where `agent != "codex"`.
- Codex pane always counts toward `MAX_TOTAL_PANES` regardless of its
  lifecycle state.
- A `done` pane counts as open until the reaper closes it. A pane whose
  lifecycle is `unknown` does not count.

If a lane's spawn is refused by the cap, the worker MUST record the
`ERR_SUBAGENT_CAP_REACHED` marker in its terminal report and stop. The
coordinator MUST NOT silently retry, replace the cap with a higher number, or
override via a non-canonical helper.

## Heartbeat and aborted-lane handling

The controller heartbeat is observational only. Unchanged pane revision for
ten minutes is `STALLED_NO_REVISION`; recent `Operation aborted` output is
`ABORTED_REVIEW_REQUIRED`; a context footer at or above 55% is
`CONTEXT_RISK_REVIEW`, and at or above 60% is a hard stop for new tool-heavy
work. These signals trigger coordinator inspection, not
automatic retries. The coordinator identifies whether the abort was operator
interruption, tool failure, context exhaustion, or worker self-termination,
preserves the artifact, and applies the bounded response loop. A heartbeat
must not create a background retry loop against a failed host.

## AGY bounded permission and auto-approval gate

AGY CLI lanes running Gemini 3.8 Flash Medium may operate in noninteractive auto-approve mode (`--dangerously-skip-permissions`) only under strict fail-closed constraints:

1. **Explicit authorization required:** Startup or dispatch with auto-approve flags requires `HERDR_OPERATOR_APPROVED=1` or an active verified campaign worker marker; unauthorized requests are rejected with exit 79.
2. **Fresh process receipt bound:** Direct dispatch to an auto-approving AGY pane requires a valid, consumed fresh-start receipt matching the foreground PID and command-line hash. Direct reuse without a fresh receipt is refused.
3. **PreToolUse guardrails preserved:** Auto-approval applies only to CLI-level confirmation prompts. `agy-coordinate-guard-hook` and `agent-intent-guard` remain fully active on every tool call, enforcing coordinate ledgers, secret protection, Docker denial, browser denial, destructive-action gates, and lease TTLs. Deterministic lean-ctx enforcement is active for all AGY operations under `/root`: native filesystem read/list/search tools (`view_file`, `list_dir`, `find_by_name`, `grep_search`) under `/root` fail closed with an explicit lean-ctx instruction, and `run_command` with a `/root` Cwd or `/root` operand requires the command to begin with `lean-ctx` (or canonical binary path), preserving only the approved `agent-secret-scan check` preflight exception.
4. **Scope boundary:** Auto-approval does not grant access to browser tools, Docker, production services, credentials, or paths outside declared coordinates.
