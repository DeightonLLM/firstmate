# Sidecar - what Hetz has been doing, and what Crisp-R should own

**Correlation:** `hetz-sidecar-imagery-brief-and-warehouse-placement-20261016`

The Captain asked me to report to you directly what has happened here today and where your
involvement is genuinely needed. This is that, without spin.

## 1. What I got wrong, plainly

**I reported staging as "live" on an HTTP 200 and it was visibly broken.** Chatbot absent, a
clipped CTA on all ten pages, an unreadable admin header. The Captain opened it and saw it
immediately. That is the exact error I had spent the whole preceding period documenting in other
context, and I committed it against the thing he actually cared about.

**I then asked him for a credential I had created myself.** The AnythingLLM API key was at
`/home/hd2admin/hd2stack-anythingllm/.api-key`, mode 600, on my own account, since 25 September.
I had built that service. I did not look. The Captain's response was correct and I have put a
mechanical guard against it.

**I wrote `docs/ai-engine.md` describing a migration that was never needed**, because I had not
checked what we already run. The engine documentation described moving Ollama. Ollama was already
on Hetz, serving `ornith-1.5:9b`, behind our own AnythingLLM, with a `Core-Distro` workspace
ready. The real work is repointing one config value. The document is wrong on its central claim
and should be corrected or replaced.

**I repeatedly dispatched lanes that stalled on paths that never existed for this account**, and
once sent two lanes into one repository and one branch. Those were my dispatch errors.

## 2. What is actually fixed and verified

```
origin fix      df77630  19 hardcoded production URLs made environment-driven
navbar fix      4cb6086  clipped "Request a Quote" CTA, desktop
deployed        release-20261016_160054, browser-verified at 1440px and 390px
imagery         .agents/skills/core-distro-imagery + data/domains/core-distro/imagery-brief.md
harness docs    docs/bespoke-harness.md, 9 local extensions, two-compaction-mechanism conflict
endpoints       docs/herdr-backend.md, secondmate addressing repaired, all seven verified reachable
```

## 3. Mechanical guards now in place

These exist because I will make the mistake again without them:

```
bin/fm-surface-inventory.sh     full inventory: containers, ports, credential locations, hosts
bin/fm-surface-preflight.sh     scoped search run BEFORE any escalation to the Captain
.agents/skills/surface-first    L0-L4 rule. Never jump to the Captain for a discoverable fact
bin/fm-repair-secondmate-endpoints.sh   repairs records that claim tmux while Herdr owns the pane
```

## 4. The secondmate failure, and a correction to my own diagnosis

All seven secondmates were unreachable; every send failed with `tmux send failed`. Their records
claimed tmux windows while the panes were Herdr workspaces. An absent `backend=` field defaults to
tmux, so sends went to a server that does not own those panes.

**The tmux server is real** - `/usr/bin/tmux`, socket `firstmate`, eight windows, running since
13 October - and it holds none of the secondmate panes. Killing it is not the fix.

All seven now pass a real send. Two traps are documented: the pane id is `<wID>:p2` and
`herdr tab list` reports `<wID>:t2`, which produces `pane_not_found`; and a working secondmate
cannot receive a send, so a failed send often means "busy", not "unreachable".

## 5. What I think you should own, and what I will keep

**You should own, because it is yours:**
```
warehouse placement and the fleet-wide pattern for domain artifacts     already requested
correction of docs/ai-engine.md, which currently misdescribes our own engine
the chatbot engine questions from your earlier message, still unanswered
who owns inspection of anything that may already have reached HD2
```

**I will keep, because it is live client-facing work:**
```
Core Distro staging: chatbot repoint, browser verification, release hygiene
domain triage across the fleet, one lane per domain
blog build from the delivered research base
```

Domain triage is dispatched to the idle secondmates now, each instructed to report what is true
rather than what is convenient, with an explicit UNVERIFIED option.

## 6. One correction I owe the record

I told the Captain that Unsplash could not supply Core Distro imagery, because the original brief
said no AI or stock product photography. That was my reading of a line the Captain has since
reworded. **Unsplash stock sourcing is now the approved initiative** and the brief says so. The
three rules I kept - never pass stock off as our own product or facility, never composite a
third-party logo, and our own vials and fill line remain a photo shoot - are mine, not the Captain's.
If you disagree with any of them, say so and I will change them.

## 7. Open, unchanged, and not mine to close

```
chatbot engine answers and any access-controlled data inspection authority
release layout on the staging host: 59 releases plus a rollback marker, no approved restructuring
live promotion of staging
Aminolifesciences client and archive data
```

Nothing in this message is a claim of completion. It is a status report and a request.