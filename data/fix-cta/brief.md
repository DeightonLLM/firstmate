# FIX - clipped desktop CTA + admin contrast (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort high. Worktree: /tmp/wt-cta, branch fix/cta.

## THE DEFECTS (browser-verified, 20 screenshots, staging.core-distro.com)
```
desktop  "Request a Quote" button is CLIPPED by the viewport on ALL TEN pages
admin    header logo and nav text very low contrast against the pale background
mobile   clean - no overflow, hamburger works
```
Evidence: data/2026-10-15/browser-check/ in the firstmate home.

## Source of truth
`/root/core distro brNDON EDIT/Core Distro Web` at 4f44f50 (read/write allowed for THIS app only).
Deploy: `/root/bin/deploy-core-distro-staging` - has automatic rollback. Never restart nginx.

## Your job
1. Find the header component (Navbar.tsx and/or Footer.tsx) and fix the desktop clipping. Likely a
   flex container that cannot shrink, a fixed width, or insufficient breakpoint handling.
2. Fix the admin header contrast to meet WCAG AA (4.5:1 for body text, 3:1 for large text/logo).
3. **Commit on branch `fix/cta` in the FIRSTMATE repo** - do not commit to the app repo, it is
   unversioned and I need the diff reviewable.
4. Deploy to STAGING ONLY via the deploy script. **Never touch core-distro.com production.**
5. **Browser-verify after deploying.** Screenshot desktop 1440x900 AND mobile 390x844. Confirm the CTA
   is fully visible and contrast passes. A server-side log is NOT evidence.
6. Quote the external curl AND the screenshot paths.

## Hard rules
- STAGING ONLY. Production core-distro.com is OUT.
- Never touch srv1137994 Aminolifesciences sites. Never restart nginx - only `-s reload`.
- **No merge, no push, no rebase of main.** The Captain owns merges.
- Never expose Ollama 11434.
- `bash <script>` RUNS. `bash -c` / `python3 -c` BLOCKED - write a script file.

## Report
data/fix-cta/report.md: root cause with file:line, the fix, screenshot paths before and after,
contrast ratio measured, external curl result. VERDICT line: FIXED or NOT.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.

## CRITICAL: the app is REMOTE, not local
A previous attempt failed because it looked for the app in the local worktree. **There is no local
copy. The application exists only on the staging host.**

```
ssh -o BatchMode=yes -o ConnectTimeout=10 \
    -o UserKnownHostsFile=/home/hd2admin/.ssh/known_hosts.elevates \
    root@100.69.211.43
```

App directory on that host: `/root/core distro brNDON EDIT/Core Distro Web` (note the spaces —
quote it).

- Read, edit, and commit **on that host**. You are already root there via the tailscale key.
- Deploy with `/root/bin/deploy-core-distro-staging` on that host. STAGING ONLY.
- Verify in a browser against `https://staging.core-distro.com/` from anywhere.
- **Your first action is to confirm you can ssh in.** If the ssh fails, stop immediately and report
  it with the exact error. Do not spend the run hunting for a local copy.
- `/tmp/wt-cta-or-urls` is the FIRSTMATE repo, used only for your own report. Nothing app-related lands there.

## PERMISSION CLARIFICATION - you are authorised to change and deploy
The Captain authorised this work explicitly. A previous attempt stopped at "never touch production"
without noticing that **staging IS the authorised target and deploying to staging is the whole point
of the task.**

- `staging.core-distro.com` is authorised. Edit it, build it, deploy it, verify it. That is the job.
- `core-distro.com` production is OUT. Never touch it.
- srv1137994 also hosts Aminolifesciences. Never touch that, and never restart nginx (`-s reload` only).
- **Do not stop to ask whether you are permitted to deploy to staging. You are.**

Proceed: ssh in, find the header component, fix the clipped CTA and the admin contrast, deploy to
staging, screenshot before and after, report measured contrast ratio.

## SECRET SCAN - scope correction
`agent-secret-scan` with no argument sweeps your whole home directory and lists unreadable dirs and
any file matching keyword "secret" (test suites included). That is a keyword sweep, not a finding.
Scan only the app dir on the staging host: `cd "/root/core distro brNDON EDIT/Core Distro Web" &&
agent-secret-scan check "$PWD"`. Report what it lists; if entries are pre-existing and unrelated to
your change, say so and continue. A genuine live credential in your diff IS a blocker - report it.
