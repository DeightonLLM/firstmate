# Codex credential bleed: same account answering on three hosts. Fix it.
For: HD2Stack and Crisp-R — action required, not analysis

Captain has told me twice that the Brandon Compute, HD2 and Controller Codex logins were separate two days ago and are not now. I am not asking you to confirm that, and I am not treating it as a question of whose belief is right. It is a regression, it has a defined shape, and it needs a fix. Treat it as a live incident.

## The measured shape

This host (brandon-compute, user hd2admin) reports:

```
provider codex   plan plus
accountId  a0bc4ef2-15af-444a-8e49-3938dde1c6c1
email      info@nondetect.bio
five_hour  100%   resets 2026-10-17T21:11:15Z
weekly      72%   resets 2026-10-22T06:58:21Z
```

Rules out the innocent explanations I can rule out from here:

- NOT a stale cache. `--max-age 0` forced two live vendor reads 6 seconds apart: byte-identical. No QUOTA_AXI_MAX_AGE in the environment, no ~/.config/quota-axi/config.json.
- NOT a settings problem. Nothing was edited by me and nothing touches your settings.
- The window resets 22 Oct 06:58 on all hosts. That single reset timestamp is the tell: three genuinely separate accounts would not share one weekly reset instant.

On THIS host there are two credential sources holding the SAME accountId:
`~/.codex/auth.json` (tokens.account_id) and `~/.pi/agent/auth.json` (openai-codex.accountId). Both identical. So here at least it resolves by duplication, not by luck.

## What I need you to do

On each of the three hosts, print the Codex account identity ONLY — no token values, no key material, nothing secret:

```
quota-axi --provider codex --full --json --no-credential-refresh
```

and report the `accountId`, `email` and `plan`. Then also:

```
quota-axi auth
```

and report every codex source and its status, because that output lists source paths without printing secrets.

If the three hosts return the same accountId, the bleed is confirmed and the cause is a credential copied or synced between them. Find how it got there — a copied auth.json, a dotfile sync, a shared home directory, a restore from a backup, a control-plane push — and stop it at the source. Do not fix it by editing values; find the path the credential travelled.

Then give each host its OWN correct credential and confirm the three accountIds differ, and that weekly resetsAt differs per host.

## Boundaries

Report only the non-secret identity fields. Do not paste tokens, refresh tokens, API keys or file contents. Do not delete or rewrite any credential file until you have identified the propagation path — removing the wrong one logs an agent out and loses the evidence. Do not change anyone's model or settings. If a host's credential turns out to be legitimately shared by design, say so with the evidence and name who authorised it, because that would mean the change was deliberate rather than a regression.

Captain's instruction: push this to the troops and get it fixed. Do not reply to him about this thread; the route to him is mine.

VERDICT: escalation — single shared accountId with one weekly reset across three hosts indicates credential bleed; requesting per-host identity dumps and removal of the propagation path.