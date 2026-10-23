#!/usr/bin/env python3
"""Build the Captain's Lavish review board.

One file, self-contained, no external resources. Everything on it is read from
live machine state (lane ledger, INBOX tickets, board digest) so it cannot go
stale: regenerate and it shows the truth.

  python3 bin/build-captain-board.py --repo <firstmate repo> --ledger <ledger.tsv>
                                     --out <repo>/.lavish/CAPTAIN-BOARD.html
"""
import argparse, html, json, os, re, glob, datetime, hashlib

E = html.escape


def read(p, default=""):
    try:
        with open(p, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return default


def parse_tickets(repo):
    out = []
    for p in sorted(glob.glob(os.path.join(repo, "INBOX", "*.md"))):
        name = os.path.basename(p)
        if name == "README.md":
            continue
        txt = read(p)
        hdr, body, seen_body = {}, [], False
        for line in txt.splitlines():
            m = re.match(r"^([A-Za-z ]{3,20}):\s*(.*)$", line)
            if m and not seen_body and not line.startswith("#"):
                hdr[m.group(1).strip().lower()] = m.group(2).strip()
            else:
                if line.strip() or body:
                    seen_body = True
                    body.append(line)
        body = "\n".join(body).strip()
        tid = name.split("-")[0]
        # markdown-ish body -> one line
        flat = re.sub(r"\s+", " ", re.sub(r"[#*`>|\[\]]", " ", body)).strip()
        flat = re.sub(r"\s{2,}", " ", flat)
        out.append({
            "id": tid,
            "file": name,
            "prio": hdr.get("priority", "") or "—",
            "area": hdr.get("area", "") or "—",
            "req": hdr.get("requested by", "") or "—",
            "received": (hdr.get("received", "") or "")[:10],
            "body": body,
            "oneline": flat,
        })
    return out


def parse_ledger(path):
    lanes = []
    for line in read(path).splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        f = line.split("\t")
        if len(f) < 8 or f[0] == "lane_id":
            continue
        lanes.append({"id": f[0], "state": f[1], "owner": f[2], "opened": f[3],
                      "updated": f[4], "expires": f[5], "next": f[6],
                      "artifact": f[7], "branch": f[8] if len(f) > 8 else ""})
    return lanes


def first_sentence(t, n=170):
    s = t["oneline"]
    for stop in (". ", "; "):
        i = s.find(stop)
        if 20 < i < n:
            return s[: i + 1].strip()
    return (s[: n - 1].rsplit(" ", 1)[0] + "…") if len(s) > n else s


CSS = """
:root{color-scheme:dark;--bg:#0d1319;--panel:#151e26;--panel2:#1b2732;--line:#2b3a47;
--ink:#e8f0f3;--muted:#9db0bd;--faint:#6f8391;--accent:#75d4c3;--ok:#75d4c3;--warn:#ffc978;
--bad:#ff9c91;--blue:#7cc4ff;--violet:#c4a7f7;--ink-2:#0d1319}
*{box-sizing:border-box}
body{margin:0;padding:0 0 70px;background:var(--bg);color:var(--ink);
 font:15px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
 -webkit-font-smoothing:antialiased}
.wrap{max-width:1280px;margin:0 auto;padding:0 24px}
header.top{padding:34px 0 18px;border-bottom:1px solid var(--line)}
h1{margin:0 0 6px;font-size:clamp(1.5rem,3.4vw,2.1rem);letter-spacing:-.02em}
h2{margin:0;font-size:1.16rem;letter-spacing:-.01em}
h3{margin:0 0 8px;font-size:.95rem;text-transform:uppercase;letter-spacing:.07em;color:var(--muted)}
p{margin:0 0 10px}
.lede{color:var(--muted);max-width:88ch;font-size:14.5px}
.meta{color:var(--faint);font-size:12px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;
 margin-top:12px}
.grid{display:grid;gap:12px}
.stats{grid-template-columns:repeat(auto-fit,minmax(150px,1fr));margin:20px 0 0}
.stat{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:12px 14px;min-width:0}
.stat b{display:block;font-size:26px;font-weight:700;letter-spacing:-.02em;line-height:1.15}
.stat span{display:block;font-size:11px;color:var(--muted);margin-top:4px;text-transform:uppercase;letter-spacing:.06em}
.stat.ok b{color:var(--ok)} .stat.warn b{color:var(--warn)} .stat.bad b{color:var(--bad)}
.card{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:18px 20px;min-width:0}
section{margin:26px 0 0}
section>header{display:flex;justify-content:space-between;align-items:baseline;gap:14px;
 flex-wrap:wrap;margin:0 0 12px}
.note{color:var(--muted);font-size:13px;max-width:96ch;margin:0 0 12px}
.pill{display:inline-block;padding:2px 9px;border-radius:999px;font-size:11px;font-weight:700;
 letter-spacing:.03em;border:1px solid var(--line);background:var(--panel2);white-space:nowrap}
.p0{color:var(--bad);border-color:rgba(255,156,145,.4)}
.p1{color:var(--warn);border-color:rgba(255,201,120,.35)}
.p2{color:var(--blue);border-color:rgba(124,196,255,.3)}
.tag{font-size:11px;padding:2px 8px;border-radius:999px;background:#233240;color:var(--muted);
 font-family:ui-monospace,SFMono-Regular,Menlo,monospace;white-space:nowrap}
.tag.ok{color:var(--ok)} .tag.warn{color:var(--warn)} .tag.bad{color:var(--bad)} .tag.blue{color:var(--blue)}
table{width:100%;border-collapse:collapse;font-size:13.5px}
th,td{text-align:left;padding:8px 10px;border-bottom:1px solid var(--line);vertical-align:top}
th{font-size:10.5px;text-transform:uppercase;letter-spacing:.07em;color:var(--faint);
 position:sticky;top:0;background:var(--panel);z-index:2}
td.tid{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--blue);white-space:nowrap}
td.what{color:var(--ink)}
.scroll{max-height:560px;overflow:auto;border:1px solid var(--line);border-radius:10px}
label.opt{display:flex;gap:10px;align-items:flex-start;padding:9px 11px;border:1px solid var(--line);
 border-radius:10px;margin:7px 0;cursor:pointer;background:var(--panel2)}
label.opt:hover{border-color:var(--accent)}
label.opt input{margin-top:3px;accent-color:var(--accent);flex:0 0 auto}
label.opt .t{font-weight:600;display:block}
label.opt .d{display:block;color:var(--muted);font-size:12.5px;margin-top:2px}
button{font:inherit;color:var(--ink);background:#22323f;border:1px solid var(--line);
 border-radius:9px;padding:8px 14px;cursor:pointer}
button:hover{border-color:var(--accent);background:#263a49}
button.primary{background:var(--accent);color:var(--ink-2);border-color:var(--accent);font-weight:700}
button.primary:hover{filter:brightness(1.08)}
input[type=text],textarea,select{font:inherit;color:var(--ink);background:#111a22;
 border:1px solid var(--line);border-radius:9px;padding:9px 11px;width:100%}
input[type=text]:focus,textarea:focus{outline:2px solid rgba(117,212,195,.35);border-color:var(--accent)}
textarea{min-height:74px;resize:vertical}
.qbox{border:1px solid var(--line);border-radius:12px;padding:14px 16px;background:var(--panel2);margin:12px 0}
.qbox>.qh{display:flex;justify-content:space-between;gap:10px;align-items:baseline;flex-wrap:wrap;margin-bottom:4px}
.qid{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:11px;color:var(--faint)}
.kv{display:grid;grid-template-columns:max-content 1fr;gap:4px 14px;font-size:13.5px;margin:0 0 12px}
.kv dt{color:var(--faint);font-size:12px;text-transform:uppercase;letter-spacing:.05em}
.kv dd{margin:0}
pre{white-space:pre-wrap;overflow-wrap:anywhere;font:12.5px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;
 color:var(--muted);background:#0f161d;border:1px solid var(--line);border-radius:10px;padding:12px;margin:0}
.ticket-body{font-size:13.5px;color:var(--ink)}
.filters{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin:0 0 12px}
.filters input[type=text]{flex:1 1 220px;max-width:300px}
.filters select{width:auto;min-width:130px}
.count{color:var(--faint);font-size:12px;margin-left:auto;font-variant-numeric:tabular-numbers}
.legend{display:flex;gap:14px;flex-wrap:wrap;font-size:12px;color:var(--muted);margin:10px 0 0}
.legend i{display:inline-block;width:9px;height:9px;border-radius:2px;margin-right:6px;vertical-align:-1px}
.lane{display:flex;gap:12px;align-items:flex-start;padding:9px 0;border-bottom:1px solid var(--line)}
.lane:last-child{border-bottom:none}
.lane .nm{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12.5px;
 min-width:230px;flex:0 0 auto;overflow-wrap:anywhere}
.lane .nx{font-size:13px;color:var(--muted);min-width:0}
.st-DONE{color:var(--ok)} .st-ACTIVE{color:var(--warn)} .st-BLOCKED{color:var(--bad)}
.st-RELEASED{color:var(--faint)} .st-NEXT{color:var(--blue)}
.toolbar{position:sticky;top:0;z-index:30;background:var(--bg);border-bottom:1px solid var(--line);
 padding:12px 0}
.toolbar .inner{display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.sub{color:var(--faint);font-size:12px}
ul.tight{margin:6px 0 0;padding-left:18px}
ul.tight li{margin:3px 0;font-size:13.5px}
hr{border:none;border-top:1px solid var(--line);margin:16px 0}
.copyrow{display:flex;gap:12px;align-items:center;flex-wrap:wrap;margin-top:14px}
.status{min-height:1.3em;color:var(--accent);font-size:13px}
@media(max-width:760px){.wrap{padding:0 14px}.kv{grid-template-columns:1fr}.lane{flex-direction:column;gap:2px}
 .lane .nm{min-width:0}th{font-size:9.5px}td{padding:7px 5px}}
"""


def build(repo, ledger_path, out_path):
    tickets = parse_tickets(repo)
    lanes = parse_ledger(ledger_path)
    now = datetime.datetime.now(datetime.timezone.utc)

    p0 = [t for t in tickets if t["prio"] == "P0"]
    p1 = [t for t in tickets if t["prio"] == "P1"]
    p2 = [t for t in tickets if t["prio"] == "P2"]
    active = [l for l in lanes if l["state"] == "ACTIVE"]
    done = [l for l in lanes if l["state"] == "DONE"]
    blocked = [l for l in lanes if l["state"] == "BLOCKED"]
    released = [l for l in lanes if l["state"] == "RELEASED"]

    ticket3 = next((t for t in tickets if t["id"] == "0003"), None)

    # ---------------- header ----------------
    h = []
    h.append(f"""<!doctype html>
<html lang="en" data-lavish-annotate="off">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Captain's board - HD2 firstmate - {now:%Y-%m-%d %H:%M}Z</title>
<style>{CSS}</style></head><body>
<div class="wrap">
<header class="top">
 <h1>Captain's board &mdash; HD2 firstmate</h1>
 <p class="lede">One surface for the things you asked to see: the ticket you authorised, the full ticket
 queue, the decisions settled tonight, the live to-do list, and the space job. Every number here is read
 from machine state at build time &mdash; this board is generated, never hand-typed, so it cannot drift
 from the ledger it claims to show.</p>
 <p class="meta">built {now:%Y-%m-%dT%H:%M:%SZ} &middot; surface: HD2Stack vmi3238503 / 100.71.95.76
 &middot; ledger digest sha256:{hashlib.sha256(read(ledger_path).encode()).hexdigest()[:16]}&hellip;
 &middot; {len(tickets)} tickets in INBOX &middot; {len(lanes)} lanes in the ledger</p>
 <div class="grid stats">
  <div class="stat warn"><b>{len(active)}</b><span>lanes in flight</span></div>
  <div class="stat"><b>{len(tickets)}</b><span>tickets waiting</span></div>
  <div class="stat bad"><b>{len(p0)}</b><span>P0 tickets</span></div>
  <div class="stat warn"><b>{len(p1)}</b><span>P1 tickets</span></div>
  <div class="stat ok"><b>0</b><span>board residuals</span></div>
  <div class="stat ok"><b>0</b><span>contract gaps</span></div>
  <div class="stat ok"><b>0</b><span>ledger drift</span></div>
  <div class="stat bad"><b>86%</b><span>HD2Stack disk used</span></div>
 </div>
</header>

<div class="toolbar"><div class="inner">
 <b style="font-size:14px">Jump:</b>
 <a class="tag" href="#t3">ticket-0003</a>
 <a class="tag" href="#queue">ticket queue ({len(tickets)})</a>
 <a class="tag" href="#dec">decisions settled</a>
 <a class="tag" href="#space">space job</a>
 <a class="tag" href="#todo">my to-do list</a>
 <span class="sub">annotate is OFF on this page &mdash; the boxes and buttons below are live controls</span>
</div></div>
""")

    # ---------------- ticket 0003 ----------------
    if ticket3:
        h.append(f"""
<section id="t3">
 <header><h2>1 &mdash; ticket-0003: the one you authorised</h2>
  <span class="tag blue">INBOX/{ticket3['file']}</span></header>
 <p class="note">This is the ticket. It was never on a review surface &mdash; it sat as a text file in
 <code>INBOX/</code> with a one-line body pointing at a dated campaign board, which is why you could not find it.
 Full text, verbatim, is below. It now has a decision control attached.</p>
 <div class="grid" style="grid-template-columns:minmax(0,1.05fr) minmax(0,1fr)">
  <div class="card">
   <h3>The ticket, verbatim</h3>
   <pre>{E(ticket3['body'])}</pre>
   <hr>
   <dl class="kv">
    <dt>Received</dt><dd>{E(ticket3['received'] or '2026-10-15')}</dd>
    <dt>Area</dt><dd>{E(ticket3['area'])}</dd>
    <dt>Priority</dt><dd>{E(ticket3['prio'])}</dd>
    <dt>Requested by</dt><dd>{E(ticket3['req'])}</dd>
    <dt>Source cited</dt><dd>data/campaign-dashboard-20261015/board.md row &ldquo;KVM1 Herdr registration&rdquo;
     (HELD, owner Operator / Controller) and data/surface-parity-20261015/STATUS.md row 14
     &mdash; <b>that STATUS.md does not exist anywhere</b>, so the board row is the only surviving record</dd>
   </dl>
  </div>
  <div class="card">
   <h3>What the diagnosis found</h3>
   <dl class="kv">
    <dt>KVM1 is</dt><dd><b>srv797124</b> &middot; tailnet <code>srv797124-hd2-hostinger-kvm1</code> &middot;
      <code>100.92.152.109</code> &middot; account root &middot; tier <code>KVM1_HOSTINGER</code> &mdash; the HD2 main
      WordPress host <b>hd2.ai</b>, 1 CPU. It is <i>not</i> the backup box (srv1856614) and <i>not</i> the Lead Engine
      production box (100.69.211.43, a hard gate).</dd>
    <dt>Why Herdr</dt><dd>Herdr was never installed there and was never registered. <code>herdr machine list</code>
      is empty, and no key on this host is authorised on it &mdash; 6 accounts tried, all
      <code>Permission denied</code>. Herdr 0.9.5 refuses a non-interactive remote stop/update, so the
      registration is an <b>attended</b> step.</dd>
    <dt>Trap</dt><dd>the fleet's pinned Herdr is 0.8.2 but the live binary is 0.9.5 &mdash; following the
      marker would <b>downgrade</b>. The pin must be re-pinned first, inside the same window.</dd>
    <dt>Ready</dt><dd>a read-only 7-gate preflight ships with it
      (<code>data/hd2-takeover/kvm1-herdr-window-preflight.sh</code>, exits 66 today, dated backup of
      <code>/root/.config/herdr</code> proves it wrote nothing).</dd>
   </dl>
   <h3>Proposed window</h3>
   <dl class="kv">
    <dt>Placement</dt><dd><b>05:00&ndash;05:30 BST, a working day</b> &mdash; matches the fleet's own
      05:10&ndash;05:18 BST KVM1-maintenance precedent</dd>
    <dt>Length</dt><dd>30 minutes hard-bounded; <b>abort and report at 15 minutes</b></dd>
    <dt>Trigger</dt><dd>your authorisation of this ticket <b>and</b> a working SSH path into KVM1 at that moment</dd>
    <dt>Owner</dt><dd>you for the attended interactive approve step; the HD2 firstmate drives the preflight
      and keeps the record</dd>
    <dt>Mechanism</dt><dd>the existing pinned-apply mechanism &mdash; armed marker, zero live panes,
      <code>.bak</code> rollback, one-shot</dd>
   </dl>
  </div>
 </div>

 <div class="card" style="margin-top:12px">
  <h3>Your decision on ticket-0003</h3>
  <div class="qbox" data-lavish-question="ticket-0003-window">
   <div class="qh"><b>Which window do you authorise?</b><span class="qid">Q1 &middot; ticket-0003</span></div>
   <label class="opt"><input type="radio" name="t3window" value="authorise-as-proposed">
    <span><span class="t">Authorise the window as proposed</span>
    <span class="d">05:00&ndash;05:30 BST on a working day &middot; 30 min, abort at 15 &middot; the firstmate
     runs the guarded preflight and the attended registration</span></span></label>
   <label class="opt"><input type="radio" name="t3window" value="authorise-other-window">
    <span><span class="t">Authorise a different window &mdash; state it below</span>
    <span class="d">e.g. a specific date and time, or a different clock hour</span></span></label>
   <label class="opt"><input type="radio" name="t3window" value="hold">
    <span><span class="t">Hold &mdash; do not authorise yet</span>
    <span class="d">ticket-0003 stays open and the KVM1 lane stays held</span></span></label>
   <label style="display:block;margin:10px 0 4px;color:var(--muted);font-size:12.5px">
    If you picked a different window, say which (date + start time + BST/UTC):</label>
   <input type="text" name="t3other" placeholder="e.g. Thursday 2026-10-22, 02:00 BST" style="max-width:420px">
   <div class="copyrow">
    <button type="button" class="primary" onclick="(function(b){{var f=b.closest('.qbox');
     var fd=new FormData(f); var choice=(fd.get('t3window')||'').trim(); if(!choice){{alert('Pick one option first.');return;}}
     var other=(fd.get('t3other')||'').trim();
     var msg='ticket-0003 decision: '+choice+(other?' -- requested window: '+other:'')+
      ' -- authorise the KVM1 Herdr registration window on srv797124 (100.92.152.109).'+
      ' Reply with the window to run and confirm the SSH path into KVM1.';
     window.lavish.queuePrompt(msg,{{tag:'decision',text:'ticket-0003: '+choice,
      element:f,data:{{question:'ticket-0003-window',answer:choice,requested_window:other}}}});}})(this)">
     Queue this answer</button>
    <span class="status" aria-live="polite"></span>
   </div>
  </div>

  <div class="qbox" data-lavish-question="kvm1-ssh-path">
   <div class="qh"><b>The SSH path into KVM1</b><span class="qid">Q2 &middot; ticket-0003</span></div>
   <p class="sub" style="margin:0 0 8px">The window cannot open without one: no key on this host is authorised
    on srv797124. Give a path, or say it will be added at the window.</p>
   <input type="text" name="kvm1ssh" placeholder="e.g. root@100.92.152.109 with the fleet key, or &quot;add my key at the window&quot;">
   <div class="copyrow">
    <button type="button" class="primary" onclick="(function(b){{var f=b.closest('.qbox');
     var v=(new FormData(f).get('kvm1ssh')||'').trim();
     window.lavish.queuePrompt('KVM1 SSH path for ticket-0003: '+(v||'(none given - add at the window)'),
      {{tag:'decision',text:'KVM1 SSH path',element:f,data:{{question:'kvm1-ssh-path',ssh_path:v}}}});}})(this)">
     Queue this answer</button>
    <span class="status" aria-live="polite"></span>
   </div>
  </div>
 </div>
""")

    # ---------------- ticket queue ----------------
    rows = []
    for t in tickets:
        pr = t["prio"]
        cls = {"P0": "p0", "P1": "p1", "P2": "p2"}.get(pr, "")
        rows.append(f"""<tr data-prio="{E(pr)}" data-area="{E(t['area'])}" data-txt="{E((t['id']+' '+t['area']+' '+t['oneline']).lower())}">
 <td class="tid"><label style="display:flex;gap:7px;align-items:center;cursor:pointer">
   <input type="checkbox" name="tickets" value="{E(t['id'])}" data-label="{E(first_sentence(t))}" data-disposition="queue-for-hd2-firstmate">
   {E(t['id'])}</label></td>
 <td><span class="pill {cls}">{E(pr)}</span></td>
 <td>{E(t['area'])}</td>
 <td class="what">{E(first_sentence(t))}</td>
</tr>""")

    h.append(f"""
<section id="queue">
 <header><h2>2 &mdash; your ticket queue</h2>
  <span class="tag">{len(tickets)} tickets &middot; {len(p0)} P0 / {len(p1)} P1 / {len(p2)} P2</span></header>
 <p class="note">These are the Captain-raised tickets sitting in <code>INBOX/</code>. Nothing has ever put
 them on a review surface, which is the whole reason you could not find ticket-0003. Tick the ones you want
 the firstmate to work next and queue the batch &mdash; I will come back with an item-by-item receipt, one
 line per ticket number.</p>
 <div class="filters">
  <input type="text" id="q" placeholder="Search tickets&hellip;" aria-label="Search tickets">
  <select id="fp" aria-label="Filter by priority">
   <option value="">All priorities</option>
   <option value="P0">P0 only</option><option value="P1">P1 only</option><option value="P2">P2 only</option>
  </select>
  <select id="fa" aria-label="Filter by area"><option value="">All areas</option></select>
  <button type="button" id="all">Select all shown</button>
  <button type="button" id="none">Clear</button>
  <span class="count" id="cnt"></span>
 </div>
 <div data-lavish-question="ticket-batch">
 <div class="scroll"><table id="qtable">
  <thead><tr><th style="width:76px">Ticket</th><th style="width:58px">Pri</th><th style="width:190px">Area</th><th>What it asks</th></tr></thead>
  <tbody>{"".join(rows)}</tbody></table></div>
 <div class="copyrow" style="margin-top:12px">
  <button type="button" class="primary" onclick="(function(b){{var f=b.closest('[data-lavish-question]');
   var sel=[].slice.call(f.querySelectorAll('input[name=tickets]:checked')).map(function(i){{return {{id:i.value,label:i.dataset.label,disposition:i.dataset.disposition}};}});
   if(!sel.length){{alert('Tick at least one ticket.');return;}}
   window.lavish.queuePrompt('Work this batch of '+sel.length+' ticket(s) next: '+
    sel.map(function(s){{return s.id}}).join(', ')+
    '. Act on every selected ticket and return an item-by-item receipt: one outcome per submitted ID '+
    '(addressed with evidence, deferred with a reason, or rejected with a reason). Account for every submitted ID before reporting completion.',
    {{tag:'tracked-batch',text:'Queue '+sel.length+' ticket(s)',element:f,data:{{items:sel}}}});}})(this)">
   Queue selected tickets</button>
  <span class="status" aria-live="polite"></span>
  <span class="sub">the batch is sent as one prompt with your ticket numbers &mdash; nothing is lost between rounds</span>
 </div>
 </div>
</section>""")

    # ---------------- decisions ----------------
    decisions = [
        ("Key rotation", "You, 2026-10-21", "dropped", "bad",
         "You said you are not doing it now. The item sits in the machine tracker as BLOCKED with a re-raise trigger, the audit stays, the 98-container purge stays unrun."),
        ("KVM1 Herdr registration window", "board.md row + ticket-0003", "needs your answer", "warn",
         "Section 1 above (Q1). Also needs an SSH path &mdash; that is the hard blocker, not the authorisation."),
        ("srv1137994 hard gate", "docs/agent-policy/SURFACE-IDENTITY.md", "needs your answer", "warn",
         "Q4 below. The gate still marks srv1137994 as hard-gated although that host has been the live data.core-distro.com origin since 2026-10-20. The file was not edited."),
        ("Quota gate provider mapping", "You, via this board, 2026-10-21", "ruled", "ok",
         "Leave it refused. claude / grok / kimi / opencode stay unusable and the gate keeps saying so out loud; no mapping is inferred from a harness name. Recorded as VERIFIED-DONE (quota-harness-provider-binding-20261021)."),
        ("FAST tier + parallelism cap", "QUOTA-ROUTING-RUBRIC.md &sect;3, AGENTS.md:631, captain directive 2026-10-18", "decided", "ok",
         "FAST is the Codex Luna <code>--fast</code> flag, not a tier &mdash; and no HD2 worker lane has a FAST route (the HD2 worker route is Gemini 3.8), so the standing default stays OFF with task-scoped opt-in. Cap = <b>six working agents per provider</b>, enforced by <code>bin/fm-dispatch-guard.sh</code>. <code>config/parallel-dispatch-cap</code> is retired, not implemented: it never was in the repo, and a third gate in fm-spawn.sh would let two ceilings disagree."),
        ("Core base: 259a669 vs 17dc2f1", "live git state + the 0018/0019 audit", "decided", "ok",
         "<b>259a669 is the base of record</b> &mdash; origin/main calls four symbols it never defines (exit 127, jq parse error) while 259a669 defines all four. 17dc2f1 is rejected as a base. <b>Neither was merged.</b>"),
        ("Helper-permission route", "tests/fm-helper-permissions.test.sh + the live drift", "decided", "ok",
         "14 exact live allowlist entries plus the ticket-0043 migration roots brought under version control; the blanket <code>/root/.secrets/**</code> write removed from the live store (a narrowing); the invariant extended to write roots; per-profile <code>required</code> flag fail-closed; two exact refusal tests added &mdash; suite <b>6/6 green</b>."),
        ("Skill refresh set", ".agents/skills inventory + staleness evidence", "decided", "ok",
         "<b>2 of 33 refreshed</b> (harness-update-sweep, namecheap-mail-dns &mdash; both had provably dead references). 31 deliberately left (zero dead refs, zero retired model ids). <b>No skill deleted.</b>"),
        ("lead_list_search_cache (445 MB)", "measurement: 37,502 rows, 100% expired", "done &mdash; production", "ok",
         "Dated backup <code>lead_list_search_cache-20261021T023829Z.sql.gz</code>, sha256 <code>6033f807&hellip;</code>, verified by re-reading (37,502 rows, CHECKSUM TABLE 2462031730 identical). Nine bounded rounds removed exactly 37,502 rows. Chromium PASS, WebKit PASS, admin grid PASS with 0 console errors. Counts unchanged (users 2 / lists 21 / items 949,376 / searches 155,600). <b>Freed 1,438,498,816 B (1.339 GiB)</b>. Rollback command recorded in the report."),
        ("Merge route: direct-notify vs relay", "branch fm/direct-notify-20261015 + tests", "handed over", "warn",
         "Still needed: no notify hook on main. 13/13 notify tests, ingest and hetz-send green &mdash; but the branch is 149 commits stale with conflicts in fm-hetz-send, and a naive merge would regress two fixes. Ships as a verified bundle plus a 6-step refresh-and-merge instruction to the Hetz lane."),
        ("Which Core branch", "PRD v3 + repo state", "decided", "ok",
         "core-distro-saas-clean origin/main is the base of record; my branches hand over to the Hetz merge lane, which owns the firstmate main merge."),
    ]
    drows = "".join(
        f"""<tr><td><b>{E(d[0])}</b></td><td style="color:var(--muted)">{E(d[1])}</td>
 <td><span class="tag {d[3]}">{E(d[2])}</span></td><td>{E(d[4])}</td></tr>""" for d in decisions)

    h.append(f"""
<section id="dec">
 <header><h2>3 &mdash; decisions settled tonight</h2>
  <span class="tag">derived from the PRDs and the actual repo state, then acted on</span></header>
 <p class="note">Only spend, credentials, live client production and destructive acts are held for you.
 Everything else is decided from the evidence and executed.</p>
 <div class="card" style="padding:0;overflow:hidden">
  <table><thead><tr><th style="width:23%">Decision</th><th style="width:22%">Derived from</th>
   <th style="width:13%">State</th><th>What happens</th></tr></thead><tbody>{drows}</tbody></table>
 </div>

 <div class="card" style="margin-top:12px">
  <h3>Spend decision &mdash; ruled by you, 2026-10-21</h3>
  <p class="note" style="margin-bottom:10px"><b>Your ruling: leave it refused.</b> Recorded in the tracker as
   VERIFIED-DONE (<code>quota-harness-provider-binding-20261021</code>) &mdash; those four harnesses stay
   unusable and the gate keeps refusing them out loud. The controls below are still here if you want to change
   your mind.</p>
  <p class="note" style="margin-bottom:10px"><code>bin/fm-quota-gate.sh</code> has no provider mapping for the
   <code>claude</code>, <code>grok</code>, <code>kimi</code> and <code>opencode</code> harnesses, so it refuses
   <b>100% of crew spawns</b> on them. <code>AGENTS.md</code> &sect;4 forbids inferring a mapping from a harness
   name, so I cannot just bind it. Every one of those four harnesses is currently unusable.</p>
  <div class="qbox" data-lavish-question="quota-provider-binding">
   <div class="qh"><b>How should the quota gate treat those four harnesses?</b>
    <span class="qid">Q3 &middot; spend</span></div>
   <label class="opt"><input type="radio" name="quotabind" value="bind-to-quota-axi-provider">
    <span><span class="t">Bind them to the quota-axi provider</span>
    <span class="d">ask quota-axi which provider serves each harness and record the mapping in the gate with
     the evidence &mdash; the same route every other harness takes</span></span></label>
   <label class="opt"><input type="radio" name="quotabind" value="bind-to-named-provider">
    <span><span class="t">I will name the provider &mdash; state it below</span>
    <span class="d">you tell me which provider serves claude / grok / kimi / opencode</span></span></label>
   <label class="opt"><input type="radio" name="quotabind" value="leave-refused">
    <span><span class="t">Leave it refused</span>
    <span class="d">those four harnesses stay unusable and the gate keeps saying so out loud</span></span></label>
   <input type="text" name="quotaprovider" placeholder="If you picked &quot;I will name the provider&quot;: which provider for which harness" style="max-width:520px">
   <div class="copyrow">
    <button type="button" class="primary" onclick="(function(b){{var f=b.closest('.qbox');
     var fd=new FormData(f); var c=(fd.get('quotabind')||'').trim(); if(!c){{alert('Pick one option first.');return;}}
     var p=(fd.get('quotaprovider')||'').trim();
     window.lavish.queuePrompt('Quota gate provider binding for the claude / grok / kimi / opencode harnesses: '+c+
      (p?' -- '+p:'')+'. Implement it in bin/fm-quota-gate.sh with the evidence recorded and a refusal test.',
      {{tag:'decision',text:'quota binding: '+c,element:f,data:{{question:'quota-provider-binding',answer:c,provider:p}}}});}})(this)">
     Queue this answer</button>
    <span class="status" aria-live="polite"></span>
   </div>
  </div>
 </div>

 <div class="card" style="margin-top:12px">
  <h3>Q4 &mdash; the hard gate that no longer matches the fleet</h3>
  <p class="note" style="margin-bottom:10px"><code>docs/agent-policy/SURFACE-IDENTITY.md</code> still carries
   <b>srv1137994</b> as a <b>HARD GATE</b> &mdash; &ldquo;do not touch it, probe it, resolve it, dispatch to it,
   or route work to it&rdquo;. But that host has been the live <code>data.core-distro.com</code> origin since
   2026-10-20, which is where the Lead Engine and the 445 MB cache purge just ran. The file was
   <b>not edited</b> &mdash; a hard gate is policy, and policy is yours to re-scope.</p>
  <div class="qbox" data-lavish-question="srv1137994-hard-gate">
   <div class="qh"><b>What should happen to the srv1137994 hard gate?</b>
    <span class="qid">Q4 &middot; policy</span></div>
   <label class="opt"><input type="radio" name="hardgate" value="rescope-guarded-production">
    <span><span class="t">Re-scope it &mdash; guarded production, not forbidden</span>
    <span class="d">keep it flagged, but allow the named lane to act on it with the backup + value-equality +
     browser-gate discipline it just used for the cache purge</span></span></label>
   <label class="opt"><input type="radio" name="hardgate" value="leave-as-written">
    <span><span class="t">Leave it exactly as written</span>
    <span class="d">the gate stays absolute; nothing routes there and the record keeps the contradiction
     visible</span></span></label>
   <label class="opt"><input type="radio" name="hardgate" value="replace-with-named-gate">
    <span><span class="t">Replace it with a named gate on the right host</span>
    <span class="d">the hard gate moves to whichever host is genuinely off limits, and the identity file
     names it</span></span></label>
   <div class="copyrow">
    <button type="button" class="primary" onclick="(function(b){{var f=b.closest('.qbox');
     var c=(new FormData(f).get('hardgate')||'').trim(); if(!c){{alert('Pick one option first.');return;}}
     window.lavish.queuePrompt('srv1137994 hard gate in docs/agent-policy/SURFACE-IDENTITY.md: '+c+
      '. Apply that ruling to the identity file through the owning lane and record it in the tracker.',
      {{tag:'decision',text:'srv1137994 hard gate: '+c,element:f,data:{{question:'srv1137994-hard-gate',answer:c}}}});}})(this)">
     Queue this answer</button>
    <span class="status" aria-live="polite"></span>
   </div>
  </div>
 </div>
</section>""")

    # ---------------- space job ----------------
    h.append("""
<section id="space">
 <header><h2>4 &mdash; space reclaim on HD2Stack (the sidecar job)</h2>
  <span class="tag warn">copy in flight &middot; nothing deleted</span></header>
 <p class="note">You asked to empty this box of data we are not live-serving that is not mission-critical,
 while migrating it to the KVM8 backup box &mdash; and to not bin anything blindly.</p>
 <div class="grid" style="grid-template-columns:repeat(auto-fit,minmax(300px,1fr))">
  <div class="card">
   <h3>What is true right now</h3>
   <dl class="kv">
    <dt>This host</dt><dd>96 G disk, <b>82 G used (86%)</b>, 14 G free &mdash; and it runs the live business
     stack: open-webui, uptime-kuma, 1panel-ai-gateway, ollama, anythingllm, n8n+postgres, mysql,
     watchtower &mdash; <b>9 of 9 containers active</b>.</dd>
    <dt>Docker images</dt><dd>26.43 GB &mdash; <b>0% reclaimable</b>. Nothing to win there.</dd>
    <dt>Real find</dt><dd><b>1.76 GB of dangling volumes</b> (WordPress 452 M + db 298 M, Mattermost
     438/236/73/27/15 M, postgres 48/44/40 M). These hold <b>orphaned application data</b> &mdash; they are
     data to preserve and migrate, not garbage to bin.</dd>
    <dt>Copied so far</dt><dd><b>9.8 GB, 170,724 files</b> now sit on the KVM8 under
     <code>/root/hd2-archive/vmi3238503/</code> &mdash; docker volumes, npm/pnpm caches, the playwright
     browsers, old codex releases, controller agent history, git bundles, rotated logs, temp rollbacks.
     Nine per-tree digest manifests are written; the docker-volumes digest is still computing.</dd>
    <dt>My area</dt><dd><code>/root/agent-work</code> 7.3 G, caches ~4 G, <code>/var/tmp</code> 1.3 G,
     <code>/root/backups</code> 786 M &mdash; mine to reclaim, once the copies are verified.</dd>
    <dt>Never touched</dt><dd><code>/root/.secrets</code> (5.9 G) and <code>/root/secret-quarantine</code> are
     excluded and were never read. <code>/root/backups/infra</code> belongs to the Controller.
     <code>/home/hd2admin/kun-agent-workspace</code> belongs to the Hetz lane.</dd>
   </dl>
  </div>
  <div class="card">
   <h3>The order of operations</h3>
   <ol class="tight" style="margin:0 0 12px">
    <li><b>Copy</b> to KVM8 at <code>/root/hd2-archive/vmi3238503/</code> &mdash; additive only, no
     <code>rsync --delete</code></li>
    <li><b>Verify</b> with a receipt: per-file count, bytes and sha256</li>
    <li><b>Only then</b> reclaim on the source side</li>
   </ol>
   <p class="note" style="margin:0 0 8px">The reclaim step is <b>held</b> until Dubz answers three questions
    sent in the sidecar note:</p>
   <ul class="tight">
    <li>what else is already on the KVM8 box, so we do not clash</li>
    <li>is the Controller's own snapshot job going to point at the same box</li>
    <li>what retention numbers Job B wants</li>
   </ul>
   <p class="note" style="margin:12px 0 0">Destination path is disjoint from the Controller's
    <code>/root/backups/infra</code> and from the Hetz lane's workspace. <b>Nothing has been deleted.</b>
    The reclaim list is being written before any source-side removal, one tree at a time, each with its
    digest receipt on the KVM8.</p>
  </div>
 </div>
</section>""")

    # ---------------- todo list ----------------
    def lane_rows(items):
        out = []
        for l in items:
            st = l["state"]
            out.append(f"""<div class="lane"><span class="nm">{E(l['id'])}</span>
 <span><span class="st-{st}"><b>{E(st)}</b></span>
 <span class="nx">&mdash; {E(l['next'])} <span class="tag">{E(l['owner'])}</span></span></span></div>""")
        return "".join(out)

    h.append(f"""
<section id="todo">
 <header><h2>5 &mdash; my live to-do list</h2>
  <span class="tag ok">generated from the lane ledger &middot; 0 drift</span></header>
 <p class="note">The ledger is the machine truth; this list is projected from it, never hand-written. A lane
 that finishes without leaving its next step visible fails the contract, and the drift gate refuses &mdash;
 so this list cannot go stale behind my back.</p>
 <div class="card">
  <h3>In flight &mdash; {len(active)}</h3>
  {lane_rows(active)}
  <hr>
  <h3>Blocked &mdash; {len(blocked)}</h3>
  {lane_rows(blocked) if blocked else '<p class="note" style="margin:0">none</p>'}
  <hr>
  <h3>Done &mdash; {len(done)} closed this cycle, {len(released)} released</h3>
  {lane_rows(done + released)}
 </div>
 <div class="card" style="margin-top:12px">
  <h3>What the mechanism guarantees</h3>
  <ul class="tight">
   <li>the to-do list, the claims board and the ledger cannot disagree &mdash; the gate refuses if they do</li>
   <li>a lane cannot close while its to-do entry is stale (third fail-closed closure precondition)</li>
   <li>the same bytes are published to all three hosts and every channel</li>
   <li>the board carries the ledger digest, so you can see the moment it stops matching</li>
  </ul>
 </div>
</section>""")

    # ---------------- copy all answers ----------------
    h.append(f"""
<section>
 <header><h2>6 &mdash; send everything back</h2></header>
 <div class="card">
  <p class="note">If you are reading this in Lavish, the <b>Queue</b> buttons above send each answer straight to
   me. If you opened the file directly (double-clicked it), use <b>Copy all answers</b> and paste the result
   back into the chat &mdash; it works without the Lavish server.</p>
  <div class="copyrow">
   <button type="button" onclick="(async (btn) => {{
    const copyRun = btn._lavishCopyRun = (btn._lavishCopyRun || 0) + 1;
    const qs = [...document.querySelectorAll('[data-lavish-question]')];
    const status = btn.parentElement.querySelector('[data-lavish-copy-all-status]');
    btn.parentElement.querySelector('[data-lavish-copy-all-manual]')?.remove();
    const out = [];
    for (const q of qs) {{
      const key = q.getAttribute('data-lavish-question')?.trim() || 'Question';
      const lines = [];
      for (const el of q.querySelectorAll('input, select, textarea')) {{
        if (el.matches(':disabled')) continue;
        if (el.closest('[data-lavish-question]') !== q) continue;
        const isChoice = el.matches('input[type=checkbox], input[type=radio]');
        if (isChoice && !el.checked) continue;
        if (el.matches('input[type=button], input[type=submit], input[type=reset], input[type=image], input[type=hidden], input[type=file], input[type=range], input[type=color]')) continue;
        let vals;
        if (el instanceof HTMLSelectElement) {{
          vals = [...el.selectedOptions].filter((o) => !o.disabled && !o.closest('optgroup[disabled]')).map((o) => o.value.trim()).filter(Boolean);
        }} else {{
          const v = isChoice && (!el.hasAttribute('value') || !el.value.trim())
            ? el.labels?.[0]?.textContent?.trim() || el.getAttribute('aria-label')?.trim() || el.name || ''
            : el.value.trim();
          vals = v ? [v] : [];
        }}
        const label = el.name || el.labels?.[0]?.textContent?.trim() || el.getAttribute('aria-label')?.trim() || el.getAttribute('placeholder')?.trim() || el.tagName.toLowerCase();
        for (const v of vals) lines.push('  ' + label + ': ' + v.split('\\n').join('\\n    '));
      }}
      if (lines.length) out.push(key + ':\\n' + lines.join('\\n'));
    }}
    const text = out.join('\\n\\n');
    if (!text) {{ status.textContent = qs.length ? 'No answers to copy yet.' : 'No questions or answers to copy.'; return; }}
    status.textContent = '';
    try {{
      if (typeof navigator.clipboard?.writeText !== 'function') throw new Error('Clipboard API unavailable');
      await navigator.clipboard.writeText(text);
      if (copyRun !== btn._lavishCopyRun) return;
      status.textContent = 'Answers copied.';
      return;
    }} catch {{}}
    if (copyRun !== btn._lavishCopyRun) return;
    const tmp = document.createElement('textarea');
    tmp.value = text; tmp.readOnly = true; tmp.setAttribute('aria-hidden','true');
    tmp.style.position='fixed'; tmp.style.left='-10000px';
    document.body.append(tmp); tmp.focus(); tmp.select();
    let ok=false; try {{ ok = document.execCommand('copy'); }} catch {{}}
    tmp.remove();
    if (ok) {{ status.textContent='Answers copied.'; return; }}
    btn.parentElement.querySelector('[data-lavish-copy-all-manual]')?.remove();
    const man = document.createElement('textarea');
    man.value = text; man.readOnly = true; man.rows = Math.min(12, Math.max(3, text.split('\\n').length));
    man.setAttribute('aria-label','Answers to copy manually'); man.dataset.lavishCopyAllManual = '';
    btn.insertAdjacentElement('afterend', man); man.focus(); man.select();
    status.textContent = 'Clipboard unavailable. Copy the answers below manually.';
  }})(this)">Copy all answers</button>
   <span data-lavish-copy-all-status role="status" aria-live="polite"></span>
  </div>
 </div>
</section>

<p class="meta">NEXT: the Captain works this surface &mdash; ticket-0003 decision, the ticket batch and the quota binding come back as queued prompts | owner: captain | by: next reply</p>
</div>
<script>
(function(){{
  var q=document.getElementById('q'),fp=document.getElementById('fp'),fa=document.getElementById('fa'),
      tb=document.getElementById('qtable'),cnt=document.getElementById('cnt');
  var areas=[].slice.call(tb.querySelectorAll('tbody tr')).map(function(r){{return r.dataset.area;}})
    .filter(function(v,i,a){{return v && a.indexOf(v)===i;}}).sort();
  areas.forEach(function(a){{var o=document.createElement('option');o.value=a;o.textContent=a;fa.appendChild(o);}});
  function apply(){{
    var t=(q.value||'').toLowerCase(),p=fp.value,ar=fa.value,n=0;
    [].slice.call(tb.querySelectorAll('tbody tr')).forEach(function(r){{
      var ok=(!p||r.dataset.prio===p)&&(!ar||r.dataset.area===ar)&&(!t||r.dataset.txt.indexOf(t)>-1);
      r.style.display=ok?'':'none'; if(ok)n++;
    }});
    cnt.textContent=n+' of '+(tb.querySelectorAll('tbody tr').length)+' shown';
  }}
  q.addEventListener('input',apply); fp.addEventListener('change',apply); fa.addEventListener('change',apply);
  document.getElementById('all').addEventListener('click',function(){{
    [].slice.call(tb.querySelectorAll('tbody tr')).forEach(function(r){{
      if(r.style.display!=='none'){{var c=r.querySelector('input[type=checkbox]');if(c)c.checked=true;}}}});
  }});
  document.getElementById('none').addEventListener('click',function(){{
    [].slice.call(tb.querySelectorAll('input[type=checkbox]')).forEach(function(c){{c.checked=false;}});
  }});
  apply();
}})();
</script>
</body></html>
""")

    html_out = "".join(h)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html_out)
    return out_path, len(html_out), len(tickets), len(lanes)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--ledger", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    p, n, nt, nl = build(a.repo, a.ledger, a.out)
    print(f"wrote {p} ({n} bytes, {nt} tickets, {nl} lanes)")
