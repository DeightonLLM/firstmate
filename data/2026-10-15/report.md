# WO-0017 report — Core Distro AI engine documentation

## Summary

- Added `docs/ai-engine.md` describing the intended Hetz-local Ollama engine and `ornith-1.5:9b`, the HD2 AnythingLLM data-boundary defect, a side-by-side current/target configuration, a migration map, read-only verification commands, and explicit no-touch constraints.
- The principal migration risk is real: the site currently uses an AnythingLLM embed URL plus embed ID, while Ollama provides model APIs, not that hosted embed contract. Widget request/stream/session behavior and a safe authenticated browser-facing adapter have not been established. This is not a URL-only change.
- No migration or live/staging change was performed. Ollama was not accessed, restarted, or exposed. No DNS, proxy, firewall, deployment, or app configuration was touched.

## Verified evidence and limitations

- `/tmp/wt-engine` was on branch `docs/engine` at start; the worktree reported clean before edits.
- The supplied work-order facts were used as authoritative for the current chatbot URL (`https://llm.hd2.ai/api/embed`), embed ID (`0ec57bfa-7368-42ef-bdb6-d7959bc4f1e2`), intended model, reported 6.6 GB size, Qwen 3.5 family, and localhost listener. The service itself was not probed.
- Repository search found a historical note naming `/root/agent-work/projects/core-distro.com/current-core-distro` as the static-site source and saying it pointed at `llm.hd2.ai`; that path did not exist at inspection time. The exact current file/config carrying the URL and embed ID therefore remains unverified and is explicitly called out in the engineering doc.
- The model digest was not included in the verified facts and was not obtained from the host. The document leaves it explicitly unknown rather than inventing one.
- The repository's system-context records call HD2 AnythingLLM historical/partial and prohibit inferring its current origin or client isolation. The work order's newer supplied facts were distinguished from those stale records.

## Validation

- Documentation-only review confirms the requested engine, data-boundary rationale, current-vs-target view, migration/API mismatch, network exposure answer, verification commands, prohibited-host constraints, and no-migration status are present.
- A digest value and exact application source paths could not be independently verified without access to the intended model host and Core Distro source checkout. Neither was accessed or changed.

## VERDICT

**REAL RISK — not a straightforward migration.** The existing widget's AnythingLLM embed contract and identity do not map directly to Ollama; the client-facing adapter, authentication, streaming/session semantics, privacy controls, and staging/live configuration sources must be established before any cutover. Ollama must remain localhost-only; a separately approved protected HTTPS adapter is necessary if browsers are to reach the model.
