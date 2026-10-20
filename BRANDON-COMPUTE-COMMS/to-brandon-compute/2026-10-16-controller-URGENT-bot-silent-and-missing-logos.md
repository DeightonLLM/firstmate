# URGENT — bot silent, company logos missing (Captain, 18:2x BST)

**Correlation:** `2026-10-16-controller-decision-anythingllm-endpoint.md`
**Report source:** Captain opened the site and saw both. Treat as confirmed symptoms, not hearsay.

Two defects, in this order.

## 1. The bot loads but does not reply

Symptom: the widget appears and can be opened, but no answer ever comes back.

Do not report "widget loads" as a fix. Establish where it actually breaks, with evidence for each
step, and say which one it is:

1. **Is the proxy path live yet?** You were told to serve the widget through the site's existing TLS
   hostname. If that rule is not deployed, the old mixed-content script is still being blocked and
   nothing you change in the widget will matter.
2. **Is the request reaching AnythingLLM at all?** Capture the network request for the chat call:
   URL, status, response body. A 4xx with an error body tells us the truth; a silent hang tells us
   something else.
3. **Is the workspace answering at all?** Paste a real question and the real response, or the real
   error. Confirm which workspace the site's embed id is bound to, and that it matches the
   workspace that holds documents. An embed bound to an empty or wrong workspace answers nothing.
4. **Is the model backend up?** If AnythingLLM has no reachable LLM backend, it will accept
   questions and never answer. Prove which it is.

Paste the actual console error and the actual failing response. If it is the empty-workspace
problem, say so plainly and tell me how many documents are actually loaded right now.

## 2. Company logos are not showing

Identify precisely which logos are missing — capture a screenshot of the page and list every image
the page tries to load with its resolved URL and whether it returned 200, 404, or was blocked.
Common causes worth checking: absolute URLs pointing at a host that no longer serves them, paths
broken by the staging origin change, missing files in the build output, or assets served from a
directory the deploy does not include.

Report it as: `logo-name -> URL -> status -> cause`. If they were among the 19 hardcoded URLs you
replaced, say whether the replacement is incomplete.

## Rules for this one

- Staging only. No production change.
- Capture evidence before changing anything, then change the minimum that fixes the proven cause.
- No spend, no credential changes, no DNS, no customer-data inspection.
- That staging box rebooted at 17:08 with no explanation — if it reboots again mid-task, stop and
  report that immediately rather than pushing more changes onto it.

## Report back, in this order

1. Which of the four failure points the bot actually breaks at, with the pasted error.
2. The logo table.
3. What you changed, and the browser re-verification for each fix.

VERDICT line required.