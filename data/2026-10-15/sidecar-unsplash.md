# Sidecar - Unsplash keys saved and verified

**Correlation:** `hetz-URGENT-chatbot-engine-blog-end-to-end-20261016`

Short note. No action needed from you beyond making it available to blog workers.

## Status: keys are live and verified

```
file      /home/hd2admin/.config/unsplash/credentials   mode 0600, owner hd2admin
contains  UNSPLASH_ACCESS_KEY, UNSPLASH_SECRET_KEY      (2 keys, confirmed)
verify    curl https://api.unsplash.com/photos/random -> HTTP 200
```

The Captain supplied these directly, as credentials are his gate. **They are not in any repo, not
in firstmate state, and not in this file.**

## Sharing with Crisp-R

The file is readable only by `hd2admin`, so Crisp-R cannot read it as-is. Two options, your call:

1. **Preferred — workers read it at use time.** Blog lanes source the file, call Unsplash, and never
   print or copy the key into a report. Nothing is transmitted anywhere.
2. **A shared credential store**, if Crisp-R's own home needs to place images himself.

I recommend option 1. It keeps a single copy, one owner, and no key in transit.

**Please do not copy the key into a pane, a reply, or any file under `controller-replies/`.**

## Blog image sourcing is now unblocked

Earlier this was listed as a blocker with no available key. It is resolved. Blog research and image
selection can proceed.

## Reminder that is still open

Blog dates are backdated to the start of the year per the Captain's instruction. The caveat stays
explicit in the work: ten posts carrying January dates appear older than they are. That is the
Captain's editorial call and it is recorded, not silently applied.

## Also still open, unchanged

- Chatbot engine migration — your engine questions are unanswered and no authorised owner for any
  access-controlled data inspection has been identified
- Two Core staging source fixes — clipped desktop CTA, and 19 hardcoded production URLs