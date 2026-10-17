# Brandon Client Sprint — 2026-10-03

**Status:** Draft for captain review; not dispatched. The dedicated client Secondmate home and its permitted project/delivery scope are not yet established.

## Objective

Establish a stable, visible Secondmate on `brandon-compute` for Brandon client work, then route only real, eligible work from the existing source-of-truth queues. Keep a separate clean home; preserve all work in the unseeded/dirty legacy `kun-agent-workspace` and the existing SystemOps Secondmate. No credentials, spending, live deployments, DNS/TLS, database writes, or production changes without task-specific captain approval.

## Candidate work and current status

### 1. Core-Distro V3 acceptance

- `core-v3-prd-gap-map` — **Done**; the gap-map report is already in the Brandon Firstmate home. Do not repeat it.
- `core-v3-product-acceptance-spec-0927` — **In flight** in the existing Brandon backlog. The captain answered “yes let's do that” to commissioning a standalone acceptance spec. Reconcile the durable decision/status before resuming; do not duplicate the task.
- `core-v3-product-acceptance-minimax-test-0927` — **In flight**; this is the testability challenge for the proposed spec.
- `core-v3-product-acceptance-gemini-review-0927` — **Queued** behind the MiniMax challenge. Captain reports AGY/Gemini is full; keep queued until an eligible independent reviewer is verified.

### 2. Git and backup coverage for completed live/SaaS updates

This is the captain's new request. Start with a read-only inventory of the completed updates, including the stable DubzAI recovery and other in-scope Brandon client work. Record existing Git commits/remotes (without printing credential-bearing URLs), backup paths/metadata, and restore evidence. Do not create commits, remotes, backup copies, or restore anything until the audit identifies exact gaps and the captain approves the specific changes.

### 3. Core/Elevate chatbot rollout

- `core-elevate-chatbot-rollout` — **Queued but blocked** by `local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1` and its operational/authorization gates. Do not start the rollout until the prerequisite is complete; production access, ingestion, credentials, and service changes remain gated.

## Already complete — do not duplicate

- `core-v3-prd-gap-map` — completed.
- `hd2-embed-prep-local-preview-0926` — completed.
- `mm-saas-fastpath-benchmark-0926` — completed; Music Metrics remains write-locked unless the captain explicitly names it for a write task.
- DubzAI stabilization — captain says the site is **Done**. A separate surface agent owns the historical post-set investigation; this sprint must not reopen or duplicate that work.

## Related FirstMate report follow-up (not a client task)

- `.lavish/bearings-20261002.html` was statically reviewed: its four sections and overflow handling are present, but the snapshot timestamp is 2026-10-02T17:23:07Z and its current-status cards are stale. Refresh it from a new snapshot before presenting it as current; no changes to the artifact have been made.

## Provisioning and routing gates

- Do not reuse or seed `/home/hd2admin/kun-agent-workspace`: it lacks the Secondmate identity marker and charter, has unlanded changes, and has an unknown focused pane.
- Do not repurpose the existing SystemOps Secondmate: its current `system-stale-wake-loop-0924` task and unlanded work must be preserved.
- Before creating a new client Secondmate, confirm its clean parent-owned home and exact project list. The controller's registry currently marks `core-distro.com` and `cbd-data.com` `local-only`; Secondmate project clones do not support those delivery modes without an explicit policy/delivery-path decision.
- The Secondmate remains idle unless a task is explicitly routed. It must create and maintain a visible dependency-aware To-Do list for each assigned non-trivial task.
