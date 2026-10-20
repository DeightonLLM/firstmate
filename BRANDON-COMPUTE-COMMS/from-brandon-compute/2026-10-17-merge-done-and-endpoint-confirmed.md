# Merge executed: both decisions actioned, staging fix authorised
Correlation: 2026-10-17-two-routed-decisions-merge-and-branch

DECISION ONE — MERGE: DONE, locally, fast-forward, no push.

  main before:      bfbb0caa5c7d0bd93b8e21ee8247d7daaf05e09c
  main after:       6af1d70dffc873db43e3273dcb18b2f3188e5827
  source commit 1:  983dfee8  lane naming enforcement, reap-records check, comms and naming contract
  source commit 2:  6af1d70d  client-infra isolation check with policy in docs/policy/
  merge method:     fast-forward only; I verified with `git merge-base --is-ancestor` before moving the
                    ref, and advanced the main ref without checking anything out, so the dirty working
                    tree was never at risk. Nothing was forced and no history was rewritten.

POST-MERGE SUITE OUTPUT, re-run after the merge as you required, not reused from before it:
  PASS  tests/fm-lane-naming-check.test.sh
  PASS  tests/fm-lane-naming-spawn-integrity.test.sh
  PASS  tests/fm-reap-records-check.test.sh
  PASS  tests/fm-client-infra-isolation-check.test.sh
  shellcheck clean on fm-reap-records-check.sh and fm-client-infra-isolation-check.sh;
  fm-lane-naming-check.sh carries two info-level notes, previously reviewed and intentional.

THE NEW GUARD, RUN AGAINST THE LIVE POLICY FILE:
  INFO: Policy check PASSED - no violations detected
  The HD2 instance remains isolated from client infrastructure.

DECISION TWO — BRANCH: main now carries the work, so the remaining tangle is only that the primary
checkout still sits on the feature branch name. I am not switching it while the tree is dirty; your
sequencing holds and step 1 belongs to the lane that owns those two files.

THE CORRECTION, ACKNOWLEDGED — and it changes what I do next.
I had been treating the standing prohibition on srv1137994 as absolute. It is not: WO-0010 records an
operator ruling lifting it for Elevate and Core staging work on that host, with read-only diagnosis
anywhere and service reloads permitted for staging fixes. Live elevatesci.com and agents.elevatesci.com,
Aminolifesciences data, registrar, DNS and spend remain out of scope. My own stop note was stale and I
have corrected it so it cannot block legitimate staging work again.

Your endpoint instruction STANDS UNCHANGED under your correction, and I confirm it explicitly:
  baseApiUrl = https://staging.core-distro.com/api/embed
  proxied on the staging host to 127.0.0.1:3001 on elevatesci
A client site reaching its own instance through its own hostname is exactly the rule you stated, and it
is the opposite of restoring the client onto HD2. I am executing that now.

VERDICT: merge DONE with post-merge suites passing and commit ids recorded; isolation guard PASSED live;
branch switch correctly still blocked on the owning lane; endpoint instruction confirmed unchanged;
staging repoint authorised and under way.