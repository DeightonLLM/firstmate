> **DATED CORRECTION — 2026-10-19 (Captain ruling):** KVM1 (`srv797124`) is our own
> infrastructure, not a client host, not the Elevate VPS, and not a client deployment target.
> `100.69.211.43` is the Elevate VPS `srv1137994-elevatesci`, not KVM1. Any client-data
> placement or deployment target on KVM1 is **VOID**, not repointed. Historical body below is
> retained as evidence; this correction supersedes its conflicting identity/target claims.
>
# Core staging publish runbook

**Revision:** `50ae6849c190` (content-addressed — same source always yields this id)
**Target:** `staging.core-distro.com` → `45.90.220.156` = KVM1 `srv1137994.hstgr.cloud`
**Authority:** staging-only. The host route is Controller-side; no key transfer is authorized.

## Current state, measured

| thing | state |
|---|---|
| `staging.core-distro.com` | **HTTP 000** — connection fails before any HTTP response |
| what serves it | an orphaned **Next.js** deployment, not our port |
| our port | Astra 4.14.0 + child theme, 10/10 suite, 12 routes 200 on the private origin |
| artifact | 19 files, `SHA256SUMS` verifies 19/19 OK |
| artifact integrity | **acknowledged as reported, NOT independently accepted by Controller** |
| chatbot | **INACTIVE** in the artifact — outstanding |
| DB / page / menu state | **ABSENT** — the artifact is a theme only |

## Preconditions — every item checkable, all must pass

```bash
# 1. Artifact integrity, before anything else
cd /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact
sha256sum -c SHA256SUMS            # every line must read OK

# 2. Revision matches the one Controller acknowledged
cat REVISION                        # must read revision=50ae6849c190

# 3. A restore-tested backup exists for the CURRENT staging host (see restore-plan.md)
#    A backup that has not been restored at least once is not a backup.

# 4. The Next.js deployment occupying the vhost is identified and its fate decided
#    BEFORE the port is deployed. Do not overwrite it and discover later it mattered.
```

**STOP if any of these fail.** Do not proceed on a partial verification.

## Publish steps

> Every step marked ⛔ can damage something live. Do not run past one without explicit authority.

1. ⛔ **Confirm the live sites first.** Both must be 200 before you touch anything:
   ```bash
   curl -s -o /dev/null -w 'core-distro %{http_code}\n' https://core-distro.com/
   curl -s -o /dev/null -w 'elevatesci  %{http_code}\n' https://elevatesci.com/
   ```
   If either is not 200, **stop** — the host has another problem and you are about to make it worse.

2. ⛔ **Back up the existing vhost and database.** Per `restore-plan.md`. Verify the backup is non-empty
   before continuing.

3. **Install WordPress + Astra 4.14.0 parent** on the staging host if not already present.

4. **Copy the child theme:**
   ```bash
   cp -a <artifact>/core-distro-astra-child <wp-content>/themes/
   ```

5. **Activate** the child theme. Verify with `wp theme list` that it is active, not merely present.

6. ⛔ **Create or reconcile page and menu state.** The artifact is a theme only. Without this step the site
   loads but every route 404s. Check for duplicates before importing — nine duplicate seed records were
   previously drafted on the private origin, not deleted.

7. **Verify all 12 routes**, each with observable output:
   `/`, `/products/`, `/about/`, `/compliance/`, `/contact/`, `/resources/` and the rest of the intended set.

8. **Activate the chatbot.** It is currently inert. Verify by loading the page and exercising it — not by a
   header, and not by the widget being present in the DOM.

9. **Confirm the live sites are still 200** with the same two curls as step 1. ⛔ A change here means roll back.

## Explicitly out of scope — do not do these

- ⛔ Touch `core-distro.com` — live, Namecheap `business190`, cPanel `corejdng`
- ⛔ Touch `elevatesci.com` — live, Hostinger + Cloudflare, same box
- ⛔ DNS, registrar, billing, or permission-store changes
- ⛔ Credential creation or key transfer
- ⛔ Enabling the newsletter form against anything live

## Rollback trigger — a condition, not a judgement

**Roll back immediately if any of these is true:**
- `core-distro.com` or `elevatesci.com` stops returning 200
- any of the 12 routes fails after a step that previously passed
- the vhost will not come up after restore from the backup
- the chatbot cannot be made to work and the site is otherwise complete

Roll back per `restore-plan.md`, then report. A rolled-back publish that is honestly reported is a success; a
half-published staging site that is left in place is not.

## Honest limits of this runbook

It has **not** been executed. It is prepared so publication is one authorised step rather than an improvised
one. The artifact is unaccepted, the chatbot is inactive, and there is no database state — those are stated
here so nobody discovers them mid-deploy.
