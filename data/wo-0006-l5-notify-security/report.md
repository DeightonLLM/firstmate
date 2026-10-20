# WO-0006 L5 — Direct-notify security review

**Scope inspected:** `bin/fm-to-controller.sh`, `bin/fm-controller-pending.sh`, `bin/fm-outbound.sh`, and the inbound file consumer `bin/fm-comms-ingest.sh`, at branch `wo-0006/l5`, HEAD `2da3696de2854a8a2120d406c1f4a0bcde518831`. The direct file-drop implementation is present in the history as `fe14dad7` (`feat(comms): enforce Controller transmission; recover per-provider cap`).

**Safety boundary:** No notification, transport, or write to a live inbox was attempted. The intended destination `/home/hd2admin/controller-replies` is a real path and the sender hard-codes it, so executing the sender could contact a real recipient. Attempts to run isolated temporary probes and tests were blocked before execution by the shell allowlist (`mktemp` not allowed); those runtime checks are **UNVERIFIED**. Static findings below cite inspected source.

## Findings (ranked)

### High — Explicit filename can overwrite an existing recipient file

`bin/fm-to-controller.sh:44-49` validates only the filename shape, then copies with ordinary `cp` to both the local outbox and `/home/hd2admin/controller-replies`. `cp` replaces an existing destination; there is no exclusive-create, existing-file refusal, or content/version check. A caller can therefore reuse a destination name and replace a message already awaiting review, including one written by another sender. A partial success is also possible: if the first copy succeeds and the second fails, the script exits before its ledger update, and retry may replace the already-delivered file.

**Reproduction (not run against real targets):** In a fully isolated filesystem, pre-create `controller-replies/reused.md` with a sentinel body, then call `fm-to-controller.sh --text reused.md` with different content. The source's `cp` to that destination replaces the sentinel. Do not run this against the configured live path.

### High — No busy/blocked/done recipient guard or recipient identity

`fm-to-controller.sh:46-49` writes files directly; it does not resolve a task/recipient identity or inspect any current recipient lifecycle state before writing. Thus this implementation cannot distinguish a working, blocked, or done recipient. I found no endpoint injection in this sender: it performs file copies and prints “transmission only” (`:75`). Whether a separate filesystem watcher or human recipient treats that write as an interrupt is **UNVERIFIED**. The required invariant (“never interrupt a working or blocked recipient”) is therefore not enforced by this code, and done-recipient behavior is not gated: the file is still written if the destination directory exists.

**Reproduction (static):** Give the sender any valid `.md` name; no task id or lifecycle state is supplied to, or read by, the script before its `cp` calls. Dynamic recipient-state behavior is **UNVERIFIED** because safely invoking the configured sender would touch the live destination.

### Medium — Hash ledger conflates identical bodies and does not prevent replay

`bin/fm-to-controller.sh:30-40,53` records only a SHA-256 body hash, without destination filename, recipient, or send identifier. `bin/fm-controller-pending.sh:25-31` treats a file as transmitted whenever its body hash appears anywhere in the ledger. Consequently, if `a.md` was sent, a distinct unsent `b.md` with identical bytes is reported as not pending. Conversely, the sender never consults the ledger before sending, so it permits replay of identical content and re-sending to the same filename. This is a semantic key collision, not evidence of a practical SHA-256 cryptographic collision.

**Reproduction (not run):** In a temporary `FM_HOME`, create two different outbox filenames with identical bytes and place that body's SHA-256 in `.controller-inbox-outbound`. `fm-controller-pending.sh` will treat both as transmitted. The attempted isolated runtime probe was blocked by the shell allowlist; result is **UNVERIFIED** dynamically.

### Medium — Outbound queue and hash ledger have no retention bound

Every successful call can add a destination file and append another hash (`fm-to-controller.sh:46-53`; `fm-outbound.sh:58-62`). The pending scanner traverses every `.md` file (`fm-controller-pending.sh:25`) and the ledger has no compaction or retention path in these scripts. Sustained use can grow both the recipient directory and ledger without bound. This is a storage/availability risk; actual volume and operational cleanup are **UNVERIFIED**.

### Medium — Sender accepts arbitrary caller-authored Markdown without provenance

`fm-to-controller.sh:58-69` accepts arbitrary stdin via `--text` or copies any readable regular source file; it validates the destination name but does not authenticate or bind the content to an author. It therefore allows the invoking local user/process to place arbitrary Markdown in the Controller inbox. The inspected inbound `fm-comms-ingest.sh` treats inbound files as data, computes a digest, extracts a bounded summary, and does not shell-execute file contents. I found no execution of transmitted content in these paths. Whether a downstream Controller workflow executes or follows supplied instructions is **UNVERIFIED**; no claim of safe downstream interpretation is made.

## Probe matrix

| Probe | Result |
|---|---|
| Notification to working/blocked recipient | No task-state check in sender; no endpoint injection in inspected sender. External watcher/recipient interrupt behavior **UNVERIFIED**. |
| Done recipient | No done-state check; sender still writes to the configured file destination. |
| Deferred/queued growth | Outbox and hash ledger have no bound/retention in inspected scripts; no separate deferred queue in this sender. |
| Recipient executes content not authored by recipient | Sender permits arbitrary local input; inspected consumer does not execute it. Downstream interpretation **UNVERIFIED**. |
| Content-hash collision/replay | Duplicate-body semantic collision and replay are possible as described; no SHA-256 cryptographic collision demonstrated. |
| Runtime tests | **UNVERIFIED**; safe temp probe/test command was rejected before execution by shell allowlist. No live destination was touched. |

## Evidence and limitations

- `bin/fm-to-controller.sh:23-24, 28-53, 58-75`
- `bin/fm-controller-pending.sh:19-36`
- `bin/fm-outbound.sh:19-20, 24-39, 58-63`
- `bin/fm-comms-ingest.sh:20-45, 58-60, 162-205`
- Current branch contains the sender, but has no dedicated `fm-to-controller` test file or test reference found in `tests/`.
- No credentials, network targets, real inboxes, or recipients were used.
