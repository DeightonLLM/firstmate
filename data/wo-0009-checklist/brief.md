# WO-0009 lane 2 - acceptance-criteria checklist so domain completion is reproducible (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort **high**. **Worktree:** `/tmp/wt-wo0009-checklist`, branch `wo-0009/acceptance-checklist`.

## Why this exists
The Captain asked for a completion percentage per domain. I produced one, then had to say plainly:

> "These percentages are my judgement... they are not computed from a machine-readable checklist,
> because the PRDs do not expose one. **I would be inventing the denominator.**"

**That is the gap. Fix it.**

## Your task
Produce a **machine-readable acceptance checklist per domain**, then **score every domain against it**
and report a percentage that anyone can reproduce.

### Source material - read all of it before writing
- `data/wo0005-2-domain-prds/report.md` - the seven domain PRDs with owners
- `data/2026-10-15/` - tonight's audit reports, including the Whoosh and Core findings
- `docs/system-context/hosts.yaml` - authoritative host registry
- the live surfaces themselves

### Domains
```
core-distro.com   cbd-data.com   data.core-distro.com   elevatesci.com
agents.elevatesci.com   staging.core-distro.com   whooshperformance.com
```

## Rules for the checklist
- Each criterion must be **objectively checkable** - someone else must be able to run it and agree.
- Mark each one of: `PASS`, `FAIL`, `UNVERIFIED`, or `N/A` with a stated reason.
- **UNVERIFIED is a real and correct answer. Never convert it to PASS to make a total look better.**
- `whooshperformance.com` is a **new domain, website pending delivery from an external developer.**
  A parked page is the CORRECT current state, not a defect. Do not score it as a failure.
- **`staging.core-distro.com`'s serving host is UNKNOWN and must stay UNKNOWN.** Do not resolve it from
  DNS, PTR, or a legacy alias. Record it as UNKNOWN.

## Deliverable
1. A checklist file, one entry per criterion, machine-readable (TSV or JSON), with the status of each.
2. A scored percentage per domain, **derived from the file**, not asserted.
3. The total, and what would move it.

## Hard rules
- **Read-only against every live site.** No writes, no deployment, no DNS, no credentials.
- **Never touch `srv1137994` / animovps / Aminolifesciences / elevatesVPS in any form.**
- Verify by observation. Never infer a PASS from a file existing, and never from HTTP 200 alone -
  a parked page returns 200.

## Rules
- Work ONLY in /tmp/wt-wo0009-checklist. Read-only on projects/ and all app directories.
- Commit on branch wo-0009/acceptance-checklist. No merge, no push, no rebase of main.
- If bash is denied, report it verbatim as the finding and stop. Do not route around it.

## Report
data/wo-0009-checklist/report.md - the scored table, the per-domain percentage derived from the file,
and one line naming the single biggest blocker to completion.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
