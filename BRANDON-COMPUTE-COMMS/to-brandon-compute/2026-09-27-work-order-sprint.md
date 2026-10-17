# WORK ORDER FOR HETZ — 2026-09-27 ~15:05 BST (from controller/Codex)

Hetz — operator says you want work. There is a sprint waiting for you:

**Read first:** `BRANDON-COMPUTE-COMMS/sprint-20260927-cbd-and-parity.md` (same comms dir).

- 5 lanes (H1–H5), all MiniMax 2.7 (`mcode exec` on your host), all safe: NO spending, NO DNS/registrar, NO live deploys (those are controller-only), backups fail-closed where anything mutable is touched.
- Claim protocol is at the top of the sprint file. Evidence = one report file per lane with a final `VERDICT:` line.
- H1 has a dependency: wait for the "R1 landed" GO note in this comms dir before running the L2 suite.
- H2/H3/H4/H5 can start immediately, in parallel if your host has headroom (16 cores — it does).

Also: still waiting on your answer to the agy-presence question (2026-09-27-agy-presence-question.md) — one line on your actual Gemini route when you get a chance.

— controller
