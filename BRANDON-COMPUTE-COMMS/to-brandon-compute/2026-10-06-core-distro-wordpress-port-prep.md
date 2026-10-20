# WORK ORDER — BRANDON-COMPUTE HETZNER SECONDMATE PREPARATION & STAGING

**Date:** 2026-10-06 01:35 UTC  
**Sender:** Controller (vmi3196300)  
**Target Surface:** Hetzner Secondmate (`hd2admin` on brandon-compute 100.106.6.22)  
**Workspace:** `/home/hd2admin/kun-agent-workspace`  
**Active Projects:** `cbd-campaign`, `core-distro`, `cbd-data`  
**Standard Applied:** `WAR-ROOM-LANE-STANDARD.md` & `/root/.agents/skills/hd2-stack-astra-port/SKILL.md`  

---

## 1. Directive & Core Objectives (Preparation & Queue Only — DO NOT Execute Live Port)

Per Captain directive 2026-10-06:
1. **Leftover Jobs & Workspace Audit**:
   - Sweep and inventory every leftover job, dangling background task, and stale process across `/home/hd2admin/kun-agent-workspace/` on `brandon-compute`.
   - Clean up workspace clutter and stale scratch trees while preserving verified artifacts.

2. **Skill Drift Integrity Check**:
   - Execute `/root/bin/skill-drift-check --check` across active skill trees.
   - Reconcile any skill drift against the pinned baseline and report findings.

3. **War-Room Layout Setup**:
   - Establish standard 2×2 grid layout across active worker tabs (`WAR-ROOM`).
   - Preserve main controller pane protection.

4. **Prepare Staged Port of `core-distro.com` to WordPress**:
   - Skill Reference: [`/root/.agents/skills/hd2-stack-astra-port/SKILL.md`](file:///root/.agents/skills/hd2-stack-astra-port/SKILL.md).
   - Approach:
     - Try vanilla WordPress structure first.
     - Astra plugin license is available on HD2 stack as fallback if vanilla cannot faithfully reproduce components.
   - Asset & Token Harvest:
     - Re-use or verify local crawl data at `/tmp/core-crawl/` (manifest, screenshots at 1440px + 390px, logo marks).
   - Staging Target:
     - Staged Docker containers on brandon-compute (`mariadb` + `wordpress:latest` under container name `core-distro-wp-stage`).
     - Preview via animovps `staging.core-distro.com` vhost.
     - **HARD SAFETY GATE**: DO NOT touch live webroot or DNS. Do NOT execute the port yet — prepare assets, tokens, Docker staging scripts, and queue the tickets only.

---

## 2. Reporting
Deliver status report, skill-drift output, and staging plan back to:  
`/root/agent-work/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/from-brandon-compute/20261006T-core-distro-prep-status.md`
