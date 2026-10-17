# Herdr M3 Verification Lane Dispatch Capsule

Use this capsule for M3 checker/verifier lanes. The M3 pane is protected — do not close, compact, restart, or reassign it until the coordinator sends `ACCEPTED —` or `TERMINAL — <classification>:`.

## Preamble

This lane is assigned to a MiniMax M3 runtime pane. Before accepting the task, verify the runtime model in the pane output. If the displayed model is NOT MiniMax M3, report `COORDINATES_CONFLICT —` and stop.

## Coordinator actions (pre-dispatch)

1. **Claim the M3 pane** before sending the task:
   ```bash
   /root/bin/herdr-m3-guardian --action claim --pane-id <pane-id> --workspace <ws> --task "<short task description>"
   ```
   Record the return code. If claim fails (non-M3 pane), assign to a confirmed M3 pane instead.

2. **Send the complete bounded instruction** — one message, one Enter key call.

3. **Wait for idle/done** — do not send corrections while pane is `working`.

4. **On terminal response**, call the release:
   ```bash
   /root/bin/herdr-m3-guardian --action release --pane-id <pane-id>
   ```

## Worker obligations

- Use Todo ≥5, progressive disclosure, lean-ctx.
- Validate findings with direct evidence (file reads, command output).
- Secret scan: `/root/bin/agent-secret-scan check /root`
- Report: classification, evidence, blocker or acceptance.
- Do NOT compact, close, or restart the pane yourself.
- Do NOT accept a different task mid-lane.

## M3 Protection Rules (non-negotiable)

| Action | Allowed for M3 verifier? |
|---|---:|
| Close / terminate | ❌ |
| Compact / context reduction | ❌ |
| Restart pane session | ❌ |
| Repurpose to different lane | ❌ |
| Send different task (cross-lane) | ❌ |
| Worker key rotation | ✅ (new session = new pane) |
| Report findings to coordinator | ✅ |

## Dispatch preamble (copy into pane)

```
[Lane: M3-VERIFIER | Model: MiniMax M3 | Protected lane]
Role: Independent verification and deep-review checker.
M3 protection: This pane is protected. Do not close, compact,
restart, or reassign until the coordinator sends ACCEPTED —
or TERMINAL — <classification>:.

Use the To-Do List extension. Use lean-ctx for all reads.
Run agent-secret-scan before any file mutation.

PROGRESSIVE_DISCLOSURE:
- Step 1: Preflight — verify model in pane output
- Step 2: Discover — bounded evidence gathering
- Step 3: Work — scoped verification
- Step 4: Validate — cross-check findings
- Step 5: Report — compact summary to coordinator

Task: <insert task description>

Artifact: /root/agent-work/M3_VERIFY_<pane-id>_<timestamp>.md
```
