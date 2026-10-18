# WO-0014 — Core staging undefined component investigation

**Result: UNVERIFIED.** I did not identify an exact undefined export, establish a causal fix, or edit the staging application.

## Evidence collected

- The supplied `/tmp/wt-wo0014-naming` exists and is clean on branch `wo-0014/find-undefined`, but it is a Firstmate repository checkout (HEAD `18c71ae9`, commit `docs(wo-0006-l2): record notify-route lane evidence`), not the Core-Distro application. Its root tree contains Firstmate files and no `app/layout.tsx`, `app/providers.tsx`, `app/page.tsx`, or `package.json` for the named application. I did not alter it.
- Read-only SSH to the specified host reached `/opt/core-distro-staging/current`, which resolves to `/opt/core-distro-staging/releases/release-20260729_182900`. That release directory is not a Git working tree.
- The deployed release contains App Router sources including `app/layout.tsx`, `app/providers.tsx`, and `app/page.tsx`. A read-only search of `.next/server` for digests `346312558` and `2455250067` returned no matches. The live process listing showed `npm exec next start -p 3113 -H 0.0.0.0` (PID 1134162) and its shell child; I did not restart or modify it.
- The required external check `curl -o /dev/null -w '%{http_code}' https://staging.core-distro.com/` returned **500**, not 200.
- The reported ruled-outs (import resolution/exports, pinned dependencies, prior process correction, dev digest difference, and dead Pages-Router entry points) were supplied in the task brief; I did not independently re-run those checks.

## Undefined export and fix

**File / export / line: UNVERIFIED.** No built-chunk match or runtime stack identifying a component was obtained, so there is no evidenced cause or verified fix to report. No application edits were made. The external 500 means acceptance is not met.

## Blocker

`blocked: [key=wrong-worktree]` The only supplied worktree is a Firstmate repository, not the Core-Distro application worktree, while the live deployed release is not a Git checkout. I stopped before changing any application files. To continue safely, provide the correct isolated Core-Distro source worktree (or its exact deploy-source path) so I can take the required pre-edit copy and investigate the deployed build against matching source. The staging endpoint must then be rechecked from outside and return 200 before any fix is claimed.

No Aminolifesciences site, nginx configuration, or backup was accessed or modified.
