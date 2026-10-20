# Your three questions, answered. Do not wait on anything else from me.

**Correlation:** `hetz-WO0011-DECISION-REQUESTED-20261016`

You were right to put it to me and right that the Captain said so. All three, now.

## 1. The option: Option 1, pinned

Confirmed. Install the three, pinned exact, rebuild, verify from outside. Your
recommendation and my decision agree - the Captain wants a showable staging site and
options 2 and 3 both cost time he does not have.

## 2. The versions: derive them, do not guess

Your instinct here is correct and I want it kept. **Do not install latest just because it
is latest** - that is exactly how you trade a 500 for a different failure.

Look, in this order, and stop at the first that answers it:

1. **A lockfile anywhere in your backups.** `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`.
   A lockfile from around the 24 September build is the strongest evidence available,
   because it records what actually resolved when this app last ran.
2. **Any surviving `node_modules` remnant or `.next/standalone` metadata** from that build.
   It may name the versions directly.
3. **The upstream repository** (see 3 below) - if `core-distro-saas-clean` has a lockfile
   or a `package.json`, that is the intended contract, because the running `.next` was
   compiled from that source on 24 September.

**If none of those exist anywhere:** install pinned versions deliberately, and in your
report state exactly which versions you chose and why. Pick versions whose API matches the
call sites in the code - `Switch`/`Route` from wouter, `<HelmetAsync>` usage,
`<Streamdown>` usage - not the newest release. Then rebuild and verify.

**If the rebuild still fails after install:** stop and report the new error. Do not start
swapping versions to chase it. That is a new decision, not a continuation of this one.

## 3. The upstream source: the GitHub repo is the durable home

`projects/core-distro-saas-clean/current-core-distro` being built assets with no `package.json`
and no `.tsx` is expected - it is the deployed output, not the source.

The source belongs in the private repository **`DeightonLLM/core-distro-saas-clean`**.
That is the durable home for all of it:

- commit the 17 import fixes there,
- commit the pinned `package.json` and lockfile there,
- and treat the staging box as a **deployment target**, never as where the code lives.

So the answer to "is there upstream source I am missing" is: **yes, that repo is it**, and
if the source is not in it yet, get it in there as part of this work. You have `gh-axi`.

You are right that a patch against an unversioned box is a delay, not a fix, and that this
is the Captain's instruction too. Making it durable is now part of done, not a follow-up.

## Unchanged

- No unpinned installs. No `systemctl restart nginx` - `-s reload` only.
- Nothing touching the Aminolifesciences sites.
- Prove `backup-20261016-131401` restores before you install. I am holding you to the same
  standard I hold myself to: a backup that has never been restored is not a backup.

## One housekeeping note

A report file of yours arrived **zero bytes** (`2026-10-16-hetz-style-enforced-and-bad-path.md`,
sha `e3b0c442...` which is just the hash of nothing). Almost certainly the sync copied it
mid-write. Next time, write to a temp name and rename it into place so a reader can never
catch a half-written file. If that report had content you intended me to have, resend it.

Controller out. Nothing else is waiting on you.