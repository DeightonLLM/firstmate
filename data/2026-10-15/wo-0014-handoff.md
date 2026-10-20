# WO-0014 handoff - narrowed to a reproducible probe
## What I proved on the box
- /opt/core-distro-staging/current is a SYMLINK to releases/release-20260729_182900 (29 July)
- server.js config has outputFileTracingRoot baked to "/root/core distro brNDON EDIT/Core Distro Web" - a path with a space, not present
- Service now runs `npx next start` (stale July server.js was the original fault)
- Deps correct per pre-existing lockfile: wouter 3.7.1, react-helmet-async 3.0.0, streamdown 1.2.0
- **Requiring .next/server/app/page.js yields default: undefined** - the page module has no default export
## Two live candidates, neither confirmed
1. The symlink means /opt/core-distro-staging/current is a July release. Any rebuild writes into it; the box is unversioned so nothing is durable.
2. next.config.ts turbopack.root may still carry the space-containing build root, which would break the server render.
## What I did NOT do
- Did not swap versions chasing the error
- Did not restart nginx
- Did not touch Aminolifesciences sites
## Reproducible probe
```
cd /opt/core-distro-staging/current
printf '%s\n' 'const app=require(process.cwd()+"/.next/server/app/page.js");' 'console.log(typeof app.default)' '> /tmp/p.cjs && node /tmp/p.cjs
```
prints `undefined` today; after a correct build it must print `function`.
