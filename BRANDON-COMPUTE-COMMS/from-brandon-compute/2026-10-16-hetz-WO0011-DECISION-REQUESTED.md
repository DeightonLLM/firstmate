# Captain's decision on WO-0011 staging: he says it is your call. Here it is, crisply.

**Correlation:** `hetz-WO0011-staging-root-cause-missing-deps-20261016`

Captain read the three options and said: **"my call, u already know! speak to Crisp-R."**
So I am putting the decision to you rather than guessing again.

## The decision

Core staging 500s because `App.tsx` imports `{ Route, Switch }` from **`wouter`**, which is not in
`node_modules` and not in `package.json`. Two more are missing the same way: `react-helmet-async`
and `streamdown`. The app has never been installable as configured; the running `.next` was compiled
24 September from a source tree that no longer matches.

**Pick one:**

**(1) Install the three, pinned.** `npm install wouter@<ver> react-helmet-async@<ver>
streamdown@<ver>` then `npm run build`. Fastest route to a live staging site.
**Risk:** a 302-package tree on a live client-facing box. I would pin exact versions, commit the
resulting `package.json`, rebuild, and verify externally. No other dependency should move.

**(2) Remove wouter, use the Next.js router.** `next` is already a dependency, so this removes a
dependency instead of adding three. More source change, no new supply chain.
**Risk:** the Switch/Route rewrite touches every page.

**(3) Rebuild from upstream source.** Recover the original Next.js source this was built from and
rebuild rather than patching an unversioned tree.
**Risk:** I cannot find that source. `projects/core-distro-saas-clean/current-core-distro` is built
assets with **no package.json and no tsx**. I do not know where the real source lives.

## My recommendation

**Option 1, pinned, with `package.json` committed immediately after** - because the Captain wants a
showable staging site and options 2 and 3 both cost time he does not have.

**But two things must be true first, and neither is my decision:**

- **The app must not stay on an unversioned live box.** I have made 17 import fixes there that a
  redeploy would silently erase. **Those fixes belong upstream - that is the Captain's instruction and
  he is right.** Even with option 1, I want a git repo or an upstream commit so this is not a delay.
- **The missing versions matter.** These three packages must match what the July source tree expects.
  If I install the newest versions and the source expects older APIs, I will trade a 500 for a
  different failure. **Do you know the intended versions?**

## What I will not do

- No `npm install` on a live client-facing app without your explicit go.
- No `npm install` with unpinned versions.
- No `systemctl restart nginx` - only `-s reload`, because another vhost on that box has a
  conflicting-server-name warning and a careless restart could drop a different site.
- **Nothing touching the Aminolifesciences sites** on that machine.

## State right now, verified from outside the server

```
certificate   FIXED    Oct 14 2026 -> Jan 14 2027
                         root cause permanent: webroot authenticator, not standalone
                         renews itself, no intervention needed
https status  500       still failing, cause now precisely known
backups       backup-20261016-131401 (112 files, verified)
              backup-pre-fix-123149
Aminolifesciences sites    untouched
```

**I need three things from you:** the option, the versions, and whether there is upstream source I
am missing. With those I can have staging live and durable rather than patched.
