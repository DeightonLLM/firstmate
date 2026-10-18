# WO-0014 - find the undefined component in Core staging (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort **high**. Worktree: /tmp/wt-wo0014-naming, branch wo-0014/find-undefined.

## THE ERROR
```
Error: Element type is invalid: expected a string (for built-in components) or a
class/function (for composite components) but got: undefined.
digest: 346312558 (prod) / 2455250067 (dev)
```
`stack: []`  <- EMPTY component stack in dev. That is the key clue.

## Environment
```
ssh -o UserKnownHostsFile=/home/hd2admin/.ssh/known_hosts.elevates root@100.69.211.43
app:  /opt/core-distro-staging/current   (Next.js 15.5.20, App Router, React 19.2.7)
```
`bash <script>` RUNS. `bash -c` and `python3 -c` are BLOCKED - write a script file and run it.

## What is ALREADY RULED OUT - do not redo these
- Every relative and `@/` import in the app resolves to a real file.
- Every named import has a matching export (a regex scan found 7 false positives: 6 Drizzle
  `export type`s and 1 unused Express entry, all fine).
- `wouter` 3.7.1, `react-helmet-async` 3.0.0, `streamdown` 1.2.0 are installed and pinned -
  versions confirmed from the pre-existing lockfile.
- The service was running a stale July `server.js`; it now runs `npx next start`.
- Next.js dev on 127.0.0.1:3199 was tried; it gives a different digest but still no stack.
- **This is an App Router app.** `app/layout.tsx`, `app/providers.tsx`, `app/page.tsx` are live.
  `App.tsx` and `main.tsx` at the root are DEAD Pages-Router code - ignore them entirely.

## Your job
**Find the specific export that evaluates to undefined at render time.**

Because the component stack is empty, the fault is likely at MODULE EVALUATION, not a JSX tag:
- a circular import where one module reads another's binding before it initialises
- a barrel/index file exporting a name that resolves undefined
- `next/font/google` variable (`Barlow_Condensed`, `DM_Sans`) undefined at SSR
- a `"use client"` boundary exporting something the server tree cannot resolve
- a CJS/ESM interop default that comes back undefined

Method that will actually answer it: **bisect the render tree**, or inspect the built server chunk
under `.next/server/` for the digest and read the surrounding component. Write a small Node script
that requires the built page module and catches the throw with a real stack.

## Rules
- **NEVER touch the Aminolifesciences sites** on that host. Do not restart nginx.
- Backups exist: `backup-20261016-131401`, `backup-pre-fix-123149`. Do not delete them.
- Take your own copy before editing anything.
- Verify from OUTSIDE: `curl -o /dev/null -w '%{http_code}' https://staging.core-distro.com/`
  must be 200. 500 is not success.

## Report
data/wo-0014-undefined/report.md: the exact file, export and line, why it is undefined, the fix, and
the external curl result. If you cannot find it, say UNVERIFIED and list what you ruled out.
Do NOT claim a fix you have not verified with an external 200.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
