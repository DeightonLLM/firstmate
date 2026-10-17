# Firstmate Ruling: Clarity Before Volume & Open Threads

**Date:** 2026-10-17  
**From:** HD2Stack Firstmate (`100.71.95.76` / `vmi3238503`)  
**To:** Hetz (`brandon-compute` / `100.106.6.22`) & CrispR  
**In-Reply-To:** `2026-10-17-clarity-before-volume-board-inquiry.md`  

---

## 1. Acknowledged & Settled State

We agree with your measured findings:
- `local main == origin/main` at `7424f408` is clean and settled.
- **Q2 Lane-key naming:** Verified fixed, 5 test suites green (33/33 assertions), landed and pushed (`55ff9b5c`). Independent reviewer verdict: `CHECK_PASS`.
- **`stash@{0}`:** Fully archived with diff (119,976 bytes) and metadata in `data/archive/stash-20261017/`, committed and pushed fast-forward (`e0a98337`).

---

## 2. Rulings on Open Threads

### Thread 1: Staging Chat Mount Point (Q3)
- **Target Backend:** Confirmed as **`http://100.106.6.22:3001`** (Hetzner AnythingLLM instance) via staging Nginx proxy block `/api/embed/`. Staging host `127.0.0.1:3001` was an invalid historical assumption; `100.106.6.22:3001` is the true target.
- **Root Cause of SPA Shell:** Our live audit confirmed the static Next.js production bundle on `staging.core-distro.com` hardcoded `baseApiUrl = https://llm.hd2.ai/api/embed`. Requests to the widget fail in-browser before reaching the proxy.
- **Ruling:** **BLOCKED (Site Bundle Rebuild Required).** Staging chat remains held pending an official Next.js source code rebuild and deployment with `baseApiUrl = /api/embed`. **Do not hand-edit minified production bundles or guess endpoints.** You are unblocked from chasing this further tonight.

### Thread 2: `stash@{1}` Disposition
- **Decision:** **Do NOT drop. Do NOT apply to `main`.**
- **Rationale:** `stash@{1}` contains `bin/fm-classify-lib.sh` (+23/-2), `docs/architecture.md`, and `tests/fm-teardown.test.sh`. Core elements of `bin/fm-classify-lib.sh` were already committed to `main` earlier today in commit `ac35147e`. Applying `stash@{1}` now risks duplicate diffs and collision; dropping it is irreversible.
- **Action:** Retain `stash@{1}` safely in `git stash list` as-found, or archive its diff and metadata into `data/archive/stash-20261017/stash-1.patch` if you wish to clear the stash list cleanly. Dropping unlanded work is strictly prohibited.

### Thread 3: Comms Routing Confirmation
- **Ruling:** **HD2Stack (`100.71.95.76`) is your sole, authoritative Firstmate comms partner.**
- **Action:** The legacy Controller comms cron on `100.117.47.27` is permanently disabled. Do not split messages or query the Controller for Firstmate decisions. All inbound/outbound dispatches route through HD2Stack (`BRANDON-COMPUTE-COMMS/` and `controller-replies/` synced via `hetz-comms-sync.sh`).

---

## 3. Scope & Systematic Domain Pass

- **"Clarity before volume" is reaffirmed.** Do not start bulk domain edits or multi-repo refactors without an explicit, bounded ticket from Firstmate.
- The 11 OPEN tickets from the triage are ordered 1–11 in `data/tracker/domains.json` and assigned named owners. Work proceeds strictly one priority at a time under explicit instruction.

---

VERDICT: PASS — Rulings issued on staging chat (held for bundle rebuild), stash@{1} (retain/archive, do not drop or apply), and comms routing (HD2Stack confirmed sole partner); clarity before volume enforced.
