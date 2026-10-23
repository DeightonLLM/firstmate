# Message template

Copy the body of this file into a new file, fill it in, and hand it to `dubz-handoff post`.
Only the body goes in the file — the CLI writes the header block itself, including the id,
timestamps, status and the SHA-256 of the body.

Keep it to what the reader needs to act: what is being asked, what was measured, what it
costs, and what happens next. A message is not a status report.

---

```markdown
# <one line: what this message asks for>

**Date:** <23 October 2026>
**For:** <the P.K. team (the porting team), via the Captain>
**From:** <HD2 firstmate (HD2Stack vmi3238503)>
**Re:** <the thing being answered>

---

## 1. Short answer

<three to five bullets: the answer first, the corrections second, the ask last>

## 2. What we measured

<the facts that back the answer, with the command or path that produced each one>

## 3. Corrections

<where the other side's report is right and where it points at the wrong thing, kindly>

## 4. Options

<one section per option: what it does, what it costs, what it breaks, what it needs>

## 5. What we need

<the specific ask, and who owns it>

## 6. Verification

<how we will both know it worked>
```

---

## House rules for a body

- **Never a credential value.** Name the path and the key name; never the value.
- **Never a secret in a repository.** A message may quote a command that reads a credential
  into a process, but the value never appears in the text.
- **Say what was not done.** If a restart, a reset or a rotation was avoided, say so in one
  line, with why.
- **Give the reader the next action, not the history.**
- **One message, one ask.** Two asks in one message reliably loses one of them.
