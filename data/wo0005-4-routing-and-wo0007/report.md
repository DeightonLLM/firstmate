# WO-0007 / ticket 0027 — Controller routing and Hetz capacity evidence

**Scope:** report and proposal only. I did not install instructions, alter tracked files, dispatch workers, mutate tasks-axi, clean up worktrees, merge, deploy, or modify a watcher. This report is the requested durable deliverable.

## A. Proposed account-scoped Controller routing rule

**Proposed file:** `/home/hd2admin/kun-agent-workspace/AGENT-POLICY.md` — do not install this text yet.

**Exact proposed text:**

> ## Controller-first operational routing
> Route ordinary operational decisions, status, dispatch, review, collision resolution, work-order clarification, and reachability to the Controller first, using `/home/hd2admin/controller-replies/` and the existing watched pickup path. Do not route ordinary coordination to the Captain merely because the Captain is reachable. If the Controller is unavailable, the Captain is the fallback for ordinary operational matters. The Captain retains the hard gates for spending; destructive or irreversible actions; credentials or key transfer; live production, DNS, or registrar changes; the Aminolifesciences archive; and branch merges. Controller direction never overrides these Captain gates. Distinguish writing, transmission, Controller receipt, reading, and acceptance; claim reachability only from measured evidence.

**Why this file:** `AGENT-POLICY.md` is the home-scoped policy identified by the fresh-agent manifest (`scope=home`, pinned SHA-256 `3cd8632098333f5a4c57810dbe8652f2c5f77d54a1531427f0e205021bd4cacd`). Its text at lines 1–3 names this as the Hetz home variant; lines 34–43 specify that fresh sessions receive the policy pointer. `git -C /home/hd2admin/kun-agent-workspace ls-files --stage AGENT-POLICY.md AGENTS.md` showed only tracked `AGENTS.md`; `git status --short -- AGENT-POLICY.md AGENTS.md` showed `?? AGENT-POLICY.md`. Thus the suggested file is local/untracked home policy, not shared tracked material or `AGENTS.md`. This placement is evidenced by the actual layout and baseline, not an assumption about generic agent conventions.

## B. Current capacity — what is and is not verified

**Safely usable capacity I can certify from available evidence: 0 additional slots.** This means zero slots are *proven* available for safe use by this evidence set; it does not establish that physical capacity is zero.

Fresh measurements:

- `python3 -c '...json.load(open("/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/treehouse-state.json"))...'` read the live treehouse state: **15 registered worktrees**, slots `1,4,15–27`.
- The same command enumerated **27 numeric slot directories**, numbered `1–27`. The **12** directory numbers absent from that registered-worktree list are `2,3,5–14`; directory presence is not proof that they are free. `find /home/hd2admin/.treehouse/kun-agent-workspace-46aafc -maxdepth 3 -type f -print` showed `.fm-slot-owner` markers among those slot directories, so I did not classify unregistered directories as reusable.
- The frequently implied arithmetic **40 − 27 = 13** is only conditional: this turn did not establish a configured maximum of 40. `strings /home/hd2admin/.local/bin/treehouse | grep -iE 'max.?slots|slot.?limit|capacity|40|MAX' | head -100` exposed generic binary strings including `MaxTrees`, not the configured limit. `treehouse --help` was refused by the lean-ctx shell allowlist before execution; I did not retry through another route or change the allowlist. The state JSON itself contains only `worktrees`, no capacity setting.

Therefore **13 is not a freshly verified usable-slot count**. It is a candidate count only if the applicable ceiling is 40 and no other reservation/owner rule applies. The safe report is “0 independently certified; actual available capacity unresolved,” pending owner-authorized status/config evidence. No slots were consumed or reclaimed.

## Inbound Controller routes and watch mechanism

`/home/hd2admin/kun-agent-workspace/state/controller-inbox.check.sh:36–42` currently enumerates these five paths:

1. `/home/hd2admin/controller-replies`
2. `/home/hd2admin/kun-agent-workspace/BRANDON-COMPUTE-COMMS/to-brandon-compute`
3. `/home/hd2admin/agent-work/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute`
4. `/home/hd2admin/agent-work/firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute`
5. `/home/hd2admin/brandon-inbox` (retained as a historical route, despite being identified as stale/wrong for current use).

The poll deduplicates by content hash, filters already-handled and locally outbound hashes, and reports filenames/digests rather than content (`controller-inbox.check.sh:22–27, 80–89, 125 onward`). Acknowledgement re-hashes the named message and refuses changed bytes (`:93–119`). The check is trust-bound: `state/controller-inbox.check-trust` contains `fm-custom-check-v1` and `c75fb91acb0174dcff8eefaa74a8843a093cbbc5e84176f5623b715d664e25ff`, matching the current check script SHA-256 from `sha256sum`. `ls -l` showed both files present; the check script is mode `0700`.

The unsent-outbound checker is likewise present and trust-bound: `state/controller-pending.check-trust` pins `1a2df26f9e289f7b9eb81b32caa2e037b5c916d7d536dfb019f757a52ced7e14`, matching `state/controller-pending.check.sh`; the checker calls `bin/fm-controller-pending.sh` and emits any pending result (`state/controller-pending.check.sh:1–8`). The pending checker compares each outbound Markdown file's SHA-256 against `state/.controller-inbox-outbound` (`bin/fm-controller-pending.sh:24–37`). These code and trust-file checks establish the configured/trusted poll artifacts, not a newly observed scheduled wake in this run.

## Scope gate and refusal boundary

The current live command was run against the actual seven-row registry at `/home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv`:

```text
bash /home/hd2admin/kun-agent-workspace/bin/fm-scope-check.sh hetzner-compute PROJECT.APPLICATION.CODE
REFUSE: action domain is explicitly excluded for owner
exit=13
bash /home/hd2admin/kun-agent-workspace/bin/fm-scope-check.sh hetzner-compute hetzner.compute
ALLOW: exact action domain appears in owner write_domains and is not excluded
exit=0
```

The allow is a scope match, **not authorization to execute** (`bin/fm-scope-check.sh:1–2, 38–39, 70–82`). Exact matching means it refuses a missing/unreadable registry, invalid header/schema or malformed rows, unknown owner, excluded domain, and any action domain not exactly present in that owner's `write_domains` (`:33–36, 40–53, 66–80`). It does not infer wildcard, parent/child, or prose matches (`:38`). In particular, the registry's `hetzner-compute` row excludes `PROJECT.APPLICATION.CODE`; the live test confirms refusal of project application code and allows exact `hetzner.compute` only.

## Transmission guarantee and unproven states

`bin/fm-to-controller.sh:42–54, 73–76` packages file creation and copy attempts in one command. It copies to the local outbox and to `/home/hd2admin/controller-replies` when that route exists, then records the staged content hash. This is a **single-command transmission attempt**, not a transaction spanning Controller receipt. At measurement time, `test -d /home/hd2admin/controller-replies` and `test -d .../from-brandon-compute` both returned `0` (directories exist).

The guaranteed/observable level is therefore limited to local copy/transmission attempt through the extant exchange route, conditional on the copy succeeding. The pending checker can identify a note whose hash was never entered in the outbound ledger. The code itself explicitly disclaims Controller reading and acceptance (`fm-to-controller.sh:12–13`). I did not send a canary or alter any message. **Still unproven in this run:** a fresh correlated message independently received by Controller, a matching receipt on both sides, Controller reading it, or Controller accepting it. The Controller's latest written reply, `BRANDON-COMPUTE-COMMS/to-brandon-compute/2026-10-15-controller-pickup-loop-and-factory-response.md`, says the fresh correlated round trip is still outstanding and direct notification is not active; polling remains the honest fallback.

## Remaining P0

**Named remaining P0: Gate 8a — end-to-end inbound Controller communications acceptance.** The five-path watcher/check artifacts are present and hash-bound, but the fresh correlated round trip with matching receipts is not established by this turn. This is a verification/acceptance gap, not permission to restart or replace the watcher. The same latest Controller reply also explicitly says direct notification remains inactive; do not represent polling as instant notification.

## Commands and evidence boundaries

Commands run for fresh evidence included:

- `pwd; git status --short --branch; git rev-parse --show-toplevel; git rev-parse HEAD; sha256sum ...` — confirmed isolated root `/home/hd2admin/.treehouse/kun-agent-workspace-46aafc/27/kun-agent-workspace`, clean detached `HEAD` `2da3696de2854a8a2120d406c1f4a0bcde518831`, and all six baseline hashes matched the supplied manifest.
- `python3 -c` against the current `treehouse-state.json` — derived 15 registered entries, their slot names, 27 numeric slot directories, and the 12 unregistered directory names.
- `find ... -maxdepth 3 -type f -print` — inspected slot-marker presence without deleting or changing anything.
- `treehouse --help` — refused by the command allowlist before execution; no workaround attempted.
- `bash .../fm-scope-check.sh ...` for the two exact cases above — reproduced the exclusion refusal and exact-domain allow.
- `git -C ... ls-files --stage ...`, `git status --short -- ...`, and `nl -ba ...` — established file tracking status and cited source line locations.
- `ls -l`, `sha256sum`, and `test -d ...` — checked check-script trust bindings and current exchange-directory presence.

The controller-side `/root/agent-work/deightonllm-firstmate/BOARD.md` and `CONTROLLER_STATE.md` pointers were not present at the supplied paths (`ENOENT` from reads); I did not infer their contents. No live message, watcher cycle, or machine-level capacity ceiling was tested beyond the commands above.

## Recommendation

Keep the proposed routing language in the home-scoped untracked `AGENT-POLICY.md` only after the account owner decides to install it; leave `AGENTS.md` and the tracked repository untouched. Obtain an approved read-only treehouse status/config output before claiming any free-slot count. Keep the five-path poll and hash-bound checks intact, and close Gate 8a only after a fresh correlated round trip yields matching receipts. Until then, report polling/transmission separately from read and acceptance.
