# WO-0015 - get Core staging source under version control (Luna 6, high)

**Model:** openai-codex/gpt-6-luna, effort **high**. Worktree: /tmp/wt-wo0015-durability, branch wo-0015/durability.

## Why
`/opt/core-distro-staging/current` has **NO git**. Every fix made there is one redeploy from gone.
Controller's standing order: the durable home is the private repo **`DeightonLLM/core-distro-saas-clean`**.
Captain's instruction: "these belong upstream."

## Your job
1. Fetch the live app source from the box:
   `rsync -a --exclude node_modules --exclude .next root@100.69.211.43:/opt/core-distro-staging/current/ ./staging-source/`
   (`ssh -o UserKnownHostsFile=/home/hd2admin/.ssh/known_hosts.elevates`)
2. Check whether `DeightonLLM/core-distro-saas-clean` already contains this source. If it does, diff.
3. Commit the **17 import fixes** and the **pinned package.json + package-lock.json** to that repo
   on a branch. Do NOT merge to its default branch - the Captain owns merges.
4. Record in the commit message what each fix was and why, so it is reviewable.
5. Write a short `docs/STAGING-DEPLOY.md` in the repo: how the staging box is a deployment target,
   what the pinned versions are, how to rebuild, and how to roll back.

## The 17 import fixes, for the commit message
```
4x  ./pages/products/{GlassVials,RubberStoppers,AluminumSeals,AutomationEquipment} -> ./
12x ./pages/{About,Admin,AdminBlog,Blog,BlogPost,ClientRegister,Compliance,Contact,
            FAQ,Home,Products,Resources} -> ./
1x  @/pages/NotFound                 -> @/components/pages/NotFoundPage
5x  @/_core/hooks/useAuth            -> @/hooks/useAuth      (Navbar, renders on every page)
1x  @/components/JsonLd              -> @/JsonLd
```
Plus: `wouter 3.7.1`, `react-helmet-async 3.0.0`, `streamdown 1.2.0` pinned into package.json.
Plus: systemd ExecStart changed from stale `node server.js` to `npx next start -p 3113`.

## Rules
- READ ONLY on the box. Do not edit, build, or restart anything there.
- Use `gh-axi` for GitHub. Branch, do not merge.
- Never touch srv1137994 Aminolifesciences sites. Do not restart nginx.
- If the repo is not reachable or you lack access, say so plainly with the exact error.

## Report
data/wo-0015-durability/report.md: what you fetched, what you committed, the branch name, the repo URL,
and confirmation the source now exists in version control.
Use an explicit [key=<slug>] on any blocked:/needs-decision: line.
