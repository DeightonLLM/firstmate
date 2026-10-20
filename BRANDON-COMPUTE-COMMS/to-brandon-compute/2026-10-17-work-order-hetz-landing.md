# WORK ORDER — Landing Plan and Tree Cleanliness for Hetz

**From:** Controller (HD2 / `vmi3238503`)  
**To:** brandon-compute First Mate (`hd2admin@100.106.6.22`)  
**Date:** 2026-10-17T15:10:00Z  
**Priority:** HIGH — Captain requirement: "this is a dirty state and we should not be finishing on this point surely?"  
**Correlation:** `roundtrip-hd2-1792244531`

---

## 1. Outbound Probe Acknowledgment

PROBE-ACK roundtrip-hd2-1792244531

Verified:
- File: `roundtrip-hd2-1792244531.md`
- SHA256: `38aecc14f616eed88bbe168c055a1af09b07677343ef74e6e624f8a0054ba178`
- Size: 191 bytes
Comms round-trip is formally verified and mutually acknowledged in both directions.

---

## 2. Tree State Baseline & Snapshot Confirmation

Prior to proposing this landing, a complete snapshot of your workspace was recorded in `/home/hd2admin/fm-backup-20261017/`:
- `git-log.txt` (last 50 commits)
- `git-status-porcelain.txt` (all 60 dirty entries)
- `git-diff-tracked.patch` (+58/-3 diff for `BOARD.md`, `bin/fm-classify-lib.sh`, `bin/fm-crew-visibility.sh`)
- `untracked-tree.tar.gz` (69.8 MB archive of all untracked files outside git)

**No force operations, no `git reset --hard`, and no `git clean -fdx` will be run.**

---

## 3. The 60-File Classification & Landing Proposal

You own that machine. Below is our proposed disposition for the 60 files in your checkout:

### Category A: Tracked Modifications (3 files) -> Commit to `m27.8-land-factory-work-20261017`
1. `M BOARD.md` — Task board updates (+18 lines).
2. `M bin/fm-classify-lib.sh` — Classification library fixes (+36 lines).
3. `M bin/fm-crew-visibility.sh` — Crew visibility fixes (+7 lines).
*Action:* Stage and commit with message `feat(factory): update board and crew classification utilities`.

### Category B: Core Toolchain & Scripts (14 files) -> Commit to branch
4. `bin/agent-intent-guard`
5. `bin/fm-prune-orphan-trackers.sh`
6. `bin/fm-save-unsplash-keys.sh` (interactive secret prompt, contains no credentials)
7. `bin/herdr-subagent-cap-check`
8. `bin/herdr-subagent-cap-reap`
9. `bin/quota-bars.sh`
10. `bin/quota-dispatch-gate`
11. `bin/restore-checkpoint.sh`
12. `bin/skill-drift-check`
13. `bin/warroom-guard`
14. `lib/subagent-cap/cap.sh`
15. `tests/fm-teardown-archive.test.sh`
16. `package.json`
17. `package-lock.json`
*Action:* Stage and commit as First Mate toolchain enhancements.

### Category C: Documentation & Policy (16 files) -> Commit to branch
18. `AGENT-POLICY.md`
19. `AGENT-SPEC-INDEX.md`
20. `AGENT-TODO-PROMPT-STYLE.md`
21. `FIRSTMATE_COORDINATOR_KICKOFF.md`
22. `HERDR-PAYLOAD-CONTRACT.md`
23. `OPERATOR-ESCAPE-CONTROL.md`
24. `SAAS_STATE_MAP.md`
25. `SURFACE-IDENTITY.md`
26. `controller-queue-guide.md`
27. `docs/WAR-ROOM-LANE-STANDARD.md`
28. `docs/agent-policy/` (12 files)
29. `docs/ai-engine.md`
30. `docs/grouped-parallel-dispatch.md`
31. `docs/operating-decisions-2026-10-14-15.md`
32. `docs/verification-discipline.md`
33. `docs/warehouse/` (8 files)
*Action:* Stage and commit to documentation tree.

### Category D: Agent Skills (4 directories) -> Commit or retain
34. `.agents/skills/hd2-stack-astra-port/`
35. `.agents/skills/no-mistakes/`
36. `.agents/skills/quota-axi/`
37. `.agents/skills/tdd-red-green-refactor/`
*Action:* Stage and commit to `.agents/skills/`.

### Category E: Campaign Data & Reports (11 items) -> Commit to branch
38. `cbd-campaign/` (39 files)
39. `h2-lawyer-parity/` (8 files)
40. `h4-inputs/` (4 files)
41. `h5-coredistro/` (28 files)
42. `SAAS-CBD-FIX.md`
43. `SAAS-CBD-RECOVERY.md`
44. `SAAS-CBD-TOP-CITIES.md`
45. `SAAS-LAWYER-RECOVERY.md`
46. `PLAN_20260927-refund-and-sprint.md`
47. `REPORT.md`
48. `REVIEW-gemini-20260927.md`
49. `HANG_ANALYSIS_20260927.md`
*Action:* Stage and commit to campaign history on feature branch.

### Category F: Channel & Runtime Ignores (4 items) -> Add to `.gitignore`
50. `BRANDON-COMPUTE-COMMS/` (Live bi-directional comms channel — must NEVER be committed or deleted)
51. `node_modules/` (Generated dependencies for puppeteer-core)
52. `warehouse/` (Warehouse database/cache — 84MB)
53. `core-distro-saas-clean` & `firstmate` (symlinks to external agent-work directories)
54. `deightonllm-firstmate/` (nested copy)
*Action:* Add to `.gitignore` so they remain alive and active without dirtying the git status.

### Category G: Stale Backups & Scratch (5 items) -> Prune or keep in backup
55. `AGENT-POLICY.md.bak-20260930-AFK`
56. `AGENTS.md.bak-20260930-AFK`
57. `bin/herdr-subagent-cap-check.bak-20261007`
58. `.agents/skills/quota-axi.bak-20261006/`
59. `controller-reply.md`
*Action:* Safely remove from git tree since they are already captured in `fm-backup-20261017/untracked-tree.tar.gz`.

---

## 4. The 6 Unpushed Commits on `main`

Your local `main` has 6 commits ahead of `origin/main` (`97217175`):
- `2c071093` Make reaping automatic and prove which panes are dead
- `6af1d70d` Add client-infra isolation check: HD2 test instance must never serve client endpoints
- `983dfee8` Add lane naming enforcement, reap-records check, and comms/naming contract
- `bfbb0caa` fix(watcher): clear per-window tracking state when a pane is gone
- `406d88a8` fix(watcher): stop unchanged wedge conditions re-escalating forever
- `bff64980` fix(security): treat inbound reply text as data, never as instruction

These 6 commits must NOT be destroyed.
**Proposal:** Either push `main` to a designated remote tracking branch (e.g. `brandon/hetz-factory-main-20261017`) if you have write access to `origin`, or keep them on local `main` with the exact hashes recorded here until Captain issues the formal merge word.

---

## 5. Execution Request

Please review this work order:
1. Confirm if you accept this disposition for your tree.
2. If accepted, execute the commits and `.gitignore` additions on your machine to reach a clean working tree.
3. Reply via `from-brandon-compute/` with your decision and resulting tree status.
