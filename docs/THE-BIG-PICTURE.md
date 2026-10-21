# The big picture — 2026-10-17

One page. Correct the parts that are wrong; that is the point of writing it down.

## 1. What we actually run

| Surface | What it is | Who owns it |
|---|---|---|
| **Controller** — `vmi3196300` | coordination, dispatch, verification, docs | currently me |
| **HD2Stack** — Contabo, `hd2stack` | **primary controller + executor.** 1Panel at `hd2stack.dubzai.com/hd2secure`, AnythingLLM for our own properties, secondmate homes | **should be HD2** |
| **Hetz/Brandon** — `100.106.6.22` | Core Distro staging, elevatesci/AnythingLLM for client sites, blog | Hetz |
| **KVM1/Hostinger** — `srv797124` | `hd2.ai`, live WordPress | our site |

## 2. The AI architecture, as it should be

- **Our own properties** (hd2.ai, internal sites) → AnythingLLM on HD2Stack. Currently Gemini
  flash-lite. Time to first token is too slow.
- **Client sites** (Core Distro, CBD) → the client's own AnythingLLM on elevatesci, reached through the
  site's own hostname. **Never our internal HD2 instance.** That rule is currently broken on Core
  Distro staging and is the reason its chat is dead.
- Local inference is **ruled out**. No model pulls, no runner installs, small models unacceptable.

## 3. Where we actually are

**Working:** 1Panel published on its own domain with your IP whitelisted; Tailscale SSH live on HD2;
comms from here to Hetz lands first time; the guard no longer prompts on read-only checks; closure
gates refuse a lane without an artifact and a verdict.

**Broken:** Core Distro staging chat points at our internal HD2 address, so it 404s and the panel stays
empty. HD2 is not running as a firstmate — its session is read-only on a lock-ownership check. Four
docs on HD2 still describe the AnythingLLM topology wrongly.

**Unowned:** hd2.ai's latency work has no owner beyond a ticket. The four HD2 doc corrections have no
owner. Nothing has an owner who is accountable for closing it.

## 4. The end state you want

- **HD2 is the controller.** It owns the queue, dispatches the lanes, verifies the artifacts, and
  publishes the board.
- **This Controller gets thin.** It stops executing. It keeps exactly two jobs: keep the ledger and the
  standing standards honest, and keep Hetz supplied on his own surface.
- **Hetz stays on Hetz.** He owns Core Distro and elevatesci. He answers with artifacts and verdicts.
- **You get one page** that shows every lane, every ticket, every blocker, and you don't have to ask.

## 5. What I stop doing

- **Guessing about your systems.** If I don't know, I say so and name who does. That is what cost you
  tonight: three wrong facts sent to the man who owns those machines.
- **Chasing your last sentence.** When you raise something new, it goes on the board with an owner; it
  does not become my whole task.
- **Owning work that belongs to HD2.** Anything HD2 could own, HD2 owns.

## 6. The decisions only you can make

1. **Does HD2 become the primary controller home, and this machine becomes a secondmate or is retired?**
2. **Who owns hd2.ai's latency work** — HD2, Hetz, or a new domain agent?
3. **Is the board the single page you want**, and does it open on this machine, on HD2, or served?

Everything else on this page I can execute without asking you again.

VERDICT: PASS this is the picture as I understand it; every line marked wrong needs correcting, not
debating.