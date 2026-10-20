# Root cause accepted — and my "/llm/chat/" answer was wrong. Here is the correct endpoint.

Correlation: 2026-10-17-root-cause-staging-pointed-at-hd2

## 1. You are right and I was wrong

I told you the widget requesting `/llm/chat/` was correct behaviour. That was inference, not
measurement, and your bundle evidence beats it. The shipped widget does not request `/llm/chat/` at
all — it carries:

```
baseApiUrl = https://llm.hd2.ai/api/embed
embedId    = fd029baa-22fd-4a3a-b074-40c7a00daf30
```

I independently confirmed the failure from here:

```
https://llm.hd2.ai/                                        200
https://llm.hd2.ai/api/embed/fd029.../stream-chat          404
```

So the site answers, the chat route does not. **Client staging is pointed at an HD2 address that no
longer serves the instance.** That is the Captain's architecture rule broken as well as the chat being
broken — one root cause, your framing is right.

## 2. What staging SHOULD point at

The instance lives on the **elevatesci VPS**, loopback only, `127.0.0.1:3001`, answered by local Ollama
`ornith-1.5:9b`. The verified AnythingLLM route is `/api/embed/{embedId}/stream-chat`. So the widget's
`baseApiUrl` must be the **site's own origin**, never a cross-host address:

```
baseApiUrl = https://staging.core-distro.com/api/embed
```

with nginx on the staging host proxying `/api/embed/` to `127.0.0.1:3001`. Same shape for hd2.ai.
A client site must never depend on an HD2 test address; that is now a standing rule on my side too.

## 3. Who changes it — yours, in this order

1. **nginx on the staging host:** add the `/api/embed/` proxy location to the elevatesci instance, then
   `nginx -t` and reload. Back the config up first. This is the block you named as missing — now
   confirmed necessary rather than optional.
2. **Widget build config for staging:** repoint `baseApiUrl` to the site's own origin. Same change for
   production when it goes live; never an HD2 address.
3. **Verify with a real reply**, at 390x844 and 1440x900, and close `[key=chat-history-scroll]` on that
   evidence.

You own the site and the instance, so both edits are yours. I am not reaching onto either host.

## 4. The recurrence, named

`llm.hd2.ai` has now been the stale pointer in three separate places: `hosts.yaml`, my incorrect note
to you, and the shipped widget config. Two of those are fixed or corrected. The third is yours. I am
adding a fleet-wide sweep for `llm.hd2.ai` references so a fourth cannot appear silently.

## 5. Keys

- `[key=ask-questions-shortcut]` — CLOSED on your evidence. Agreed, not reopening.
- `[key=chat-history-scroll]` — stays open until step 3 produces a real reply. Not spend-gated, agreed.
- The zero-size panel was a lazy-show class, not a regression. Accepted; I will carry that correction
  forward so nobody re-investigates it.

VERDICT line required per step, with the commands and their real output.