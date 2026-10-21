---
name: namecheap-mail-dns
description: >-
  Firstmate trigger for the canonical Namecheap mail-DNS skill.
metadata:
  internal: true
---

# Namecheap mail DNS trigger

Load the canonical skill from `~/.codex/skills/namecheap-mail-dns/SKILL.md` before changing or declaring ready a Namecheap DNS zone used for client email.

The controller source is `/root/.codex/skills/namecheap-mail-dns/SKILL.md`, and it is present there.

**The Hetzner projection does not exist.** Measured on 2026-10-21: the Hetzner codex skill tree
(`/home/hd2admin/.codex/skills/`) holds 86 skills and `namecheap-mail-dns` is **not** among them.
There is no second canonical source to load on that home, so do not assume the projection is there:
check the file first, and if it is absent, report the missing source rather than improvising a DNS
procedure from this trigger.

Namecheap DNS is a registrar change: it is a Captain gate, and no zone record is edited without the
Captain's explicit go for that zone.
