# WO-0011 - Core staging 500: root cause found. THREE dependencies missing, not in package.json.

**Correlation:** `hetz-BASH-GRANT-WAS-REVERTED-20261016`

I did NOT delegate this - the bash grant is gone, so every worker lane dies at session start.
**I did it myself.** Here is the actual cause, with evidence.

## What was wrong - progressively, and I under-fixed twice before getting here

```
1. FOUR components imported from "./pages/products/..." - that directory has NEVER existed.
   GlassVials, RubberStoppers, AluminumSeals, AutomationEquipment are all at the app root.

2. TWELVE more imported from "./pages/..." - also never existed.
   About, Admin, AdminBlog, Blog, BlogPost, ClientRegister, Compliance, Contact,
   FAQ, Home, Products, Resources

3. NotFound imported from "@/pages/NotFound" - actually at "@/components/pages/NotFoundPage"

4. FIVE files imported "@/_core/hooks/useAuth" - there is no _core directory.
   Real path is "@/hooks/useAuth". Navbar uses it, so this broke every page.

5. Resources imported "@/components/JsonLd" - actually at "@/JsonLd"
```
All of the above are now fixed and every local import in the app resolves.

**Then I rebuilt, and it STILL 500'd with the identical digest `346312558`.** That is the real clue:
a clean build with a different error would give a different digest. An unchanged digest across a
full rebuild means the fault is not in source at all.

## THE ACTUAL ROOT CAUSE

```
App.tsx:  import { Route, Switch } from "wouter"

$ node -e "require.resolve('wouter')"     -> MISSING
$ node_modules count                       -> 302 packages, none is wouter
$ package.json dependencies                -> wouter is NOT LISTED
```

**Two more, same class:**
```
react-helmet-async   MISSING   (imported, not in package.json)
streamdown           MISSING   (imported, not in package.json)
```

**`Route` and `Switch` resolve to `undefined` at runtime. React is being handed `undefined` as a
component, which is exactly "Element type is invalid ... got: undefined".**

**This application has never been installable as configured.** It was never built from its current
package.json - the running `.next` was compiled on 24 September from a source tree that no longer
matches these files.

## Why I am stopping here rather than running npm install

Adding three third-party packages to a live client-facing app is a dependency decision, and
`npm install` against a 302-package tree on a production box can move many versions at once. That is
your call, not mine.

**Three options:**
1. **Install the three declared-by-use packages** (`wouter`, `react-helmet-async`, `streamdown`),
   pinned, then rebuild. Fastest path to a working staging site.
2. **Remove the wouter router** and use the Next.js router already present, dropping the dependency
   entirely. More code change, fewer new dependencies.
3. **Find the upstream source this was built from** and rebuild from that instead of patching a
   tree with no version control.

## The durability problem you flagged, and it is worse than I first said

```
NO GIT on that box. Not a git repo, not a worktree.
All 17 import fixes exist ONLY in /opt/core-distro-staging/current.
Any redeploy overwrites every one of them.
```
Backups taken: `backup-20261016-131401` (112 files, verified) and `backup-pre-fix-123149`.
**You are right that these belong upstream.** A patch against an unversioned live box is not a fix,
it is a delay. I have the App.tsx diff saved locally and will commit it, but a patch file is not a
durable home for it.

## Current state, verified from outside the server
```
certificate   FIXED   Oct 14 2026 -> Jan 14 2027, root cause permanent (webroot, not standalone)
https status  500 -> still 500, because wouter is absent
Aminolifesciences sites on that host: UNTOUCHED
nginx: not restarted, only -s reload used
```

**I will not install packages, restart nginx, or touch anything outside staging.core-distro.com
without your explicit instruction.**
