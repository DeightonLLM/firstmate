# Domain triage rollup - 2026-10-16

Four secondmates reported. **Every one reports the same thing: their home directory does not exist.**

## The finding

```
/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/2/   ABSENT   core-ops
/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/3/   ABSENT   whoosh-ops
/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/5/   ABSENT   cbddata-ops
/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/6/   ABSENT   elevate-p0-repair
/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/7/   ABSENT   hetzner-compute
/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/8/   ABSENT   backup-dr
/home/hd2admin/.treehouse/kun-agent-workspace-8bf1b0/4/   EXISTS   system-ops
```

Each parent directory retains only a `.fm-slot-owner` marker. Shell execution in those homes fails
with "working directory does not exist". **The panes are alive and the agents are capable; they
simply have nowhere to stand.** None of them was willing to recreate its own home, correctly - that
is a provisioning decision, not a lane's to take.

## Reports received

### cbd-data - verdict: nothing verified
- Project registry in that home was empty. A 2026-08-05 audit historically named
  `/root/agent-work/deightonllm-firstmate/projects/cbd-data.com` as a Next.js frontend with a PHP
  backend. **Current repository, remote, branch and commit: UNVERIFIED.**
- Deployment historically Namecheap shared hosting. Current deployment and health: **UNVERIFIED.**
- Blocker: missing home.
- Note: this conflicts with the earlier finding of an app at
  `/home/hd2admin/agent-work/firstmate/projects/cbd-data.com`. Unreconciled.

### hetzner-compute - verdict: nothing verified
- Charter describes a project-less domain. **Source and VCS state: UNVERIFIED.**
- Deployment and health: **UNVERIFIED.** No host or service checks were made.
- Charter names no owned web surface, so no browser check was possible.
- Blocker: missing home.

### backup-dr - verdict: nothing verified
- No backup or DR job health verified. **No changes made.**
- Registry lists it as project-less, subject being the Firstmate repository.
- The main repository at `/home/hd2admin/kun-agent-workspace` does exist with a valid GitHub origin,
  but that does not establish access to any backup surface.
- Blocker: missing home.

### anythingllm-elevate-repair - verdict: nothing verified
- Charter covers the AnythingLLM workspace at `agents.elevatesci.com` on `brandon-compute:3001`.
  **No source path, no deployed version: UNVERIFIED.**
- Runtime health **UNVERIFIED** - no live contact, correctly, because production was out of scope.
- Blocker: missing home.

## Honest assessment

**The triage produced no domain findings. It produced one fleet finding, and it is a good one:**
the secondmate fleet is registered, alive, addressable, and unable to do durable work because their
homes were removed from disk.

Every one of these agents did the right thing under the constraints: they refused to invent state,
refused to recreate their own provisioning, refused to touch production they were not authorised for,
and said UNVERIFIED rather than guessing. That is the behaviour the whole verification discipline
was built to produce. It is also the reason this report is empty of domain content.

## What this needs

1. **Recreate the six homes** or formally retire the secondmates. Provisioning is Crisp-R's call;
   I have not touched it.
2. Until then, secondmate output must be collected in chat and persisted by the parent, as done here.
3. The Core Distro and Whoosh lanes are still running and will report the same way.

## What I did not do

I did not recreate a home, did not seed a secondmate, did not touch production, and did not
treat any of this as domain completion.
## Late report: whoosh-ops

- **Source:** No Whoosh application repository or source was ever handed over. The charter and
  registry confirm no separate project clone. `/tmp/wt-d8-whoosh` is a firstmate worktree holding an
  intake report, not website or scraper source. **UNVERIFIED.**
- **Deployment and health:** Historical evidence only, not a fresh check. Records DNS `2.57.91.91`
  and a parked page. **UNVERIFIED as current.**
- **Assessment:** consistent with the known position that Whoosh is a new domain awaiting delivery
  from an external developer, with a parked page being the expected state rather than a fault.
- The agent correctly labelled its own evidence as historical rather than live.

## Standing note

Six of seven secondmates reported. `system-ops` and `core-ops` are still running.
Every reporter independently reached the same conclusion: their registered home is missing, and
that alone prevented durable domain work. No domain facts were invented by any of them.
