# Agent To-Do Prompt Style & Left-Hand Metadata Standard

**Status:** ACTIVE & ENFORCED. Applies to every dispatched lane, worker agent, subagent, and async task across all surfaces.  
**Authority:** Captain Directive (2026-10-18)

---

## 1. Required Left-Hand Metadata Prefix

Every To-Do item, plan entry, and async task status MUST begin with the metadata badge placed **early on the left-hand side** of the text.

### Canonical Prefix Formats:

```
[<ModelAbbrev> <Speed/Effort> @ <Host>] <Task Description>
```
or
```
[<Harness>·<ModelAbbrev> <Effort> @ <Host>] <Task Description>
```

### Component Definitions:
- **`<ModelAbbrev>`**: Short model identifier:
  - `M3.1F` (MiniMax M3.1 Flash)
  - `G38F` / `Gemini 3.8` (Gemini 3.8 Flash Medium)
  - `GLM53` (GLM 5.3 Flash)
  - `Luna6` (Codex Luna 6 MAX)
- **`<Speed/Effort>`**:
  - `HS` (High Speed) / `NORM` (Normal)
  - `l` (low) / `m` (medium) / `h` (high)
- **`<Harness>`**: `pi`, `agy`, `codex`, `mcode`, `claude`
- **`@ <Host>`**: Execution host where the agent runs:
  - `@ Dubz` / `@ Controller` (`100.117.47.27`)
  - `@ HD2` (`100.71.95.76`)
  - `@ Hetz` / `@ Brandon` (`100.106.6.22`)
  - `@ Elevate` (`100.69.211.43`)

---

## 2. Live Canonical Reference (Crisp-R Controller Format)

```
Updated Plan
└ [•] [M3.1F m @ Dubz] Async tracker test-only repair dispatch
  [✓] [M3.1F @ Dubz] Fast review and independent check
  [ ] [G38F m @ HD2] Bounded policy and baseline verification
  [ ] [GLM53 h @ Hetz] Independent checker and verification pass
  [ ] [M3.1F m @ Dubz] Closeout reconciliation and roadmap sync
```

---

## 3. Dispatched Worker & Subagent Prompt Standard

Every dispatched prompt to a subagent, Second Mate, or Herdr lane MUST include this explicit instruction:

```markdown
Use the To-Do List extension before your first task action.
Every item MUST start with the left-hand metadata prefix:
[<ModelAbbrev> <Speed/Effort> @ <Host>] <Action>
(e.g., [M3.1F m @ HD2] or [G38F m @ HD2])
At least 5 visible items with a dependency chain (t1 → t2 → t3 → t4 → t5).
Filesystem TODO trackers are strictly forbidden.
```

---

## 4. Enforcement Gate

- Any task list, plan, or subagent report lacking the left-hand metadata badge is classified as **`FORMAT_DEFECT`** and rejected at review.
- The coordinator must display this prefix in all progress updates to the Captain so agent type, harness, speed, and execution host are instantly visible without scrolling.