# Restore plan — Core staging

**Purpose:** prove you can get back, before you change anything.
A backup that has not been restored is not a backup. It is a hope.

## What to capture BEFORE any change

The staging host currently serves an orphaned Next.js deployment, so capture both layers:

| what | how | must verify |
|---|---|---|
| the existing vhost config | copy the nginx vhost file(s) for `staging.core-distro.com` | file exists, non-empty, readable |
| the Next.js deployment's own artifacts | whatever serves it — systemd unit, app directory, env file | you can name each one |
| the database, if any exists | database dump | dump file non-empty, and restores into a scratch name |
| TLS certificate + key path | record the paths and the issuer, do not copy secrets into the report | paths recorded |
| DNS records currently pointing here | `dig +short staging.core-distro.com` | matches `45.90.220.156` |

**Verify each capture immediately.** A backup you have not checked is the same as no backup.

## Prove the restore works — do this BEFORE publishing

1. Restore the database dump into a **scratch** database name, never over the live one.
2. Restore the vhost config to a **scratch** path and confirm it parses.
3. Confirm both scratch restores are readable and complete.
4. **Only then** is the backup considered real.

If you cannot complete this, **do not publish.** Report that the backup is untested and stop.

## Restore procedure, in order

Restore in this order; doing it the other way round leaves a half-working site.

1. Put the vhost back so the host resolves as it did before.
2. Restore the database **before** the files, so code never runs against a newer schema than it expects.
3. Restore the application artifacts.
4. Restore TLS references.
5. Verify: `staging.core-distro.com` returns whatever it returned before the change. If that was `000` or
   `500`, then restoring to `000` or `500` is a **successful restore**, not a failure.

## Failure modes specific to this stack

| failure | what it looks like | what to do |
|---|---|---|
| **partial file copy** | some themes/pages present, others missing; routes 404 inconsistently | re-copy the whole artifact, verify with `SHA256SUMS`, do not hand-pick files |
| **database ahead of files** | fatal errors on page load; `wp` complains about schema | restore the database **first**, then files. If already in this state, roll back both |
| **config divergence** | site loads but assets 404 or forms post nowhere | diff the vhost and the WP config against the backup; check document root and permissions |
| **Next.js still occupying the vhost** | new WordPress never receives a request; `000` or the old app still responds | check what is actually listening on 80/443 and which document root it uses, **before** assuming the deploy worked |

That last one is the most likely failure here, because the host is currently serving a Next.js app. A WordPress
deploy that silently loses to an existing listener looks exactly like a WordPress deploy that failed.

## Rollback is not a failure

If the publish is rolled back cleanly and reported honestly, that is a correct outcome. What is not acceptable
is leaving staging half-deployed and describing it as in progress.
