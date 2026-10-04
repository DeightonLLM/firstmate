# SYSTEM-SEC-HEALTH-20260928 — Consolidated Findings & Mutation List

**Compiled:** 2026-09-28 23:55 BST · **Updated:** 2026-09-29 00:50 BST (mutations executed) · **Coordinator:** wD3:p2 (mvs_dc8f05…) · **Status:** controller campaign complete + verified; ALL operator-GO'd mutations executed; brandon revision in flight

## Verification summary

| Artifact | Size | Independent review | Verdict |
|---|---|---|---|
| SECRETS.md | 11,267 B | REV-A (live rc=0/197 paths/993 quarantine) | CHECK_PASS |
| SUPPLYCHAIN.md | 20,416 B | REV-B (3/3 spot-checks match) | CHECK_PASS |
| AGENTSEC.md | 30,519 B | REV-A (39/39 stale-claim tests) | CHECK_PASS |
| HARDEN.md | 34,069 B | REV-B (3/3 spot-checks match) | CHECK_PASS |
| HEALTH-RETRO.md | 27,134 B | REV-B (3/3 spot-checks match) | CHECK_PASS |

Zero mutations were performed by any lane. Everything below is a recommendation awaiting operator GO.

## Key findings

- **Secrets posture:** controller scan PASSING (rc=0, 197 baselined); 993-file quarantine intact; brandon scan baseline verified byte-identical. Open: pnpm-store exclusion/baselining (SECRETS §7).
- **Agent guard chain (5 gaps):** GAP-01 HIGH raw `send-text`/`send-keys` bypass all dispatch gates; GAP-02 HIGH un-namespaced coords file collides across concurrent runs; GAP-03 HIGH ledger parser admits trailing/negative denials; GAP-04 MEDIUM `PRODUCTION_OVERRIDE` prompt token bypasses live checks (01/02 extensions); GAP-05 LOW stale-claim redirect regex defeated by quoted targets.
- **Host hardening:** hd2stack exposes 22/tcp publicly (1,178 failed SSH attempts) despite Tailscale rule; brandon has pending security updates (python3-jwt, python3-requests, dracut-install); controller SSH sees 182 active fail2ban blocks on public 22.
- **Supply chain:** no compromise found; CI actions pinned to mutable tags (MEDIUM); CI downloads jq/tasks-axi without checksums (LOW); only herdr/senpi have pre-update snapshot+rollback — pi/codex/claude/omp/agy update paths can strand broken binaries (this is exactly the 2026-09-24 codex hollow-package failure); `@code-yeongyu/*` system symlinks live inside node_modules (LOW).
- **Health/retro:** shellcheck warnings in `/root/bin` (incl. herdr-worker-pane, since quoted); post-mortem for today's session corruption + mcode/codex breakage with prevention actions (end-of-shift context checkpointing — now operational via watcher discipline; see SESSION-RECOVERY record).

## MUTATION LIST — EXECUTION STATUS (operator GO "all", 2026-09-28 23:58)

| # | Item | Status | Receipt |
|---|---|---|---|
| 1 | hd2stack UFW: remove public 22 | ✅ DONE | v4 + v6 Anywhere rules deleted; only `22/tcp ALLOW 100.64.0.0/10` remains |
| 2 | brandon security updates | ✅ DONE | python3-jwt 2.7.0-1ubuntu0.2, python3-requests 2.31.0+dfsg-1ubuntu1.2, dracut-install 060+5-1ubuntu3.4 (ii) |
| 3 | controller SSH restricted | ✅ DONE | Tailscale allow added, public v4 (1panel) + v6 rules deleted; only tailscale-allow remains |
| 4 | intent-guard GAP-02/03 | ✅ DONE | MUT-INTENTGUARD.md: suites 15/15 + 10/10 green |
| 5 | pi extensions GAP-04/05 | ✅ DONE | MUT-PIGATE.md: stale-claim suite 44/44 (5 new red-first cases) |
| 6 | herdr raw send gate GAP-01 | ✅ DONE | MUT-HERDRGATE.md + wrapper live at /root/.local/bin/herdr (gate caught herdr-review-send as ungated caller; token added — gate proven in production) |
| 7 | CI pinning + checksums | ✅ DONE | commit 53e473c (local, NOT pushed); 15/15 SHAs, jq checksum, tasks-axi removed |
| 8 | pre-update snapshot/rollback | ✅ DONE | MUT-SNAPSHOT.md: selftest PASS (dummy binary snapshot→failed-verify→rollback); contract unchanged |
| 9 | pnpm-store exclusion | ✅ DONE | both scanners patched; controller rescan PASS (197 paths) |
| 10 | @code-yeongyu relocation | ⏸ DEFERRED | rewires agy/herdr/bun entry points fleet-wide; LOW severity — needs its own change window |

All five mutation lanes executed with red→green evidence, sub-agent plans declared up front; transcripts in `/tmp/final-p29…p2D.txt`; coordinator acceptance recorded 2026-09-29 00:45 BST.

### Original item detail (pre-execution reference)

1. **hd2stack UFW:** delete `22/tcp ALLOW IN` (keep Tailscale-only SSH). Host: hd2stack. Risk: locks out non-Tailscale access path if any exists.
2. **brandon-compute:** `apt install` 3 pending security updates (python3-jwt, python3-requests, dracut-install). Host: brandon.
3. **controller:** restrict public 22 to Tailscale/VPN sources in UFW (keep current ssh session alive; break-glass console confirmed first). Host: controller.
4. **agent-intent-guard:** namespace coords files per-lane + tighten ledger parser (GAP-02/03). Controller-local code fix + tests.
5. **pi extensions:** remove/lock `PRODUCTION_OVERRIDE` token path (GAP-04); quote-aware redirect regex in 07-stale-claim-guard (GAP-05).
6. **herdr:** gate raw `send-text`/`send-keys` behind the dispatch gates or restrict to coordinator (GAP-01).
7. **CI:** pin actions to commit SHAs; SHA256-verify jq download; (optional) drop `npm install -g tasks-axi` from CI.
8. **herdr-agent-start-fresh:** extend senpi-style snapshot/rollback to pi/codex/claude/omp/agy refresh phases.
9. **SECRETS:** pnpm-store exclusion or baselining pass.
10. **node_modules hygiene:** relocate `@code-yeongyu/*` system symlinks outside `/usr/local/lib/node_modules`.

## In tandem (brandon-compute = Hetzner AX42-2 plane) — FINAL

mcode worker (MiniMax-M3.1-Flash-Preview) completed the host-local audit set (BRANDON-AUDIT.md, 36,751 B after revision round 1); the mcode controller-reviewer on brandon (BRANDON-REV.md, 22,856 B) returned HARDEN **CHECK_PASS**, SUPPLYCHAIN-LOCAL **CHECK_PASS**, SECRETS-VERIFY **REVISION_REQUIRED** → revision round 1 completed 00:49 BST.

**Final brandon security state:** scanner repaired (a controller-side sed regression introduced a stray-character array element → rc=2 scanner ERROR; fixed and verified — honest note: the regression was introduced by the coordinator during item 9, caught by the brandon reviewer, repaired by coordinator). Live scan now runs correctly with **rc=1 and 2 findings, reported NOT touched** (leak protocol — operator decision required):

1. `/home/hd2admin/.codex/sessions/2026/09/28/rollout-…jsonl` — codex session transcript (known runtime-artifact class; see SECRETS.md rec #2 session-rollout lifecycle).
2. `/home/hd2admin/.dsh/.credentials.yaml` — **sensitive-named credentials file, never baselined** — ⚠️ operator triage required: classify, then quarantine/rotate per this morning's workflow.

Other brandon audit results: mcode symlink $0 bug **reproduced on brandon** (same wrapper defect fixed on controller — brandon's `~/.local/bin/mcode` needs the same trampoline fix; NOT applied, needs GO); pending-updates item already executed (mutation #2).

## Holds, gaps & hd2stack triage outcome

- **hd2stack triage COMPLETE (2026-09-29 02:13 BST):** of the 1,856 flagged files — **27 session-rollout transcripts (103 MB) quarantined** to hd2stack `/root/.quarantine/leak-triage-20260929/` (structure preserved, verified: 4 dirs / 30 files incl. dotfiles); **268 files (14.4%) = REAL production credentials** inside `/root/backups/controller-backups/*/{.env,.env.bak.*}` (Amino, Music, Multica backup snapshots) — **REPORT-ONLY, preserved in place, contents never read**; remainder = documented classes with recommended scanner globs (hd2stack scanner untouched). Evidence: MUT-HD2STACK-TRIAGE.md. ⚠️ **Operator decision:** rotation scope for the 268 backup-credential families + whether `/root/backups/controller-backups/` moves to restricted storage. hd2stack CLIs may now be updated via `/hygiene` (hd2stack not-installed: mcode).
- **KVM1 (`srv797124`):** no ssh alias — one-time setup needed to join hygiene runs.
- **elevatesVPS claude:** unused per operator — skipped (newer extension builds 2.1.272/274 exist under antigravity-ide-server if ever needed).
- **Rollbacks used:** none — no update required a rollback.

## Evidence index

`/root/agent-work/firstmate/docs/audits-20260928/` — SECRETS.md, SUPPLYCHAIN.md, AGENTSEC.md, HARDEN.md, HEALTH-RETRO.md, REV-A.md, REV-B.md · lane transcripts `/tmp/final-*.txt` · recovery record `/root/agent-work/SESSION-RECOVERY-mvs-c890dcea-20260928.md`
