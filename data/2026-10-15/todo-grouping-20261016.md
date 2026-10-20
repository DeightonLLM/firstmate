# To-Do grouping by domain, 2026-10-16

29 open items grouped by registered secondmate scope, per `data/secondmates.md`.
Grouping is a routing proposal; nothing is dispatched until the Captain approves.

## core-ops - Core Distro property (scope: core distro, core-distro.com, scraper, enrichment, database, web property)

- **#36** Fix widget distortion and skewed logos - Core web property, staging only
- **#39** Land Core Distro source durably - blocked on Crisp-R repo-authority decision
- **#35** Ship AI disclosure line to staging widget - Crisp-R approved wording, Captain holds ship

Note: staging itself is complete (#6). These three are the remaining Core exposures.

## system-ops - Firstmate infrastructure (scope: this repo, supervisors, harnesses, dispatch, fleet visibility, workflow reliability)

- **#38** Fix pre-existing `FM_HOME` unbound-variable bug in `fm-classify-lib.sh`
- **#26** Regenerate stale BOARD.md from live state
- **#25** Add enforced reap on completion with a durable test
- **#34** Stop checking pane cwd when collecting worker output
- **#4** File visibility in fleet view, warehouse ownership
- **#5** Remove 5 duplicate skill-name startup warnings
- **#31** Repair secondmate addressing so work can be routed by name
- **#30** Route by scope ownership, not by who is free
- **#21** Durable config + docs for tonight's decisions

## Primary firstmate retains (no secondmate scope fits)

- **#37** Blog dated evidence - requires the Captain's own history, cannot be delegated
- **#40** Finding B recipient lifecycle interface - cross-home authority decision, no owner exists
- **#29** Capacity number correction - needs Crisp-R's re-measurement to land first
- **#32** Retract the "6 of 7 homes gone" finding - Crisp-R owns the homes
- **#33** Rebase stale-based lanes before merge - depends on the Core repo decision

## Secondmates with no assigned work this round

- **whoosh-ops** - nothing open; the parked page is expected pending delivery
- **cbddata-ops** - nothing open; live evidence already captured
- **hetzner-compute** - nothing open; no authoritative source mapping exists yet
- **backup-dr** - nothing open; no authoritative source mapping exists yet
- **elevate-p0-repair** - nothing open

These four stay idle by default. That is healthy, not neglect.

## Captain's decision needed

1. Approve the grouping, or move items between domains
2. Confirm system-ops may take the 9 infrastructure items
3. Confirm core-ops may take the 3 Core items