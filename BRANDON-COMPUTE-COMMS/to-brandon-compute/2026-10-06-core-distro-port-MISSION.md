# MISSION BRIEF — CORE-DISTRO WORDPRESS PORT (SECONDMATE)

**Date:** 2026-10-06 02:45 UTC
**Target:** hetzner secondmate (hd2admin on brandon-compute 100.106.6.22)
**Mission:** Staged port of core-distro.com to WordPress
**Priority:** HIGH — captain wants a win
**Standard:** WAR-ROOM-LANE-STANDARD.md, hd2-stack-astra-port SKILL.md
**Astra license:** available as fallback, try vanilla first

---

## TO-DO LIST (INFO FIRST — 12 ITEMS, COUNTED)

1. **[ ] WAR ROOM SETUP** — Set up 2x2 herdr war room on brandon (herdr at /home/hd2admin/.local/bin/herdr). Add to PATH. Create WAR-ROOM tab with 4 equal panes. Rename panes with lane labels. Apply warroom-guard.
2. **[ ] SKILL SYNC** — Run /root/bin/skill-drift-check --check. Reconcile any drift. Pull latest firstmate skills from origin (fast-forward only, skip if diverged). Verify hd2-stack-astra-port skill at /root/.agents/skills/hd2-stack-astra-port/ is current.
3. **[ ] LEFTOVER SWEEP** — Audit /home/hd2admin/kun-agent-workspace/ for stale worktrees, dead agents, scratch dirs. Reap anything stale. Preserve verified artifacts.
4. **[ ] CRAWL HARVEST** — Check /tmp/core-crawl/ for existing manifest, logos, typography. If missing, run bounded crawl of core-distro.com (respect robots.txt, rate-limit, only public pages). Save to /home/hd2admin/kun-agent-workspace/cbd-campaign/core-distro-crawl/.
5. **[ ] DESIGN TOKEN EXTRACTION** — Extract color palette, typography, spacing, component specs from current core-distro.com. Use chrome-devtools-axi or curl + parse. Save design tokens to core-distro-crawl/tokens.json.
6. **[ ] WORDPRESS STAGING SETUP** — Create docker-compose on brandon for core-distro-wp-stage: mariadb + wordpress:latest. Use staging.core-distro.com vhost via animovps (read-only DNS check, no live mutation). Save compose to /home/hd2admin/kun-agent-workspace/cbd-campaign/core-distro-stage/.
7. **[ ] VANILLA WORDPRESS STRUCTURE** — Build vanilla WordPress structure first: themes, plugins, menus, pages matching current site IA. NO Astra yet. Document at core-distro-stage/structure.md.
8. **[ ] ASTRA FALLBACK EVAL** — Only if vanilla can't match design fidelity: install Astra plugin + starter template. Document decision at core-distro-stage/astra-decision.md.
9. **[ ] CONTENT MIGRATION PLAN** — Map current core-distro.com pages to WP pages/posts/custom-post-types. Preserve SEO URLs. Document at core-distro-stage/migration-plan.md.
10. **[ ] CI/TEST PLAN** — Write bounded tests: docker compose up, healthcheck, page render check, visual diff vs live. Use no-mistakes axi if available. Document at core-distro-stage/test-plan.md.
11. **[ ] DOCS SYNC** — Update /root/agent-work/warehouse/chatbots/INDEX.md and relevant policy docs. Sync any new skills back to controller via BRANDON-COMPUTE-COMMS/from-brandon-compute/.
12. **[ ] STATUS REPORT** — Write progress to /home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-06T-core-distro-mission-status.md. Append to /root/agent-work/deightonllm-firstmate/state/hd2stack.status with [key=core-distro-port] marker. Report back via this comms queue.

---

## GATES (DO NOT VIOLATE)

- NO live DNS mutation
- NO production webroot cutover
- NO spending (domains, hosting, SSL)
- NO credential use without explicit bounded authorization
- Backup before any mutation
- Warroom-guard on every layout op
- 2x2 layout equal panes
- Main controller pane untouched

---

## REPORTING

Append to state: `echo "working [key=core-distro-port]: <step>" >> /root/agent-work/deightonllm-firstmate/state/hd2stack.status`
Final report: `/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/from-brandon-compute/2026-10-06T-core-distro-mission-status.md`
Corr token: `corr=core-distro-port-20261006`
