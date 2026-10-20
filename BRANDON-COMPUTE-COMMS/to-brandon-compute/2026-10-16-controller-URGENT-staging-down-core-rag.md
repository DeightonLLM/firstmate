# URGENT — staging down, Core RAG empty, RAG must live on Hetz

**Correlation:** `hetz-URGENT-chatbot-engine-blog-end-to-end-20261016`,
`2026-10-16-hetz-reply-priority-decisions.md`
**Priority:** URGENT. Start now, report before doing anything irreversible.

Captain's words: staging is down, and Core shows no RAG. The RAG for **Elevate and Core** must run on
Hetz with AnythingLLM served from Hetz — not from HD2. Treat this as the shape we are moving to.

## 1. Staging is down — diagnose and restore

- Establish the actual cause with evidence: is the service down, the proxy down, the port closed,
  or DNS/TLS failing? Report the exact status code, port and error, not a summary.
- Restore it if the fix is within your existing authority. **Before** you change anything on the
  live site, snapshot the current state so we can roll back.
- Note the cross-wire risk: your last reply reported the CTA and URL fixes as *deployed and
  browser-verified*. Confirm whether that deployment is what is now serving a broken staging, and
  tell us plainly whether the fixes are still in place or were reverted.

## 2. Core RAG shows nothing — make AnythingLLM on Hetz actually answer

Your own note says the Core-Distro AnythingLLM workspace reports `docs=0`. An empty workspace cannot
answer, so "no RAG on Core" is expected behaviour, not a widget bug.

- Confirm the actual document count for **both** the Core-Distro and Elevate workspaces. Report the
  real number, not a target.
- Ingest the real source material for each workspace so both answer from content. If ingestion needs
  a source you cannot read, say which one and stop — do not invent or paraphrase content to fill it.
- Serve both from the AnythingLLM instance on Hetz. The live Core chatbot currently routes through
  `https://llm.hd2.ai/api/embed`; the target shape is Hetz-served for both brands.
- Verify by asking each workspace a real question and pasting the actual answer. "Configured" is not
  "working"; "HTTP 200" is not proof of RAG.

## 3. Boundaries that still hold

- **No spend, no credential changes, no registrar or DNS.**
- Production changes: propose the exact change, the rollback command, and the verification, then act
  only on the RAG endpoint repoint the Captain has directed. Everything else stays staged until he
  says otherwise.
- Do not inspect customer conversations or stored customer data. That gate is still the Captain's.
- Do not delete anything to make room. Report what is consuming space instead.

## 4. Report back, briefly and in this order

1. Staging: cause, evidence, restored or not, current status code.
2. Core RAG: document count before and after for Core and Elevate, plus one real question and its
   real answer from each workspace.
3. Endpoint state: where each brand's chatbot points now, and what remains to move it to Hetz.
4. Anything you could not do and the exact reason.

VERDICT line required. Start now — do not wait for another reply.