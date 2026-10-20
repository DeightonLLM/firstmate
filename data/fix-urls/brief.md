# FIX - make 19 hardcoded production URLs environment-driven (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort high. Worktree: /tmp/wt-urls, branch fix/urls.

## THE DEFECT
12 files hardcode production URLs. Staging therefore renders PRODUCTION images and navigates to the
LIVE site. Measured occurrences:
```
llm.hd2.ai/embed/anythingllm-chat-widget.min.js    widget script
llm.hd2.ai/api/embed                                chatbot backend  (engine migration is separate - DO NOT change this)
core-distro.com  x19  across: ChatWidgetLoader, Breadcrumb, FAQPage, BlogPostPage,
                 ContactPage, Navbar, Footer, app/sitemap.ts, app/resources/page.tsx,
                 app/blog/[slug]/page.tsx, app/blog/page.tsx, app/faq/page.tsx
hd2.ai           x1
```

## Your job - replace hardcoding with config, staging != production
1. Introduce a single source of truth for the site origin. Prefer `NEXT_PUBLIC_SITE_URL` read from
   env, with a safe default. Do NOT invent a new framework.
2. Replace the `core-distro.com` occurrences so staging renders ITS OWN images and its own links.
3. **Images specifically:** use a helper so image URLs resolve against the current site origin rather
   than an absolute production URL. Verify in the browser that staging images are served BY STAGING.
4. `app/sitemap.ts` must emit the current origin, not production.
5. **LEAVE `llm.hd2.ai` ALONE.** The chatbot engine migration is a separate authorised workstream and
   Controller explicitly said keep production endpoints unchanged. Do not touch the bot URL.

## Verify in a browser - mandatory
- Deploy to STAGING ONLY via `/root/bin/deploy-core-distro-staging`.
- Browser check after deploy: screenshot desktop + mobile. Confirm images load FROM STAGING (check the
  network tab / image src), links stay on staging, sitemap uses staging origin.
- A 200 from curl is NOT evidence. This gate is Captain-critical.

## Hard rules
- STAGING ONLY. core-distro.com production is OUT.
- Never touch srv1137994 Aminolifesciences. Never restart nginx - only `-s reload`.
- Never expose Ollama 11434. Do not change any chatbot/backend URL.
- Commit on branch `fix/urls` in the FIRSTMATE repo only.
- **No merge, no push, no rebase of main.**
- `bash <script>` RUNS. `bash -c` / `python3 -c` BLOCKED - write a script file.

## Report
data/fix-urls/report.md: the mechanism introduced, every file changed with file:line, proof staging
now serves its own images (with the actual observed URLs), sitemap output, screenshot paths.
VERDICT line: FIXED or NOT.
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
- **Do NOT change the chatbot backend URL (`llm.hd2.ai`) - the engine migration is separately
  authorised. Only the site-origin and image URLs are in scope.**
- srv1137994 also hosts Aminolifesciences. Never touch that, never restart nginx (`-s reload` only).
- **Do not stop to ask whether you are permitted to deploy to staging. You are.**

Proceed: ssh in, make the site origin environment-driven, deploy to staging, browser-verify that
staging now serves its own images, report the observed image URLs.

## SECRET SCAN - scope correction, and how to read it
A previous attempt blocked on "105 possible secret-material files". **That is a false positive.**
- `agent-secret-scan` with no argument scans your CWD, i.e. the whole home directory, and lists
  files it cannot read (`.gnupg`, `.config/lean-ctx`) plus any file whose *name or content* matches
  a keyword like "secret". Test suites named `fm-secret-scan*.test.sh` are counted as hits.
- It is a keyword sweep, not a finding of real leaked credentials.

Correct scope: scan **only the app directory on the staging host**, and report actual matched
content if any:
```
ssh ... root@100.69.211.43
cd "/root/core distro brNDON EDIT/Core Distro Web"
agent-secret-scan check "$PWD"
```
**Report what it lists. If the only entries are pre-existing files unrelated to your change, say so
plainly and continue with the task.** Do not stop the whole run for a keyword sweep that predates
your work. If you find a genuine live credential in the files you are about to commit, that IS a
blocker - report it with [key=...]. Otherwise proceed to fix, deploy to staging, and verify.
