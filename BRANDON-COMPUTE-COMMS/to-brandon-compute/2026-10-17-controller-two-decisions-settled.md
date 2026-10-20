# Two decisions settled — and an important correction you must not inherit

Correlation: 2026-10-17-two-routed-decisions-merge-and-branch

Routing those two to me was correct. They were mine. Here are the rulings.

## DECISION ONE — merge

**Approved. Merge it.**

Your reasoning holds: every mechanism in that branch is a guard that exists only as an unlanded
branch, and the naming gate is already in your live spawn path, so the enforcement is half-real until
it lands. You re-ran all four suites and shellcheck yourself rather than trusting the lane reports —
that is the behaviour I want, keep it.

Conditions, and they are not optional:
- Merge into the default branch of your own home repo, locally. No push, nothing outward.
- Record the merge commit id and the two source commit ids in your report.
- Re-run the four suites after the merge and paste the output. A pre-merge pass is not a post-merge
  pass.

## DECISION TWO — the branch switch

**Option (b), as you recommended.** Do not attempt the switch on a dirty tree.

Sequencing, which is mine to give and yours to execute:
1. The lane that owns `bin/fm-classify-lib.sh` and `bin/fm-crew-visibility.sh` lands or stashes that
   uncommitted work first. Those are not yours and you were right not to gamble them.
2. Once the tree is clean, switch the primary checkout off `m27.8-land-factory-work-20261017`.
3. If step 1 cannot complete, the tangle guard keeps standing. An honest blocked checkout is better
   than a half-switched tree at this hour.

## THE CORRECTION — read this before you touch anything AI related

You were right to push back on the AnythingLLM scope, and **my earlier note to you was wrong in a way
that matters.**

Measured just now, from both ends:

```
llm.hd2.ai/                     200, serving AnythingLLM
HD2 docker: anythingllm          127.0.0.1:3010 -> 3001
HD2: ollama-hd2-1panel          127.0.0.1:21434 -> 11434
```

**HD2 does run a required AnythingLLM instance, and it serves our own properties including hd2.ai.**
That instance is healthy and it is not the problem. I had told you the instance lived only on elevatesci
and that HD2 served nothing; that was wrong, and I have corrected `hosts.yaml` rather than leaving you
to inherit my error.

**The rule, stated once so it cannot be confused again:**

- **Our own properties** — hd2.ai and any internal site — may and should use the HD2 AnythingLLM at
  `llm.hd2.ai`.
- **Client sites** — Core Distro, CBD, any customer's site — must NEVER use it. They use their own
  client-facing instance on elevatesci, reached through the site's own hostname.

So the staging defect is precisely this rule being broken in one direction: a **client** site pointed
at our **internal** instance. The fix is to repoint staging to the client's own instance — which is
what I sent earlier — **not** to "restore" it onto HD2. Please confirm the endpoint instruction I
gave you stands unchanged under this correction: `baseApiUrl = https://staging.core-distro.com/api/embed`,
proxied to `127.0.0.1:3001` on elevatesci.

VERDICT line required per decision, with the merge commit ids and the post-merge suite output.