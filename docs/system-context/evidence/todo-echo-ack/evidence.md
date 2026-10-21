# To-Do Echo/Ack Diagnosis Evidence
# Investigation: herdr-dispatch-ack-echo-fix-20261007
# Surface: Controller / firstmate (deightonllm-firstmate)
# Date: 2026-10-17
# Scope: READ-ONLY diagnosis; no mutations

## Q: Where is a To-Do item marked acknowledged today?

### Dispatch paths from Controller

**Path A: Normal crew dispatch (fm-spawn.sh + fm-send.sh)**
- `fm-spawn.sh` launches the agent via the herdr backend
- `fm-send.sh` calls `fm_backend_herdr_send_text_submit` (herdr.sh line 2708)
- Confirmation: waits for `agent_status == "working"` (native agent-state, NOT text content)
- Returns "empty" on confirmed submission
- NO check-in gate is invoked for this path

**Path B: M3 review dispatch (fm-m3-review-loop.sh)**
- `fm-m3-review-loop.sh` calls `herdr-send-submit` directly (line 139)
- `herdr-send-submit` types task file content to pane, then invokes `herdr-dispatch-ack`
- Check-in gate: `herdr-dispatch-ack` (HD2Stack, `/root/bin/`)
  - Checks `agent_status == "working"` for model turn
  - For non-trivial: checks five distinct `t[0-9]+` IDs via regex
  - M3 review loop targets M3 panes only (MiniMax has native To-Do)

**Path C: herdr-dispatch-ack To-Do detection (HD2Stack only)**
- File: `/root/bin/herdr-dispatch-ack` (v2.0, 259 lines)
- To-Do detection function (lines 171-187):
  ```python
  ids=set(re.findall(r"(?m)^\s*\[(?: |x|✓|•)\]\s+(t[0-9]+)\s+\S", sys.stdin.read()))
  sys.exit(0 if len(ids)>=5 else 1)
  ```
- Explicit comment (line 177-178): "Instruction text/prompt echo is NOT extension state.
  Require five distinct rendered checkbox rows with stable extension task IDs."
- Requires task IDs like `t1`, `t2`, `t3`, etc.

## Q: Can prompt/brief text falsely satisfy To-Do acknowledgement?

### Brief text content analysis

**Pi brief (when harness_supports_todo_list=true):**
```
Before any investigation, edit, test, or other task action, use the harness's
To-Do List extension and create an in-depth dependency-aware tracker with at
least five checkable items: preflight, scoped discovery, bounded work/evidence,
validation, and postflight/closeout.
```
- Contains words "checkable items" but NO checkbox pattern `[x] t1`
- NO `t[0-9]+` task IDs in the instruction text
- Does NOT match the regex

**AGY brief (when harness_supports_todo_list=false):**
```
Before any investigation, write your plan in your first reply as at least five
markdown checkbox items (`- [ ] `), one line each...
```
- Uses markdown `- [ ]` syntax (hyphen-prefixed), NOT Pi extension format
- NO `t[0-9]+` task IDs
- Does NOT match the regex (wrong checkbox format AND no task IDs)

### Prompt-echo scenario

If the agent echoes back the brief text in the pane:
- The echoed text appears in `herdr pane read` output
- Last 80 lines (`--lines 80`) are scanned by `todo_initialized()`
- Echoed instruction text: no `[ ] t[0-9]+` pattern → returns 1 (not initialized)
- Cannot falsely satisfy: instruction text lacks task IDs

### Model-turn echo scenario

If the agent echoes the prompt while remaining idle:
- `model_turn_active()` checks `agent_status == "working"`, NOT text content
- Idle/blocked/done returns immediately → model turn not detected
- Send confirmation also uses agent-state, not text

**CONCLUSION: No Controller-side path exists where prompt echo can falsely satisfy
the To-Do acknowledgement. The discrimination is correct.**

## Q: Does an AGY waiver exist?

Yes, correctly preserved in `fm-brief.sh` (line 217):
```bash
FM_HARNESS_TODO_LIST="claude grok minimax-code pi pi-signed"
# Deliberately NOT listed:
#   agy  the Antigravity/Gemini CLI. A dispatched agy crewmate was
#         observed asking to show a To-Do list it cannot produce
#         (2026-10-11), which is this gate's reason to exist.
```

The waiver produces the non-trivial fallback (markdown checkbox items) rather than
the native To-Do extension requirement, and is preserved in both brief variants.

## Q: Can the Controller fix the acknowledgement mechanism?

**No. The Controller does not invoke `herdr-dispatch-ack` for normal crew dispatch.**

- `fm-spawn.sh` / `fm-send.sh`: use `fm_backend_herdr_send_text_submit` only
- `herdr-send-submit` is called ONLY by `fm-m3-review-loop.sh`
- `fm-m3-review-loop.sh` targets M3 panes (native To-Do), never AGY panes
- `herdr-dispatch-ack` is HD2Stack-owned (`/root/bin/`)

The Controller cannot pass `--trivial` or `HERDR_TRIVIAL_LANE=1` to the
check-in gate because it never calls the gate.

## Owner determination

| Component | Location | Owner |
|---|---|---|
| To-Do acknowledgement detection | `/root/bin/herdr-dispatch-ack` | HD2Stack |
| AGY waiver in brief | `bin/fm-brief.sh` | Controller ✓ preserved |
| Normal crew dispatch | `bin/fm-send.sh` / `bin/fm-spawn.sh` | Controller — no gate invoked |
| M3 review dispatch | `bin/fm-m3-review-loop.sh` | Controller — targets M3 only |

## Missing evidence to unblock

To implement a Controller-side fix, would need HD2Stack access to verify:
1. That `herdr-send-submit` (or a wrapper) is the intended call-point for
   propagating the AGY waiver
2. That the `--trivial` flag in `herdr-dispatch-ack` is the correct escape
   for non-trivial AGY lanes

Without HD2Stack access, the Controller cannot implement or test a fix.
