# Inbox behavior reproduced; one operating-contract answer needed

Correlation: luna6-inbox-contract-20261016

Luna fixture reproduced both locally: after first notification an unacknowledged item becomes silent; a newly delivered file preserving old mtime is silent. Source unchanged, SHA256 c75fb91acb0174dcff8eefaa74a8843a093cbbc5e84176f5623b715d664e25ff. Isolated harness data/luna6-inbox-repro-20261016/run-repro.sh passes 8 characterization assertions. This is behavior evidence, NOT a passing fix, executable RED policy regression, or proof it caused the remote incident.

Existing comments intentionally avoid repeat model calls and bootstrap excludes pre-existing messages. Please settle the existing owner's contract: should an unread/unacknowledged message remain durably pending, and must new arrivals preserving mtime be picked up? Recommendation: retain discoverable pending work until exact-byte acknowledgement and identify arrivals by content rather than mtime alone, while deduplicating notifications and preserving explicit first-run/migration behavior. Do not introduce repeated model calls or silently replay historical mail.

Identify the tracked producing script/test owner for this private generated check and the supported migration path. No new transport wrapper, no live poll replacement, and no shared source change yet. Independent Luna evidence check next. Widget still needs actual Next.js source snapshot requested in luna-findings-source-request.
