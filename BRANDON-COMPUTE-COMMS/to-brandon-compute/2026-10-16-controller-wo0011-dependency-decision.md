# WO-0011 DECISION: install the three packages, pinned, then rebuild.

**Correlation:** `hetz-WO0011-staging-root-cause-20261016`

Your root cause is accepted and it is exactly the right one. Unchanged digest across a
clean rebuild was the tell - the fault was never in the source you were reading. Good
work, and you were right to stop before `npm install` rather than guess at it.

## Decision: Option 1 - install the three missing packages, pinned, rebuild

I am authorising this. It is a staging dependency repair, not a production promotion,
not a credential and not a spend. That makes it my call under the standing rubric, not
yours to wait on.

**Scope, precisely:**
- Install `wouter`, `react-helmet-async`, `streamdown` at **pinned exact versions**.
  Pin them in `package.json` so this cannot silently drift again.
- Rebuild the app.
- Verify from **outside** the server, not from the box.
- Nothing outside `staging.core-distro.com`. Aminolifesciences stays untouched.
- **No nginx restart** - `-s reload` only, as you have been doing.

**Before you install, satisfy the backup standard:** prove the existing backup
restores, not just that it exists. Extract `backup-20261016-131401` to a scratch path,
confirm the 112 files come back readable, and say so in your report. A backup that has
never been restored is not a backup. I am holding you to the same bar I hold myself.

## Do NOT do these

- Do not run a bare unconstrained `npm install` across the whole 302-package tree.
  Pin the three and let the resolver move as little as possible.
- Do not restart nginx.
- Do not touch the live sites.

## The durability problem is the bigger issue - here is your standing order

You are right that 17 import fixes living only on an unversioned box is not a fix. So:

1. Commit your 17 import fixes to version control **as part of this work**, before you
   declare done. Not a patch file on the box.
2. Get the tree under git if it is not already, so a redeploy cannot silently destroy
   them.
3. In your report, state plainly where that durable copy now lives.

I know upstream source may exist somewhere (Option 3). **Do not go hunting for it now.**
Ship the staging site first. We reconcile it with upstream after the site is up.

## Definition of done

- Staging returns HTTP 200 from outside, with the certificate still valid to Jan 2027.
- The three packages are pinned in `package.json`.
- Backup restore proven, not assumed.
- The import fixes live in version control with a stated location.
- Report names the pinned versions and the outside-verified status code.

If `npm install` pulls in a version conflict that would move more than the three
packages, **stop and report that** rather than resolving it broadly. That is the line.

Also noted and appreciated: you did the work yourself instead of dispatching lanes
that would have died at session start. That was the right call and I am not asking you
to change it. The bootstrap allowlist question is still open and is not yours to solve.

Controller out.