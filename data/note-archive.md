
## Archived 2026-09-23
- [ ] elevate-mobile-audit - Reproduce Elevate mobile Chrome layout and locate source (repo: firstmate) (kind: scout) (priority: 4) (since 2026-09-23) (hold: Provide the Elevate marketing source repository or static export, plus the build and deploy owner/origin. The report has live HTML/CSS evidence only; local records do not identify the source or origin. No implementation or deploy can proceed without those inputs. Chrome emulation is also unavailable in this environment.) (hold-kind: captain)
  Captain hold set: 2026-09-23T04:33:47Z

  goal:visible-parallel-firstmate. Captain reports that Elevate looks wrong in Chrome on Android. Perform a read-only mobile-browser diagnosis for the Elevate customer site and dashboard where accessible: https://www.elevatesci.com and https://agents.elevatesci.com. Capture desktop and Android-sized Chrome DevTools evidence, separate trigger/masking condition/visible symptom, compare a working path, and seek disconfirming evidence. Search the known local workspace for the source repo/export and identify the owning builder/deploy path from existing local records; do not log in, change files, change remote state, or deploy. Report the exact page(s) reproducing, screenshot/evidence paths, likely cause with confidence, and the source path/what is missing to implement a fix.

## Archived 2026-09-23
- [ ] core-elevate-chatbot-rollout - Implement HD2-branded local-model chatbots for Core and Elevate blocked-by: local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1 (kind: ship) (priority: 1) (since 2026-09-23) (hold: Choose the approved Elevate RAG corpus before implementation: allow the internal sales journey file together with public elevatesci.com pages; use public pages only; or name other approved Elevate source documents. The internal candidate at /home/hd2admin/agent-work/.lavish/client-sales-journeys.html contains sales journey material and must not be ingested without your approval.) (hold-kind: captain)
  Captain hold set: 2026-09-23T18:28:45Z

  Implement the captain's two-site chatbot rollout after the discovery prerequisite `local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1` is complete and its blockers are resolved.

  Target outcome:
  - Keep Core Distro on core-distro.com as the behavior and knowledge reference.
  - Reproduce that chatbot experience on elevatesci.com with Elevate-specific company framing and a separately curated, vertical-aware RAG set sourced only from approved Elevate material.
  - Preserve Core's existing RAG content and indexes.
  - Route both sites through the existing AnythingLLM integration to the Hetzner local model only if the bounded synthetic benchmark shows acceptable latency and answer quality.
  - Use HD2.ai wording and branding in customer-facing/backend surfaces where it is clear and useful; retain AnythingLLM names where operators need them to identify the real runtime or API.

  Before editing, confirm each site's canonical source, registered delivery path, runtime owner, approved RAG source documents, and a recoverable timestamped restore point. Apply the `dubzai-anythingllm-chatbot` skill's mobile embed defaults. Keep Core and Elevate documents/indexes isolated. Validate site-specific vertical questions, company framing, citation/retrieval behavior, and Android-sized mobile layout against synthetic prompts and non-production previews.

  Do not edit `/opt/brandon` runtime copies, ingest customer data, alter auth, ports, DNS, or proxy rules, expose a service publicly, or deploy until the source/build/deploy owner and the project's delivery authorization are verified. Record exact before/after artifacts and rollback steps in the task report.

## Archived 2026-09-23
- [ ] core-elevate-chatbot-rollout - Implement HD2-branded local-model chatbots for Core and Elevate blocked-by: local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1 (kind: ship) (priority: 1) (since 2026-09-23)
  Resolution recorded by fm-captain-hold.
  Decision digest: 78735247b834a778786af8f6cf2a79d0dfa23625a84db3b56757b6bad7c1c877
  Resolution mode: released

  Captain decision:
  Public Elevate pages only (Recommended)

  Implement the captain's two-site chatbot rollout after the discovery prerequisite `local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1` is complete and its blockers are resolved.

  Target outcome:
  - Keep Core Distro on core-distro.com as the behavior and knowledge reference.
  - Reproduce that chatbot experience on elevatesci.com with Elevate-specific company framing and a separately curated, vertical-aware RAG set sourced only from approved Elevate material.
  - Preserve Core's existing RAG content and indexes.
  - Route both sites through the existing AnythingLLM integration to the Hetzner local model only if the bounded synthetic benchmark shows acceptable latency and answer quality.
  - Use HD2.ai wording and branding in customer-facing/backend surfaces where it is clear and useful; retain AnythingLLM names where operators need them to identify the real runtime or API.

  Before editing, confirm each site's canonical source, registered delivery path, runtime owner, approved RAG source documents, and a recoverable timestamped restore point. Apply the `dubzai-anythingllm-chatbot` skill's mobile embed defaults. Keep Core and Elevate documents/indexes isolated. Validate site-specific vertical questions, company framing, citation/retrieval behavior, and Android-sized mobile layout against synthetic prompts and non-production previews.

  Do not edit `/opt/brandon` runtime copies, ingest customer data, alter auth, ports, DNS, or proxy rules, expose a service publicly, or deploy until the source/build/deploy owner and the project's delivery authorization are verified. Record exact before/after artifacts and rollback steps in the task report.

## Archived 2026-09-23
- [ ] core-elevate-chatbot-rollout - Implement HD2-branded local-model chatbots for Core and Elevate blocked-by: local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1 (kind: ship) (priority: 1) (since 2026-09-23)
  Resolution recorded by fm-captain-hold.
  Decision digest: 78735247b834a778786af8f6cf2a79d0dfa23625a84db3b56757b6bad7c1c877
  Resolution mode: released

  Captain decision:
  Public Elevate pages only (Recommended)

  ## Captain's intent

  the bots should are on elevatesci.com and core-distro.com core has the working version, we need that copied on to elevatesci.com but both then repointig to the local model in anything llm.. both sets of rag will need setting up.. core has a solid set, elevate will neeed its set re working and company reframing but similar vertical aware responses.. where possible remove any reference of anythingllm in the scrpiting etc, reword back end code to hd2.ai essential where possible

  Public Elevate pages only (Recommended)

  make them into similar rag as core has

  ## Firstmate spec

  Implement the two-site HD2-branded chatbot rollout after the discovery prerequisite `local-chatbot-trial-map-and-benchmark-core-elevate-chatbots-d1` is complete and its operational blockers are resolved.

  - Keep Core Distro on `core-distro.com` as the behavior, RAG structure, and response-quality reference.
  - Preserve Core's existing RAG documents and indexes. Do not copy Core's corpus into Elevate.
  - Give Elevate a separately curated RAG workspace and index using public `elevatesci.com` pages only, with Elevate company framing and similarly vertical-aware responses.
  - Route both sites through the existing AnythingLLM integration to the Hetzner local model only after a controlled synthetic benchmark establishes acceptable latency and answer quality. Current benchmark evidence is inconclusive; first-content latency and answer quality were not established.
  - Use HD2.ai wording and branding in customer-facing/backend surfaces where it is clear and useful; retain AnythingLLM names where operators need them to identify the real runtime or API.
  - Exclude `agents.elevatesci.com`; the target is the Elevate marketing site.

  Before editing, confirm each site's canonical source, registered delivery path, runtime owner, public Elevate RAG source pages, and a recoverable timestamped restore point. Apply the `dubzai-anythingllm-chatbot` skill's mobile embed defaults. Validate site-specific vertical questions, company framing, citation/retrieval behavior, and Android-sized mobile layout against synthetic prompts and non-production previews.

  Do not edit `/opt/brandon` runtime copies, ingest customer data, alter auth, ports, DNS, or proxy rules, expose a service publicly, or deploy until the source/build/deploy owner and the project's delivery authorization are verified. Record exact before/after artifacts and rollback steps in the task report.

## Archived 2026-09-24
- [ ] core-live-widget-source-0924 - Map live Core site source and mobile chat widget (repo: core-distro-saas-clean) (kind: scout) (priority: 4) (since 2026-09-24) (hold: Need captain evidence to identify the reported lower-left mobile clipping: provide a screenshot or exact element name, or confirm that we should leave the cause unconfirmed. Current live CSS puts the chat widget lower-right and browser reproduction is blocked.) (hold-kind: captain)
  Captain hold set: 2026-09-24T00:32:17Z

  Read-only diagnosis of the mobile issue on https://core-distro.com. The captain reports a bottom-left element is clipped/offset on phones and hard to move on some Android devices. The live page now returns a Next.js document with the Core AnythingLLM embed ID; the available local core-distro-saas-clean checkout is a PHP/static snapshot, so do not edit or treat it as the production source. Compare exact current live HTML/CSS and widget script behavior with the local snapshot and repo/deployment notes; identify trigger, masking condition, visible symptom, and the authoritative source/build owner if locally evidenced. Browser bridge returned BRIDGE_NOT_READY twice; use the closest safe read-only path and mark browser reproduction BLOCKED_ENVIRONMENT if no working browser exists. Do not change client files, use credentials, access admin APIs, or deploy. Keep a numbered TODO visible and update it after each phase. Produce a concise report with evidence paths, source mismatch, exact fix target, and next action.

## Archived 2026-09-26
- [ ] local-scout-spawn-source-0926 - Choose a local-only isolated worker workspace for T1 and T2 (repo: firstmate) (kind: captain) (since 2026-09-26) (hold: Controller says to run T1 and T2 from a local snapshot with no network reads, but the delivered source snapshot has no Git metadata and is not itself a worker repository. Firstmate's required isolated worker launch fetches the network-backed origin for the existing Core repository used by T1 and Firstmate repository used by T2. Option A: explicitly authorize those exact read-only origin fetches. Option B: provide or approve clean local Git repositories with no network remotes for the two isolated workers. The Controller's relayed no-network instruction is not a direct Captain answer. No worker or network read has started.) (hold-kind: captain)
  Captain hold set: 2026-09-26T16:30:15Z

## Archived 2026-09-27
- [ ] core-v3-acceptance-spec-choice - Choose Core Distro V3 acceptance authority (repo: core-distro-saas-clean) (kind: captain) (since 2026-09-26) (hold: Choose the product V3 acceptance authority. Evidence: /home/hd2admin/kun-agent-workspace/data/core-v3-prd-gap-map/report.md. Option A: explicitly ratify the Brandon Multi-Project Infrastructure PRD plus an exact, identified acceptance matrix as Core Distro product criteria; provide the matrix path and revision, since none is present locally. Option B, recommended: commission a standalone Core Distro product V3 acceptance specification and keep PRD section 20.1 as infrastructure readiness only, because the independent review verified it is not product acceptance. Controller reports that no standalone product acceptance spec exists; its controller-side paths have not been inspected locally. Until this choice is made, product-level completion cannot be scored and no criteria-specific implementation should proceed.) (hold-kind: captain)
  Captain hold set: 2026-09-26T16:16:41Z
