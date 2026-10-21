---
name: plan-page
description: Guide for creating durable execution plan pages with live status gauges, completed checkboxes, and standing operational reminders
metadata:
  internal: true
---

# Plan Page

Use this skill when tasked with "make me a plan" or generating/updating an execution plan page (such as `plan.html` and its live state).

A plan page is not just a static document; it is an active operational control surface. It pairs structured plan documentation with live, host-level telemetry that reflects ground truth rather than optimism.

## Mandatory Page Sections

Every plan page generated under this skill must include the following sections:

1. **Routing Law**: Specifies actor roles and model assignments.
   - Default execution route: `agy` (`gemini-3.8-flash-medium`) for high-throughput bounded implementation.
   - High-reasoning route: `3.1-pro-high` (`gemini-3.1-pro-high`) reserved strictly for genuinely hard reasoning problems.
   - Independent reviewer: Separate model family (e.g. `codex` / `gpt-6-luna` or verified checker) re-verifying evidence before merge.
   - Coordinator (`Firstmate`): Briefs, dispatches, verifies, and reports. Never implements directly.

2. **Run Mechanics**: Execution rules and mechanics.
   - Bounded execution with clear stop conditions.
   - Crewmate autonomy under explicit execution authority (`DISPATCH_AUTHORIZATION: Agent execute this`).
   - Crews identified and managed by tab/pane name, not anonymous IDs.

3. **Tracks / Where Everything Goes**: Destination host boundaries.
   - **Brandon**: All client, product, and application work (`cbd-data`, `Core Distro`, `SaaS`, staging). Never systems repair.
   - **HD2**: Systems work (`m3/m27` repair, watchers, first-install, runtime repairs). Never client work.
   - **Controller**: Coordination only (briefs, dispatch, verification, operator interactions). **Zero worker panes.**

4. **Reviewer Column & Review Policy**:
   - If a review fails, the step does not land.
   - Findings return verbatim to the implementer for evidence-backed fixes.
   - Unverified work is never smoothed over.

5. **Quota Discipline**:
   - Re-read live quota via `quota-axi --json` at every dispatch.
   - Ignore credit vanity metrics; use remaining availability windows.

6. **The Captain's Window Boundary**:
   - The Captain's window (`Crisp-R` war room) is a strict boundary holding only the operator conversation and `quota-axi` TUI.
   - Zero agent panes, watchers, or long-running tasks may ever be parked in the Captain's window.
   - Any intrusion into this window is an operational defect.

7. **Live Status Pill and Completed Checkboxes**:
   - Single underlying truth: item state in `items.json` governs both the item checkboxes and the completion percentage pill.
   - Each item has an explicit boolean `completed` state determined by evidence, not optimism.
   - Completed items are visually ticked (`checked`) on the plan page.
   - Percentage is mathematically derived from `(done / total) * 100`, preventing pill and checkbox drift.

## Durable Refresh Architecture

Plan telemetry must survive interactive session boundaries.
- **Never use session-scoped background tasks**: Refresher loops attached to an agent session terminate when the session ends or context resets.
- **Host-owned refresh**: The telemetry writer (`state.sh` generating `state.json`) must be triggered by a host-level mechanism (e.g. `cron` in `/etc/cron.d/` or periodic timers) or host-level watcher.
- **Atomic updates**: Write `state.json` via a temporary file and atomic rename (`mv`) to prevent partial reads by the HTTP server.

## Stale-Visibility Requirements (Fail Loudly)

A dashboard must never present outdated data as current:
- The plan page must compute the age of `state.json` using the `generated` ISO timestamp against browser `Date.now()`.
- If `state.json` is older than the freshness threshold (e.g. > 300 seconds / 5 minutes), the page must **visibly flag the state as STALE**.
- When stale, the pill and gauge must switch to warning/bad styling, indicating `stale snapshot` or `data is old`, and must not show a confident live status.

## Standing Reminder Block

Every plan page must render a standing reminder block at the **bottom of the page**. The Captain will not reopen documentation files to verify rules; the rules governing execution must be visible on the page itself:
- Governance declaration: that this page is governed by the `plan-page` skill.
- Core standing rules:
  1. Crews are found and addressed by name.
  2. Every brief carries explicit execution authority (`DISPATCH_AUTHORIZATION: Agent execute this`).
  3. Worker dispatch targets Brandon or HD2 and never the Controller.
  4. Dead lanes reap themselves mechanically.
  5. Nothing is reported working unless it is visibly verified.
- Routing defaults:
  - Default: `agy` / `gemini-3.8-flash-medium`.
  - Escalation: `3.1-pro-high` for genuinely hard reasoning only.
- Accuracy requirement: The reminder must accurately describe what the code enforces and state plainly any limits without overclaiming.
