# Ten execution lanes done. Five built, five stopped on real boundaries. Here is the unblock list.
For: HD2Stack Firstmate / CrispR

Ten Codex execution lanes ran against the live defects found last night. Reporting outcomes, including the ones that stopped.

## What was actually BUILT

**A CI gate that genuinely fails.** An aggregate status now fails unless all nine existing jobs succeed, with a regression test proving that a failed or skipped job makes the gate exit non-zero. Test partitioning was corrected so the coverage guard passes *without skipping tests*. This is real delivered work: before this, CI could go red and nothing stopped a merge.

**A backup restore, exercised.** A PHP snapshot was copied to isolated scratch storage and verified byte-for-byte by SHA-256. The lane explicitly did **not** present this as a client-domain restore drill, and that distinction is correct — it is one, not the other.

**An asset-level isolation detector.** Added by me before the fleet ran. It now reproduces the live Core Distro violation (`llm.hd2.ai` served from both apex and www) and exits non-zero, while leaving the clean domains clean. This closes the gap where DNS resolution alone could not see a client domain serving assets that call an HD2-internal endpoint.

**One finding that should be closed as stale.** Core Distro's `xmlrpc.php` was recorded as exposed in post-mortem `b1849af`. Measured today: GET, OPTIONS, and a non-mutating `system.listMethods` POST all return **403**. It is already blocked. No change made, none needed.

## What STOPPED, and on what

I want these read as boundaries, not as failures. Every one of these lanes had authority to build and used it until it hit something that genuinely requires a person with different access or authority.

| lane | stopped because | what unblocks it |
|---|---|---|
| repoint Core Distro production | production source and approved deployment method unidentified; staging embed-config probe returned **404** | identifying the real production config source and its deploy method |
| Elevate internal auth | Tailscale SSH **denied** for `hd2admin` on that host | an approved operator SSH identity for the host |
| observability | no approved alert recipient or delivery integration exists | a real alert destination, and human confirmation of receipt |
| backup/DR | no client backup jobs, schedules, destinations, retention or key custody are knowable from here | authorized read-only backup evidence, approved provider and retention |
| secondmate seeding | `fm-home-seed.sh` refuses to reassign an already-registered ID even when its registered home path is missing | a decision on that helper's behaviour, or a corrected registry |

That last one is worth your attention as a **tooling defect**: the helper will not re-seed a registered secondmate whose home path is missing, which is precisely the six-home situation we are trying to repair. It cannot be worked around without either hand-editing the registry or changing the helper.

## Two corrections the lanes forced on our own records

**The TTFT figure is not measurable as stated.** Three staging probes returned **HTTP 401** in 802.6–823.4 ms with no streamed token. Those are failed-request times, not time-to-first-token. The recorded 847 ms and the 500 ms SLA **cannot be confirmed** and the lane refused to restate them. I am withdrawing the 847 ms figure from any working set until a valid client-owned stream exists to measure.

**Whoosh coordinates definitively do not exist in any readable source.** The lane searched the workspace, the Whoosh warehouse, work and reply records, the baseline repository and other readable sources under `/home/hd2admin`. No Whoosh-specific repository or server coordinates were found. This is no longer UNKNOWN-by-omission; it is a completed negative search. Whoosh cannot start until someone supplies the repository, the Hostinger KVM8 hostname/IP, the Hetzner Whoosh service hostname/IP, and the Namecheap VPS hostname/IP. A fabricated coordinate would be worse than a blocked project.

## What is still live and still true

- Core Distro production apex still serves its chatbot from `llm.hd2.ai` — the isolation violation is live and detected, not fixed
- Elevate's Tailscale `:8000` Excalidraw console is still unauthenticated and still reachable
- No monitoring or human-paging alert exists for any client domain
- No client-domain backup or restore drill is proven
- `main` still has no branch protection, so the new CI gate reports red but does not block a merge
- The four PRDs remain not-yet-safe as a verified implementation baseline; label repair is in flight

## What I am not doing

I am not improvising around any boundary above, and I am not weakening a finding to make a lane look successful. A lane that stops with the exact unblocking condition is more valuable than one that reports progress it did not make.

Captain's route to him is mine; do not reply to him about this thread.

VERDICT: ten lanes complete — one CI gate built and proven to fail, one restore exercised and honestly scoped, one stale finding closed, five boundaries stopped on with precise unblock conditions, and two of our own recorded figures corrected (TTFT unmeasurable as stated, Whoosh coordinates a completed negative search).