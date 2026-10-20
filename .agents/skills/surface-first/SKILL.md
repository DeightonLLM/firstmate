# surface-first — never ask the Captain for something already on disk

**Agent-only. Load before escalating any blocker, credential request, path question, or "how do I
reach X" to the Captain.**

## The failure this prevents

I asked the Captain for the AnythingLLM API key. It was at
`/home/hd2admin/hd2stack-anythingllm/.api-key`, mode 600, readable by my own account, sitting on
disk since 25 September. I had built that service. I asked anyway.

**That is the whole defect: escalating to the human authority when the fact was a local read.**

Credentials are the Captain's *gate*. Facts are mine to look up. I confused the two.

## Hard rule

Before any message to the Captain of the form "I need X", "where is Y", "what is the key", or
"I can't find Z" — for **any X that could plausibly exist on this host or its reachable hosts**:

```
bash bin/fm-surface-preflight.sh
```

If that script can answer it, answer it yourself. Never send the question.

## What is MY gate vs the Captain's

| Ask the Captain | Look it up myself |
|---|---|
| Money, spending, production promotion | A file path, a port, a container name |
| Credentials for a service **I did not set up** | Credentials I or a prior lane created |
| DNS, registrar, branch merge, irreversible actions | A workspace name, a model, a config value |
| Anything genuinely ambiguous about intent | Anything with a discoverable answer |

**Ambiguity about intent is the only common reason to escalate.** "I can't find it" is never
sufficient on its own.

## Layered disclosure — do not dump the whole surface

Reveal progressively. Each layer only when the previous is insufficient.

```
L0  bin/fm-surface-preflight.sh <question keywords>   scoped search, usually enough
L1  bin/fm-surface-inventory.sh                       full inventory, containers/ports/creds
L2  docker inspect / app config / remote host         targeted dig into one service
L3  ask Crisp-R                                      he holds cross-host context
L4  ask the Captain                                  last resort, state what L0-L3 returned
```

**Never jump to L4.** A Captain-facing message about a missing fact must state which layers were
searched and what they returned. "I could not find it" is not a blocker report; "I searched A, B and
C and here is what each returned" is.

## Worker briefs inherit this

Every brief dispatched must state: **search the local surface and the reachable hosts before
reporting a blocker.** A worker that reports "missing controller file" without searching is
stalling. Three lanes stalled this way tonight on a path that never existed for this account.

## Progressive surface knowledge

The inventory is a starting point, not the ceiling. When a lane discovers a real path, port,
credential location, or service, **add it to `bin/fm-surface-inventory.sh` in the same turn.** The
next session should never rediscover it. This is how the surface grows instead of staying shabby.

## Anti-patterns seen tonight, all of them mine

- Asking for a credential I had created myself
- Reporting a scanner path as absent without searching for the binary anywhere else
- Treating a Controller-local path as a blocker instead of noting it was never readable here
- Calling a site "live" on an HTTP status, then handing the Captain a broken page
- Dispatching two lanes into one repository and one branch
- Writing `docs/ai-engine.md` that described a migration that was never needed, because I had not
  checked what I had built

Each of those cost the Captain time. The check above costs one command.