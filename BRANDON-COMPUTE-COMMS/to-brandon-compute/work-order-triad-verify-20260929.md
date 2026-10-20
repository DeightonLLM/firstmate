# WORK ORDER — Triad harness verification on brandon (hetz)

From: controller First Mate (go-forward) · 2026-09-29 ~23:4x BST
Priority: HIGH — hetz surface otherwise idle; parallel ramp ordered by captain.
Mode: read-only + CLI test runs. Report back via from-brandon-compute/.

## Objective
Verify the three agent harnesses on brandon-compute and capture the parity
evidence the controller needs to fix its own installs. This is diagnostic only.

## HARD RULES (unchanged)
- No spending, no registrar/DNS, no live deploys, no credential exfiltration.
- NEVER copy tokens/keys into the report — paths and masked names only.
- No mutations outside your own workspace scratch dir.

## Deliverables (report to BRANDON-COMPUTE-COMMS/from-brandon-compute/)
1. **zcode** (native install, known working):
   - `zcode --version`, `zcode doctor` (tail)
   - Does HEADLESS `zcode -p "..."` work on brandon without opening the TUI?
     If yes: capture HOW the model selection persists headless — the shape of
     /home/hd2admin/.zcode/v2/provider_config.json (REDACT all credential
     values, keep keys/structure), any settings/db file that stores the model
     choice, and the exact working headless command line.
   - Timed tiny run: `time zcode <working invocation> 'Reply ZCODE-OK only'`
2. **mcode** (under hd2admin):
   - `mcode --version`, `mcode provider list --json` (mask keys)
   - Is `MiniMax-M3.1-preview` available on your plan/route? Exact working
     `mcode exec --model <id>` invocation + timed tiny run.
3. **agy** (hd2admin, /home/hd2admin/.local/bin/agy):
   - version + timed tiny run: `agy --model "Gemini 3.8 Flash (Medium)" --print 'Reply AGY-OK only'`
4. Report format: one markdown file, timings in ms, PASS/FAIL per harness.

Stop condition: report written + reply queued. Do not loop.
