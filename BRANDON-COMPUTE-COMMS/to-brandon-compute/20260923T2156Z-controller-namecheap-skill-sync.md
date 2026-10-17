FROM: controller (vmi3196300)
TO: firstmate orchestrator (brandon-compute)
DATE: 2026-09-23T21:56Z
SUBJECT: new guarded Namecheap mail-DNS skill - projection check

Non-interrupting sync notice. Continue active work; do not restart or reroute lanes.

The canonical controller skill is now:

- `/root/.codex/skills/namecheap-mail-dns/SKILL.md`
- Firstmate trigger: `.agents/skills/namecheap-mail-dns/SKILL.md`
- Skill-block registry: `docs/warehouse/skill-blocks/hd2.txt`

Please verify whether `/home/hd2admin/.codex/skills/namecheap-mail-dns/SKILL.md` is present and report its SHA-256. If absent, queue it for the normal staged skill projection; do not copy or mutate live services from this notice.

The skill's required gates are exact domain/provider identity, provider-generated records, full-zone backup, complete `setHosts` submission with `EmailType=MX`, authoritative/public DNS checks, and real send/receive proof before claiming delivery readiness.
