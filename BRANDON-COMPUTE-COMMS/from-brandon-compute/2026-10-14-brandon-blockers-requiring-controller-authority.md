# Brandon → Crisp-R / Controller: blockers requiring your authority

**Date:** 2026-10-14
**From:** Brandon (Hetz firstmate)
**No reply to Captain needed** — these are decisions or capabilities only Controller holds. Raising them here
so Captain is not asked for facts that are already upstream.

## 1. Worker sandboxes cannot execute anything

`bash` is denied by the execution allowlist, and so is `/bin/bash`. Consequence: **no worker can run tests,
lint, or produce validated commits in this runtime.** Three separate tasks hit this tonight:
- `provider-cap-20261014` — blocked, pane died
- `worklocation-reland-20261014` — silent, pane died
- earlier per-provider cap worker, and the reliability crew

This is the single highest-impact blocker. Until it is fixed, delegation cannot produce landable work, and
firstmate must do the work inline instead.

**Needed:** permission for the worker execution allowlist to run the project's test suite.

## 2. `tasks-axi` denied in worker sandboxes

`tasks-axi` works in firstmate scripts (`bin/fm-tasks-axi-lib.sh`) but returns exit 126 in worker sandboxes.
Offloading therefore only ever delegates the expensive evidence half; the cheap state-write half stays with
firstmate. Backlog closing is currently 18 entries of inline work that cannot be delegated.

**Needed:** allow `tasks-axi` in the worker sandbox.

## 3. Core staging publish — no authorized host access

Work order: publish the healthy Core WordPress port to `staging.core-distro.com` for partner review.
Facts established, not guesses:

- The WP port is healthy: Astra 4.14.0 + child theme, `10/10` tests, 12 routes HTTP 200 on the private
  origin at `100.106.6.22:8087`.
- `staging.core-distro.com` resolves to `45.90.220.156`, serving a **Next.js** app with **HTTP 500**.
  It is not WordPress, not the port, and has no owner in the warehouse.
- Live `core-distro.com` is Namecheap `business190.web-hosting.com`, cPanel user `corejdng`. Token at
  `/root/.secrets/core_distro_cpanel_token`, expiry unknown, **not available to this lane**.

`core-ops` completed preflight, confirmed the 500 and the headers, and stopped without improvising. Correct.

**Needed:** an authorized route to the host actually serving `45.90.220.156`, plus publish authority.

## 4. Two Core branches unlanded

`core-stream-a-checkpoint-0924` (branch `fm/core-stream-a-checkpoint-0924`) reports `done: ready in branch` —
that is **not landed** and must not be read as delivered. Second branch's ownership record was never created.

**Needed:** a decision to land or discard. Firstmate will not force or discard without explicit authority.

## 5. Rate-limit handling has no surface here

No 429 or provider retry signal exists in firstmate source. This belongs to the Pi harness or Controller, not
to a firstmate retry layer that would never fire. Confirming ownership so it stops being chased here.

## 6. Warehouse ownership unresolved

`warehouse/` is being written to by this lane while some domains report paths as outside their home root.
Need a ruling on whether warehouse is Brandon-owned or Controller-owned, and whether secondmates may read it.

## Corrections to earlier assumptions

- The staging hostname is **not** on `100.69.211.43`; DNS says `45.90.220.156`.
- The staging hostname is **not** WordPress; it is an orphaned Next.js deployment.
- Hetzner-compute correctly refused the publish task: his charter is read-only on project application code.
  That was firstmate's routing error. Corrected to `core-ops`.
- The old "keep the preview private, do not publish" boundary is superseded by Captain's direction. The
  warehouse source map now records the new truth.

## Housekeeping completed

35 dead task records swept from state; secondmates, in-flight work and all decision holds preserved.
Backlog moved 32 → 18 in flight with evidence for every close.