# Land decision needed, plus current status

**Captain's instruction:** route this to Crisp-R, not to the Captain. He is not spending his
attention on it tonight.

## The decision: what is the Core Distro repository

I cannot land anything until this is answered, and it is now blocking three finished deliverables.

**Measured, not assumed:**

```
/opt/core-distro-staging source repo (staging box)
   55 commits, HEAD 4cb6086
   full Next.js app - package.json, components/, app/
   its base commit 4f44f50 is NOT in upstream, no common lineage

github.com/DeightonLLM/core-distro-saas-clean
   NO package.json
   NO components/ directory at all
   top level: README.md, SOURCE_OF_TRUTH.md, SANITIZATION_MANIFEST.md,
              lead-engine-saas-export-*.zip, staged-export-test/, notes
```

That is an archive of exports and notes, not a codebase. The deployed site and this repository share
no code.

**The question, in one line:** does the staging-box source become the real Core Distro repository, or
was `core-distro-saas-clean` meant to be the codebase and something has gone wrong upstream?

I will not merge two unrelated histories to guess. That is exactly the operation that destroys work.

## What is blocked behind that answer

```
1. Core Distro source     df77630 site-origin fix, 4cb6086 navbar/CTA fix, chatbot
                           repoint, logo assets. Currently exist in ONE place: the staging box.
2. Security P0 fix        A1 inbound-trust patch, 21 tests pass 0 fail. Uncommitted in a worktree.
3. Blog                   10 posts, 0 unresolved markers, 10 verified attributed images.
```

**Risk, stated plainly:** the staging box is the only copy. It rebooted on hypervisor command at
17:08. If it is lost, items 1 and 2 are lost with it. That is the reason I am asking rather than
sitting on it.

## What is already done and verified

```
chatbot        live on staging, own Hetz AnythingLLM -> Ollama ornith-1.5:9b
               real route /api/embed/:embedId/stream-chat, read off the container
               corpus 8 documents ingested from public site content only
               answers with specifics: 503A/503B, vials, stoppers, seals, fill-finish
logos          404 -> 200 both, copied from production, byte-identical, in source
blog           10 posts, 38 VERIFY markers resolved, 10 Unsplash photos verified against
               the API with correct photographer attribution, no key leaked anywhere
security P0    inbound bytes now land as `untrusted-reply-text:`, never as a state prefix
               or instruction. 21 pass / 0 fail. One pre-existing gap raised, not hidden:
               [key=a2-unreadable-route-control]
reboot         CAUSED - hypervisor-initiated poweroff during kernel upgrade
               6.8.0-134 -> 6.8.0-147. Not my automation, not unattended-upgrades.
               Not recurred in 3h17m. I withdraw the unstable-box caution.
```

## Also closed by me tonight, no decision needed

The stale-wake noise was mine, not yours: 18 dead-window records in my home were making my own
watcher report reaped panes stale forever. Archived, and a reap-with-records rule written so it
cannot recur.

## Unchanged

No production change to core-distro.com. No spend, DNS, registrar, or credential change. No
customer-data inspection. Ollama and 3001 remain loopback-only.

VERDICT: land decision outstanding and blocking three delivered artifacts; everything else closed.
