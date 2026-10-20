# WO-0011 - fix the Core staging 500: "Element type is invalid ... got: undefined"

**Model:** openai-codex/gpt-6-luna, effort **high**. Worktree: /tmp/wt-stage-fix, branch wo-0011/staging-500.

## THE ERROR (verbatim, from the live server)
```
⨯ [Error: Element type is invalid: expected a string (for built-in components) or a
   class/function (for composite components) but got: undefined.] {
  digest: '346312558'
}
```
Failing continuously since at least 15 Oct. `curl http://127.0.0.1:3113/` returns
`<div id="__next_error__">`.

## Your job - FIND THE UNDEFINED COMPONENT AND FIX IT
App: `/opt/core-distro-staging/current` on host `100.69.211.43` (Tailscale, root).

Flat Next.js/React app, many top-level `.tsx` files (App.tsx, About.tsx, Blog.tsx, Admin.tsx, ...).
A component resolves to `undefined` at render. Usually a bad import path, a named-vs-default
mismatch, a circular import, or a component used before its definition.

Method: read the import graph, find which imported symbol is not actually exported, fix it.

## ABSOLUTE RULES
- **NEVER touch the Aminolifesciences sites.** That machine also serves
  aminolifesciences.com, chat., comms., jitsi., x. - do not read, write, restart or
  reconfigure ANY of them. Only `staging.core-distro.com`.
- **Do not restart nginx** - another vhost has a conflicting server name warning and a
  careless restart could drop other sites.
- Only restart `core-distro-staging.service` if a rebuild requires it.
- Backup already exists at `/opt/core-distro-staging/backup-20261016-131401` (112 files, verified).
  Verify it exists before you change anything. Do not delete it.

## VERIFY FROM OUTSIDE, NOT FROM SERVER LOGS
A green server-side log is NOT proof. Confirm with:
```
curl -sS -o /dev/null -w '%{http_code}' https://staging.core-distro.com/
```
must return 200, and the cert must still be valid (notAfter Jan 14 2027).
If you rebuild, `nginx -s reload` may be needed to serve a renewed cert - use `-s reload`,
never `systemctl restart nginx`.

## SSH
`ssh -o UserKnownHostsFile=/home/hd2admin/.ssh/known_hosts.elevates root@100.69.211.43`

## Evidence rules
- Show the exact file, line, and import that was undefined, before and after.
- Show the external curl result. 500 is not success.
- If you cannot find it, say UNVERIFIED and what you ruled out. Do NOT claim a fix you did not verify.
- **No git on that box.** Take a fresh backup copy before you edit.

## Native To-Do list - REQUIRED first
Five or more items, each prefixed `WO-0011:`:
1. verify backup exists
2. locate the undefined import
3. state the root cause with file:line
4. apply the minimal fix
5. verify externally with curl 200

## Commit
Nothing to commit - this is a live server change. Write your report to
data/wo-0011-staging-500/report.md in your worktree and commit THAT.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
