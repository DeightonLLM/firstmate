# GATE-AUDIT-20260929 — launch-gate classification (operator ruling: retire launch bureaucracy, keep safety)

**Operator instruction 2026-09-29 ~07:38 BST:** remove old restrictive non-safety
"launch nonsense" gates on the agent-send path. **Constraint found during audit:
every gate script is referenced by 4-5 live callers, so deletion would break
launches outright.** Mechanism chosen instead: gates classified as bureaucracy are
neutered to **advisory** (warn + exit 0) at the gate itself — callers keep working,
friction disappears, and enforcement remains available by env var.

## NEUTERED to advisory (launch bureaucracy)

| Gate | What it enforced | Now | Opt back in | Backup |
|---|---|---|---|---|
| `validate-herdr-lane-prompt` | Fail-closed rejection of dispatch prompts over boilerplate: routing banner as literal first line, lane-field list, literal `"Use the To-Do List extension"`, `PROGRESSIVE_DISCLOSURE:`, literal `lean-ctx` token | Warns + exits 0 | `HERDR_LANE_PROMPT_ENFORCE=1` | `.bak-20260929T064357Z` |
| `brandon-herdr-layout-guard` | Self-described "presentation-only" pane-layout enforcement | Warns + exits 0 | `HERDR_LAYOUT_ENFORCE=1` | `.bak-20260929T064357Z` |

Verification: default invocation returns rc=0 with an ADVISORY line; with the env
var set, each gate's own bundled test suite still passes fully (33/33 and PASS) —
enforcement exists when explicitly requested.

## KEPT — safety / integrity (not launch friction)

| Gate | Why it stays |
|---|---|
| `agent-secret-scan` (+ brandon/hd2stack copies) | Secret-leak control, now fail-closed |
| `herdr-secret-input-guard` | Stops secrets entering lane prompts |
| `agent-intent-guard` | Anti-fabrication: coords/ledger contract (incident GAP-02/03) |
| `brandon-task-source-guard` | Anti-fabrication: task must exist in source-of-truth |
| `herdr-send-submit` | Dispatch integrity: ack, proof-of-read, no fabricated submits (suite green 11 classes) |
| `herdr-subagent-cap-check` / `-reap` | Resource safety (6-pane cap); policy-mandated hooks |
| `herdr-agent-start-fresh` receipt | FRESH_AGENT invariant — prevents session reuse/crossover |
| `warroom-guard` | Protects the operator's MAIN pane/tab from agent-initiated destruction (ties to the real session-corruption incident) — protective, not cosmetic |
| `herdr-dispatch-preflight` | Prevents dispatching into working/unknown panes (the rc=7 ack false-negative class) |
| `agy-checkpoint-gate` | Resilience — checkpointing is what recovered the corrupted 2026-09-28 session |
| `codex-luna-subagent-hook` | Enforces exactly the operator's fresh 2026-09-29 ruling (codex subagents = gpt-5.6-luna) |
| quota check before mass dispatch | Operator cost-safety ruling (zai exhausted; route by live quota) |
| spend-gate + mutation-gate (pi extensions) | Incident-mandated financial/mutation controls — untouchable |

## Follow-up flag (docs drift)

The canonical policy text (AGENTS.md policy modules) still *describes* the retired
boilerplate as mandatory ("routing banner as the literal first line", To-Do
acceptance wording). Hooks and docs must not disagree — that drift is the exact
failure mode documented in WORK-PLAN-20260929.md. A docs pass should update the
policy text to match this ruling; the hooks above are the operative behaviour now.
