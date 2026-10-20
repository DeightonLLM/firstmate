import subprocess, os
os.chdir('/home/hd2admin/kun-agent-workspace')
jobs = [
 ("offload-backlog-close-20261014","scout","Close every backlog entry the evidence proves closable","Firstmate owns the decision; you gather the proof. For every backlog entry that is GENUINELY DONE, produce the evidence that proves it, then close it with tasks-axi done. Close only with proof. Never close 'ready in branch' or 'partial' - those are NOT done."),
 ("offload-backlog-phantom-20261014","scout","Close backlog entries that never existed","Close entries with no report, no status record and no task directory. They implied work that never happened. Verify absence first, then close. Produce a one-line reason per entry."),
]
for tid,kind,title,body in jobs:
    subprocess.run(['tasks-axi','add',tid,title,'--kind',kind,'--repo','firstmate','--queue','--body',body],capture_output=True)
    subprocess.run(['bash','bin/fm-brief.sh',tid,'firstmate','--'+kind],capture_output=True)
    p=f'data/{tid}/brief.md'; s=open(p).read()
    task = f"""{title}.

{body}

## Method
Use the existing classification reports in `data/clear-*-20261013/report.md` and
`data/backlog-truth-pass/report.md` as your starting map - the verdicts and evidence paths are already there.
Re-verify each claim yourself against the actual artifact and status tail before acting; two entries were
previously misreported as done and were NOT.

## Close ONLY on proof that the work LANDED
- A branch that exists but is not merged into the target default branch is NOT landed, however the status
  line reads. 'ready in branch X' is NOT done.
- An artifact that exists but whose task never completed is NOT done.
- When in doubt, leave it open and say what proof is missing.

You MAY run `tasks-axi done <id>` for entries you have proven. That is the one state change you are
authorised to make. Do not delete entries, do not use --force, do not touch anything under projects/, do not
push, do not touch the seven secondmate homes.

Report to `/home/hd2admin/kun-agent-workspace/data/{tid}/report.md`: one row per entry with id, action taken
(closed / left open), the proof, and for anything left open the single specific reason.
"""
    open(p,'w').write(s.replace('{TASK}', task, 1)); print('prepared', tid)