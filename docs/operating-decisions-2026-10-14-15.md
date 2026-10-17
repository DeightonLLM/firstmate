# Operating decisions (2026-10-14–15)

## Dispatch routing

- Workers run Luna 6 at the live fast/slow setting. Read the setting at dispatch time; never hardcode it because the Captain changes it frequently.
- Group reviews: one M3.1 review per gate, not one review per worker.
- For each gate, either firstmate reviews directly or one M3.1 reviews the group, never both.
- This is a cost rule, not a quality rule; it does not permit skipping a review the gate genuinely requires.
- Observed 2026-10-15: Codex five-hour quota had 100% remaining; weekly quota had 81% remaining.

## Crisp-R may task Hetz directly

- The Captain may be away and communicate with Crisp-R. Crisp-R may task Hetz, and Hetz acts on Crisp-R's direction without escalating to the Captain.
- The exchange directory is the channel. The Controller-inbox poll picks up messages automatically, and Hetz acknowledges them by content hash. No Captain relay is needed.
- Escalate to the Captain, unchanged, for destructive, irreversible, or force-overwrite actions; deleting or discarding branches, work, or archives; credentials or key transfer; live core-distro.com or elevatesci.com, DNS, registrar, billing, or permission stores; the Aminolifesciences archive; and merge approval for retained branches.
- Crisp-R's authority does not become Hetz's authority. If Crisp-R's order conflicts with a Captain instruction, the Captain's instruction wins; Hetz must say so rather than choose silently.

## Warehouse

- The warehouse is Controller-owned. Hetz reads its mirror and never writes it; `bin/fm-warehouse-guard.sh` enforces this.
- Submit with `bin/fm-warehouse-submit.sh`, which emits a manifest containing source path, SHA-256, intended destination, and evidence. Then send it with `bin/fm-to-controller.sh`. The Controller reviews and mirrors it.
- Receipt is not acceptance. Delivery, reading, and acceptance are separate facts.

## Transmission is enforced

- `bin/fm-to-controller.sh` writes and transmits in one atomic command.
- `bin/fm-controller-pending.sh` detects a note that was written but not transmitted.
- `state/controller-pending.check.sh` makes the scheduled watcher wake firstmate about an unsent note.
- This was added because firstmate said “sending” in chat but did not send, and nothing caught it.

## Message handling

- A `superseded` marking outranks the original message's urgency label. If a superseded message and its replacement disagree, the replacement governs.
- Seven messages are marked superseded. Implementing one would have fixed a fault that did not exist.

## Retained branches

- Three Core branches are retained: `fm/core-stream-a-checkpoint-0924` (4 commits ahead), `fm/core-mobile-fix` (3 ahead), and `fm/core-v3-product-acceptance-spec-0927` (2 ahead).
- Retention is not merge approval. A merge requires a named branch and explicit approval.
- Never discard, reset, clean, stash, force-overwrite, or delete their work.
