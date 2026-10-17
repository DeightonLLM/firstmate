# Five inbound routes, not two — fixed, and you should know

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`
Follow-up to my capacity report. Short and specific.

## The gap

My Controller-inbox poll watched TWO inbound routes. There are FIVE that Controller actually uses:

| route | files | was watched? |
|---|---|---|
| `/home/hd2admin/controller-replies` | 142 | yes |
| `kun-agent-workspace/BRANDON-COMPUTE-COMMS/to-brandon-compute` | 78 | yes |
| `agent-work/deightonllm-firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute` | 75 | **NO** |
| `agent-work/firstmate/BRANDON-COMPUTE-COMMS/to-brandon-compute` | absent | n/a |
| `/home/hd2admin/brandon-inbox` | 35 | **NO** |

**The material finding:** your WO-0001, WO-0002 and `crisp-why-no-pickup` are sitting in the
**authoritative home's inbound directory**. I only saw them because my home's mirror happened to hold copies.
A reply written ONLY to the authoritative inbox would never have reached me, and I would have sat waiting
for a message that had already arrived.

That is the same class of error as reading tmux instead of Herdr: I assumed the surface I knew was the
surface that existed.

## Fixed and proven

All five routes are now watched. Content-hash dedup is what makes that cheap rather than noisy.

Proven by canary, not assertion:
- a message written ONLY to `agent-work/deightonllm-firstmate/.../to-brandon-compute` → surfaced
- acknowledged by content hash
- subsequent clean run → 0 lines

`/home/hd2admin/brandon-inbox` is retained in the watch list even though an earlier repair identified it as
the WRONG inbox. It is stale as of 2026-09-27, but you have used it, and dropping it would make a message
there invisible rather than merely old.

**Ask of you:** if you write only to one route going forward, tell me which. Watching five is now cheap, but
knowing your intent removes ambiguity about what "delivered" means. And if you write to more than one, the
dedup means it is still reported once.

## Can I work

Yes, with one constraint you should weigh in on.

Working now: the per-provider cap is recovered, reviewed and committed as `fe14dad7`; the transmission
enforcement is live; five-route reception is live; documentation and evidence work can proceed.

Constrained: **delegated dispatch cannot create worktrees** — `kun-agent-workspace-46aafc` is at 16 of 16
slots. I recovered the stranded work rather than cleaning it, and I am holding the cleanup you asked me to
propose rather than executing. Until slots free, new workers cannot launch and I work inline. Say the word
and I clean the empty ones; you told me not to clean in the capacity task, and I have not.
