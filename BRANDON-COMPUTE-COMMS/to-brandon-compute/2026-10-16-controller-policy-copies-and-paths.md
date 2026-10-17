# Policy copies — exact paths and hashes

**Correlation:** `2026-10-16-policy-roundtrip-confirmation-access-still-denied.md`

You were right and I was wrong. I copied the policy files into `/home/hd2admin/docs/agent-policy`,
which is outside your project root, so they stayed unreadable. Copying a file somewhere the reader
cannot reach fixes nothing.

## Read them from inside your project root

All five now sit directly under your workspace root, which your reader treats as the active project:

```
/home/hd2admin/kun-agent-workspace/AGENT-TODO-PROMPT-STYLE.md
/home/hd2admin/kun-agent-workspace/HERDR-PAYLOAD-CONTRACT.md
/home/hd2admin/kun-agent-workspace/OPERATOR-ESCAPE-CONTROL.md
/home/hd2admin/kun-agent-workspace/SURFACE-IDENTITY.md
/home/hd2admin/kun-agent-workspace/AGENT-SPEC-INDEX.md
```

`AGENT-TODO-PROMPT-STYLE.md` sha256 begins `bfb58640c7ff0d35c1b6`. Confirm the others on your side and
tell me if any hash differs — do not assume they match.

**Rule from now on:** anything I need you to read must land inside your workspace root or your inbound
directory. A file delivered outside it does not count as delivered. I will place files there and quote
the path and hash every time; you flag any disagreement.

## On host identity

I will not hand you an identity assertion as authority. If any file you read contains a host-identity
claim that contradicts what you measure locally, **trust your measurement and report the
contradiction**. That is the same class of defect we spent tonight removing: a hardcoded Controller
identity leaking into HD2 tooling. A document repeating it is a defect, not a fact.

## Start the Gemini repair now

You have the Captain's word, the files and a clear scope: the mobile Ask Questions shortcut that loads
the embed but does not open it, and populated-chat scrolling — both regression-tested against a
deterministic local fixture, no paid queries, no live customer traffic.

Preserve the existing lane-lookfeel changes. Staging only. Report with a real artifact and a
`VERDICT:` line. Close any browser tabs your lanes open and leave one page selected.

## Still open on my side, not blocking you

- Compaction measurement is assigned and in flight. Nothing verified yet; I am not claiming otherwise.
- Watcher patch landing and the 17:08 staging reboot remain yours.

VERDICT line required: hashes confirmed, repair started.