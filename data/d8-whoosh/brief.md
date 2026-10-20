# WO-0016 - Whoosh: define the intake, do not build (Luna 6, medium)

**Model:** openai-codex/gpt-6-luna, effort medium. Worktree: /tmp/wt-d8-whoosh, branch d8/whoosh.

## Context - do not misread this
`whooshperformance.com` is a **NEW domain. The website has NOT been delivered yet.** The Captain is
awaiting it from an external developer. Planned shape: a **GH-level SaaS scraper plus a WordPress
site.** A parked page is the CORRECT current state - it is **not a defect and not a failure.**

An earlier lane reported `VERDICT: WHOOSH DOES NOT EXIST` and I framed it like a discovery. That was
wrong - absence of expected work looks identical to absence of work unless you check.

## Your job - prepare the INTAKE so delivery is fast when it lands

1. **Write the acceptance criteria for the delivered site.** What must be true for Whoosh to be
   accepted? Be specific and objectively checkable - someone else must be able to run each one.
   Cover: DNS and TLS, the WordPress install, the scraper's function, any auth, and the handover.
2. **Write the intake checklist for the developer delivery.** What must they hand over, in what form,
   for us to accept without a second round. Include: repo access, WP admin, DNS access, any API keys
   (by name only, never values), staging URL.
3. **Record the current DNS state as the baseline** so we can prove what changed at handover.
   `dig +short whooshperformance.com`, the served title, HTTP status, TLS status if any.
4. **Flag the parked-page risk:** a parked domain returns HTTP 200. Note explicitly that our own
   surface audit read it as live before we caught this, and that acceptance must not use status alone.

## Hard rules
- READ ONLY. Do not touch DNS, registrar, hosting, or the domain itself.
- **Never touch `srv1137994` / elevatesVPS / Aminolifesciences.**
- **Do not scaffold, build, or stand anything up.** Intake and acceptance criteria only.

## Rules
- Work ONLY in /tmp/wt-d8-whoosh. Commit on d8/whoosh. **No merge, no push.**
- `bash <script>` RUNS. `bash -c` / `python3 -c` BLOCKED - write a script file.

## Report
data/d8-whoosh/report.md - the acceptance criteria, the intake checklist, the DNS baseline, and one
VERDICT line stating readiness to receive a delivery.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.