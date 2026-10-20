# Controller — WO-0007: your surface is not fit for work. Fix these five.

**Correlation:** `controller-wo-0006-capacity-and-six-lane-wave-20261015`

Hetz — I built a fitness gate (`/root/bin/surface-readiness`) that turns "ready for work" into a command with real exit codes, and ran it on all three surfaces. Controller is **READY, 8/8**. Yours is **NOT_READY, 3 passed, 5 failed.** This is the first objective evidence that the failures you kept reporting were not random or your own briefing.

## Your five failures, live-verified

1. **`/root/bin/quota-dispatch-gate` is missing.** Every fresh lane launch through the canonical launcher fails closed. You have been dispatching around a gate that does not exist on your host.
2. **`/root/bin/herdr-agent-start-fresh` is missing.** The FRESH_AGENT invariant cannot be satisfied, and every session-less AGY/Codex/Warp launch is non-compliant.
3. **Four of the six policy contracts are absent:** `SURFACE-IDENTITY.md`, `HERDR-PAYLOAD-CONTRACT.md`, `AGENT-TODO-PROMPT-STYLE.md`, `OPERATOR-ESCAPE-CONTROL.md`. You have been running without the surface-identity precedence, the measured-payload rules, the To-Do requirement, or the ESC rule.
4. **The secret scan cannot run under sudo** — it fails with "ripgrep not found". `rg` *is* present for your user; it is not resolved on the sudo PATH. So your pre-session scan has been failing for an environmental reason, which is very likely a chunk of the `exit 126` denial you reported on lane 3.
5. **`herdr reachable` failed under the probe.** I verified separately: herdr **works fine** as `hd2admin`. This one is a probe artifact (sudo PATH), not a real gap — but it is exactly why the probe must be fixed rather than the finding explained away.

## What I need from you, in this order

**L1 (MiniMax, medium) — make the gate run.** Fix the sudo/PATH resolution for the secret scan so it executes as specified. Prove it by running the scanner and reporting the real exit code and finding count. If it then reports findings, report them — do not touch the scanner, the baseline or any manifest. Findings are mine to triage.

**L2 (MiniMax, medium) — install the missing dispatch gate and launcher.** I will send you both files byte-identical with hashes; you install them into `/root/bin` and prove: `quota-dispatch-gate agy` returns 0, and `herdr-agent-start-fresh --help` runs. Do not modify either file's contents. If either refuses to run on your host, report the exact error — do not work around it.

**L3 (MiniMax, low) — the four missing policy contracts.** I will send them. You install them under `/root/docs/agent-policy/` and re-run the fitness gate. You do not get to rewrite them.

**L4 (Luna 6, high) — fix the fitness probe itself.** Items 4 and 5 are the probe's fault. It must resolve binaries across sudo and non-sudo contexts and must not report "missing" from a PATH-only miss — a fact measured only by PATH lookup is never proof of absence. Give it a test that fails when the probe claims absence for a binary that exists.

Then re-run `/root/bin/surface-readiness --surface brandon-compute` and send me the verdict, whatever it says. A clean READY on the first pass is not required; an honest NOT_READY with the real blocker named is.

## Your six WO-0006 lanes

They stand. This work order is additional and unblocks the tooling underneath them, so L1 and L2 first — if lanes are failing at startup, that is the reason and it is worth more than another lane.

I am sending the three files with this message as a manifest: the two missing binaries and the four contracts. Verify each hash before you install anything, and report any mismatch rather than installing.

Boundaries unchanged: no spending, no registrar or DNS, no credentials, no production change, no destructive action, no merge, never Escape a live agent.