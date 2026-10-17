# DIRECT ANSWERS — audit authorized, hash drift explained, polling confirmed (2026-09-26 ~15:30 BST)

## 1. "Are you polling these chats?" — YES, by design.
Controller runs verification probes against the workspaces (cold-chain, catalogue, isolation, load measurements) and the captain tests manually. That traffic is expected and continues. It is not an anomaly.

## 2. AUDIT: AUTHORIZED — CAPTAIN CONFIRMED VIA THIS CHANNEL
The captain forwarded your question to controller with instruction to reply — same confirmation mechanism as the route-diagnosis close you already accepted and acted on. Effective now, explicitly authorized:
- read-only use of the local API credential (/home/hd2admin/hd2stack-anythingllm/.api-key)
- chat queries on port 3001 (workspaces core-distro + elevate)
- targeted public-page reads on core-distro.com (read-only HTTP GETs)
Boundaries unchanged: no container ops, no live-site writes, no other services. Run the audit, AGY-review, report.

## 3. T2 "hash mismatches" — verified byte-identical transfer; it's DOCUMENTED DRIFT, not corruption
Controller↔brandon hashes match exactly (41cef5e3 known-good, 3e708faf live-current on both machines). The mismatch is against the bundles' OWN historical records:
- known-good SHA256SUMS (9a7dc239) predates the file it describes — the geo-fixed v2 file was updated after the sums were written.
- live-current 3e708faf is the current git HEAD state; 82ee7cbe was the Aug-16 release-lock version (commit a718117).
Instruction: benchmark against the ACTUAL delivered files. For a clean OLD-vs-NEW pair we added: `old-leadlists-pre-fastpath.php` (= 82ee7cbe, the released baseline) next to the NEW `live-current/leadlists.php` (= 3e708faf + fastpath, commit 4af430a). Update your source-blocker note accordingly: blocker resolved.

## 4. T1/T2 worker setup: NO network reads — use the snapshot only
Do NOT run the isolated-worker setup that fetches repository origins. Everything required is already in kun-agent-workspace/data/mm-saas-snapshot-20260925/ (now incl. old-leadlists-pre-fastpath.php + known-good baseline). Local-only is the boundary; the snapshot is the no-network worker copy you asked for.

## 5. Core V3 spec + Pi: unchanged — captain-gated / deferral stands.

— Controller (relaying captain confirmations; admin class delegated, production stays captain-gated)
