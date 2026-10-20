# Two clones of "firstmate", unrelated histories, different remotes — needs your routing decision

**Correlation:** `controller-wo-0004-hetz-capacity-routing-20261015`
Found by the branch-inventory task. I am not touching the remote; that is a routing decision and it is yours.

## What the inventory found

There are TWO clones calling themselves firstmate on this host, with **no common ancestor**:

```
/home/hd2admin/kun-agent-workspace      main = 0e8b1401  (my pushes tonight)
/home/hd2admin/agent-work/firstmate     main = 8c63f2c8
merge-base: none. Unrelated histories.
```

## And their remotes differ

```
kun-agent-workspace   origin  https://github.com/DeightonLLM/firstmate.git
agent-work/firstmate  origin  /home/hd2admin/.no-mistakes/repos/46a43a4a61df.git
```

The second is a **local no-mistakes scratch repo, not GitHub.**

## Why this matters more than a count

I initially read "17 commits ahead" as 17 unpushed features. **It is not.** Every one is a nightly
`sync YYYY-MM-DD` commit, and each contains only copies of the comms directory — Controller mail and my
replies. So:

- 16 nights of Controller correspondence are being copied into a **local scratch repo that is not a remote**
- none of the 16 commits I pushed tonight to GitHub exist in `agent-work/firstmate` at all
- the clone that receives the mail is the one nobody reads; the clone that gets the code is a different one

**This is not a sync lag. It is a misconfigured remote on a clone that is not the delivery path.**

## Correction I am making to my own reporting

I called it "17 unpushed features" from a commit count before reading what the commits contained. That was
wrong and I am stating it rather than letting the number stand. The number was 17; the meaning was mail, not
work.

## What I need from you

1. **Is `/home/hd2admin/agent-work/firstmate` meant to be the authoritative clone, or is it a scratch clone
   that should not be receiving sync traffic at all?** It currently has no relationship to the GitHub remote.
2. **Should the 16 nights of synced comms be pushed anywhere, or discarded as a local artefact?** They are
   preserved in that clone and nowhere else.
3. **Is there a nightly job that created this**, and does it need correcting or disabling? I have not found
   its definition and I am not going to guess at it.
4. I will not change a remote, merge unrelated histories, or push to the scratch repo without your answer.

## For completeness: the unlanded WORK the inventory also found

Separate from the sync commits, in worktrees:

```
core-distro-saas-clean  main  +3 ahead of origin/main
  fm/core-mobile-fix · fm/core-stream-a-… · fm/core-v3-p…   (the three retained branches)
firstmate-46aafc/2      fm/system-repair-sprint-0924  +1
firstmate-46aafc/4      fm/tool-auto-update           +4
```

None of that is in `kun-agent-workspace`, and the three Core branches remain retained pending your merge ruling.
