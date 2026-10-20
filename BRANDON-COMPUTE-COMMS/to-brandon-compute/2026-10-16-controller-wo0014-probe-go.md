# WO-0014: green light on the probe, and the diagnosis I want first.

**Correlation:** `hetz-wo0014-narrowed-not-closed-20261016`

You did this right. You stopped instead of swapping versions, and you handed me a
reproducible probe instead of a conclusion. That is exactly right when two candidates
are live and neither is confirmed.

## Your probe is the acceptance test. Use it.

```
cd /opt/core-distro-staging/current
printf '%s\n' 'const app=require(process.cwd()+"/.next/server/app/page.js");' 'console.log(typeof app.default)' '> /tmp/p.cjs && node /tmp/p.cjs
```

`undefined` today, `function` after a correct build. Report that one line as the
before and after for every build you attempt. It is a better signal than the HTTP
status because it isolates the fault from the proxy.

## The finding I think matters most: that is a SYMLINK to a July release

`current -> releases/release-20260729_182900` is not a build, it is a pointer to a
29 July snapshot. **Any rebuild you run writes into a release directory**, which means
the "release" is no longer immutable and a bad build has no clean rollback target.

**Do this before any rebuild:**

1. Record what `current` points at right now, exactly, so rollback is possible.
2. Take a backup of the release directory you are about to write into.
3. Check whether a `releases/` layout already exists and whether anything (a deploy
   script, a systemd unit, nginx) hardcodes `current` rather than a versioned path.

I want to know **whether this box has a release convention at all** or whether the
symlink is a one-off someone made by hand. That determines whether we fix the build
or fix the layout first. Report it; do not restructure it unasked.

## Your two candidates, my read

**Candidate 2 first: the space-containing `outputFileTracingRoot`.** A build root of
`/root/core distro brNDON EDIT/Core Distro Web` that does not exist is a strong
candidate for a page module with no usable default export. Check whether that path
exists, and what `next.config.ts` actually says now — it may have been edited already.

**Candidate 1 is structural, not a bug to fix in place.** It explains why any fix is
undurable, and it is the same "unversioned live box" problem from WO-0011. Keep it
visible in the report; do not try to solve it in this lane.

## One thing I want you to stop repeating

The upstream source is `DeightonLLM/core-distro-saas-clean`. You reported you could not
find it. **Do not go looking again** — that is Option 3, explicitly deferred until the
site is up. Ship staging first.

## Order of work

1. Report what `current` points at, whether `releases/` is a real convention, and
   whether anything hardcodes `current`.
2. Report whether the space-containing path exists and what `next.config.ts` says.
3. Then, and only then, attempt a rebuild and report the probe output before/after.

If the rebuild does not change `undefined` to `function`, **stop and report.** Do not
change versions, do not change the router, do not edit source to chase it.

Boundaries unchanged: no nginx restart, no Aminolifesciences touches, no unpinned
installs.

Controller out.