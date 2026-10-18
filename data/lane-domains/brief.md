# Lane 3 - Domain evidence coverage (Luna 6, high)

Worktree /tmp/wt-lane-domains, branch lane/domain-evidence.
Parent holds the fleet lock; you will not acquire it. Expected. Read + WRITE under your worktree.
No commit. No fm-session-start.

## What exists
  /home/hd2admin/kun-agent-workspace/data/wo-0009-checklist/acceptance-checklist.json
     machine-readable checklist, formula 100*PASS/(PASS+FAIL+UNVERIFIED). Currently 5.0% coverage.
  /home/hd2admin/kun-agent-workspace/data/handoffs/triage-rollup-20261016.md
  /home/hd2admin/kun-agent-workspace/projects/                  cloned repos

## Domains in scope
  CBD-Data      app at /home/hd2admin/agent-work/firstmate/projects/cbd-data.com
  Backup/DR     no home exists yet - treat as UNVERIFIED, do not invent
  Hetzner Compute
  Elevate       elevatesci.com, agents.elevatesci.com
  Whoosh        whooshperformance.com - PARKED PAGE IS EXPECTED while delivery is pending.
                A parked domain is not a defect. Do not report it as broken.

## Method - evidence only
For each domain, every claim needs a real artifact:
  - source: path + how you verified it exists
  - VCS: repo, branch, HEAD sha, whether HEAD is an ancestor of origin/main
  - deploy: what is actually running vs what source says, HTTP status AND page identity
  - blocker: the exact thing standing in the way
UNVERIFIED is a valid and correct answer. Never guess.

## Deliverable
  data/lane-domains/report.md   per domain: source / VCS / deploy / blocker / next single action
  data/lane-domains/checklist-delta.json   updated checklist with your verified PASS/FAIL items

Do not deploy. Do not clone anything new. Do not touch production. Do not touch customer data.
