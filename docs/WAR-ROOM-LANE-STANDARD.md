# WAR-ROOM LANE STANDARD (v2 — captain directive 2026-10-05)

Every worker pane gets a human Lane identifier at spawn. The captain references lanes by
letter ("Lane B keeps asking permission"); every alarm, artifact, and board entry uses the
same letters. This is spawn mechanics, not optional styling.

## 1. Spawn checklist (all three steps mandatory)
1. Launch the worker TUI in the pane (`herdr pane run <pane> mcode` + feeder-style submit).
2. Rename the window: `herdr pane rename <pane> "LANE-X . <role>"` — the label is what the
   captain sees on the open herdr window. An unlabeled worker window is a defect.
3. Register it: `state/lanes/lane-<letter>.lane` on the worker host with:
   ```
   pane=w6:pF
   name=LANE-A widget-spec-v2
   ```
   Registration is what arms the feeder's auto-allow for `Approval required` dialogs.
   An unregistered pane's approvals become the captain's manual clicks — that is a defect.
3. Mirror the mapping in BOARD.md under the active block.

## 2. Current lane map (hd2stack war-room; mirror in BOARD.md)
- **LANE-A** = w6:pF — widget patch spec v2
- **LANE-B** = w6:pG — ZCode firstmate-fit prep
- **LANE-C** = w6:pJ — widget apply standby (gated on APPROVED spec-v2)
- **LANE-D** = w6:pK — coding-surface parity audit
- **LANE-E** = w6:pE — fixture/cutover lane (verdict recorded)
- **LANE-F** = w6:pH — standby Gemini re-reviewer (agy; on-demand)
- **LANE-R** = brandon w1E:p6 — RAG TTFT tuning (separate host)

## 3. Watcher alarms (hd2fleet.check.sh, registered)
- RAW-SHELL pane (dead agent / jumbled text) — named by lane
- APPROVAL dialog persisting past the feeder's 3-min auto-allow — named by lane
- RESEARCH/STUDY artifact missing `## LOCAL EVIDENCE` (RESEARCH-LANE-STANDARD)

## 4. Host scope
Lane letters are unique per host; brandon-host lanes prefix R. dubz (controller) runs no
worker lanes by standing order — kept free for emergencies.

## Gemini model routing (captain-locked 2026-10-05)
- Basic tasks: Gemini 3.8 Flash **Medium**. Review-model tasks: Gemini 3.8 Flash **High**.
- Enforcement: dispatch via `/root/bin/agy-route.sh basic|review ...` — the wrapper pins the model; hand-set `--model` on lane prompts is a policy breach.
