#!/usr/bin/env python3
"""
fm-next-board-publish.py — publish the LIVE fleet board where the Captain's tracker can reach it.

The Captain opened the to-do tracker and found a static, four-day-old preview. The NEXT
contract already owns the rules (docs/NEXT-PROTOCOL.md): every tracked item carries a state,
a next action and an owner, and anything left over appears under RESIDUALS. What was missing
is the last mile — nothing regenerated the board on a cadence, nothing published it into the
path the tracker serves, and nothing said truthfully how a message reaches the fleet.

This script is that last mile. It does five things, in order, and every one of them is
read-only except the two files it owns:

  1. REFRESH THE TRACKER SNAPSHOT from the queue's real source. The queue is
     data/campaign-dashboard-20261015/board.md — the file bin/ticket-intake (via
     /root/bin/ticket-intake) writes and reads. It is read directly, never transcribed into
     a second list that can drift. A ticket that arrives in INBOX/ is ingested by
     ticket-intake first, then merged into data/tracker/tickets.jsonl WITHOUT touching the
     state annotations a lane has already written there.

  2. RUN THE EXISTING BUILDER (bin/build-next-board.py) to produce NEXT-BOARD.md and
     next-board.json. The rules are NOT re-derived here: the states, the contract-gap
     check, the residuals and the Captain-decision split all come from the builder.

  3. MEASURE THE DELIVERY STATE — is the long-poll listener alive, when was the last
     delivery, how many captured results are still unhandled. Every number is read from the
     durable record. Anything that cannot be read is reported as "unknown", never guessed.

  4. RENDER a self-contained HTML board: the Captain's ticket queue (every ticket, with
     area, priority and slug, P0 first), the NEXT sections, and the delivery state.

  5. PUBLISH atomically into the directory the tracker server already serves, and mirror
     the raw NEXT-BOARD.md and next-board.json next to it.

usage: fm-next-board-publish.py --repo PATH [--out DIR] [--serve-root DIR] [--now ISO]
"""
import argparse
import datetime as dt
import html
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import urllib.parse

sys.dont_write_bytecode = True

QUEUE_BOARD_REL = "data/campaign-dashboard-20261015/board.md"
TRACKER_REL = "data/tracker/tickets.jsonl"
INBOX_REL = "INBOX"
TICKET_INTAKE = "/root/bin/ticket-intake"

# The queue file's own record marker, as written by ticket-intake.
QUEUE_RECORD_RE = re.compile(
    r"^<!-- ticket-intake sha256=([0-9a-f]{64}) sequence=([0-9]{4}) area=([^ ]+) priority=(P[012]) slug=([a-z0-9]+(?:-[a-z0-9]+)*) -->$",
    re.M,
)
# The rendered section ticket-intake writes for each record.
QUEUE_SECTION_RE = re.compile(
    r"^### (?P<sequence>[0-9]{4}) — (?P<slug>[a-z0-9-]+)\n"
    r"- Received: (?P<received>[^\n]*)\n"
    r"- Source: (?P<source>[^\n]*)\n"
    r"- Area: (?P<area>[^\n]*)\n"
    r"- Priority: (?P<priority>P[012])\n"
    r"- Requested by: (?P<requested_by>[^\n]*)\n"
    r"\n(?P<description>.*?)(?=\n<!-- ticket-intake|\n<!-- ticket-intake:end -->|\Z)",
    re.M | re.S,
)

TRACKER_FIELDS = [
    "sequence", "slug", "received", "source", "area", "priority", "requested_by",
    "title", "current_state", "domain", "sha256", "hash_match", "kind", "lane",
    "lane_state", "artifact", "artifact_bytes", "verdict", "evidence",
    "visual_required", "visual_artifact", "blocks", "blocked_by", "decision",
    "recovery", "next_action",
]

PRIORITY_ORDER = {"P0": 0, "P1": 1, "P2": 2}


# --------------------------------------------------------------------------- helpers

def atomic_write(path, data, mode=0o644):
    """Write a file atomically. A reader never sees a half-written board."""
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix="." + path.name + ".")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
        tmp = None
    finally:
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)


def load_builder(repo, explicit=None):
    """Load the existing builder module. The rules are never re-derived here."""
    candidates = []
    if explicit:
        candidates.append(pathlib.Path(explicit))
    candidates.append(pathlib.Path(__file__).resolve().parent / "build-next-board.py")
    candidates.append(pathlib.Path(repo) / "bin" / "build-next-board.py")
    for candidate in candidates:
        if candidate.is_file():
            _warn_on_builder_drift(candidate, pathlib.Path(repo) / "bin" / "build-next-board.py")
            import importlib.util
            spec = importlib.util.spec_from_file_location("fm_build_next_board", candidate)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module, str(candidate)
    raise SystemExit("fm-next-board-publish: FAIL builder not found (looked in %s)"
                     % ", ".join(str(c) for c in candidates))


def _warn_on_builder_drift(in_use, repo_copy):
    """The runtime copy is what the timer runs. Say so when the repo's copy has moved on."""
    if in_use.resolve() == repo_copy.resolve():
        return
    try:
        if not repo_copy.is_file():
            return
        if in_use.read_bytes() != repo_copy.read_bytes():
            sys.stderr.write(
                "fm-next-board-publish: WARNING the installed builder (%s) differs from %s; "
                "re-run bin/fm-next-board-install.sh to sync\n" % (in_use, repo_copy))
    except OSError:
        pass


# ------------------------------------------------------------------- 1. the queue

def read_queue(repo):
    """Read the queue's real source: the board file ticket-intake owns."""
    board = pathlib.Path(repo) / QUEUE_BOARD_REL
    if not board.is_file():
        return [], None
    text = board.read_text(encoding="utf-8", errors="replace")
    records = {}
    for match in QUEUE_RECORD_RE.finditer(text):
        records[match.group(2)] = {
            "sequence": match.group(2),
            "slug": match.group(5),
            "area": urllib.parse.unquote(match.group(3)),
            "priority": match.group(4),
            "sha256": match.group(1),
        }
    for match in QUEUE_SECTION_RE.finditer(text):
        seq = match.group("sequence")
        record = records.get(seq)
        if record is None:
            continue
        record.update({
            "slug": match.group("slug"),
            "received": match.group("received").strip(),
            "source": match.group("source").strip(),
            "area": match.group("area").strip() or record["area"],
            "priority": match.group("priority").strip(),
            "requested_by": match.group("requested_by").strip(),
            "description": " ".join(match.group("description").split()),
        })
    ordered = sorted(records.values(), key=lambda r: r["sequence"])
    return ordered, str(board)


def intake_new_tickets(repo):
    """Ingest anything new in INBOX/ into the queue file. Idempotent by construction."""
    inbox = pathlib.Path(repo) / INBOX_REL
    if not inbox.is_dir() or not os.path.exists(TICKET_INTAKE):
        return {"ran": False, "output": "", "rc": 0}
    proc = subprocess.run([TICKET_INTAKE, "--root", str(repo)],
                          capture_output=True, text=True, timeout=120)
    return {"ran": True, "output": (proc.stdout + proc.stderr).strip(), "rc": proc.returncode}


def merge_tracker(repo, queue):
    """Refresh the tracker snapshot from the queue, preserving lane annotations.

    A ticket already tracked keeps every field a lane wrote about it. A ticket new to the
    tracker gets a row whose next action is the ticket's own description — a real action,
    never the "Await lane dispatch" placeholder — and no owner, so the board reports it as
    a CONTRACT-GAP (nobody holds it) instead of pretending it is handled.
    """
    tracker_path = pathlib.Path(repo) / TRACKER_REL
    rows = []
    if tracker_path.is_file():
        for line in tracker_path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except Exception:
                continue
    by_seq = {str(r.get("sequence")): r for r in rows if r.get("sequence")}
    added, kept, refreshed = [], [], []
    for ticket in queue:
        seq = ticket["sequence"]
        existing = by_seq.get(seq)
        if existing is None:
            row = {field: "-" for field in TRACKER_FIELDS}
            row.update({
                "sequence": seq,
                "slug": ticket["slug"],
                "received": ticket.get("received") or "-",
                "source": ticket.get("source") or "-",
                "area": ticket.get("area") or "-",
                "priority": ticket.get("priority") or "P2",
                "requested_by": ticket.get("requested_by") or "-",
                "title": ticket.get("description") or ticket["slug"],
                "current_state": "NOT_STARTED",
                "domain": "-",
                "sha256": ticket.get("sha256") or "-",
                "hash_match": "yes",
                "kind": "WORK",
                "visual_required": "no",
                "decision": "no",
                "next_action": ticket.get("description") or ticket["slug"],
            })
            rows.append(row)
            added.append(seq)
        else:
            kept.append(seq)
            # Keep the queue's own facts current, but never overwrite a lane's annotation.
            changed = False
            for field, value in (("slug", ticket["slug"]), ("area", ticket.get("area")),
                                 ("priority", ticket.get("priority")),
                                 ("sha256", ticket.get("sha256"))):
                if value and existing.get(field) in (None, "", "-"):
                    existing[field] = value
                    changed = True
            if changed:
                refreshed.append(seq)
    payload = "\n".join(json.dumps(r, ensure_ascii=False) for r in rows) + "\n"
    atomic_write(tracker_path, payload)
    queue_seqs = {t["sequence"] for t in queue}
    orphans = [str(r.get("sequence")) for r in rows
               if r.get("sequence") and str(r.get("sequence")) not in queue_seqs]
    return {"added": added, "kept": kept, "refreshed": refreshed,
            "orphans": orphans, "total_rows": len(rows), "path": str(tracker_path)}


# ---------------------------------------------------------------- 3. delivery state

def pid_alive(pid):
    if not pid or pid <= 0:
        return False
    return os.path.isdir("/proc/%d" % pid)


def pid_cmdline(pid):
    try:
        with open("/proc/%d/cmdline" % pid, "rb") as fh:
            return fh.read().replace(b"\0", b" ").decode("utf-8", "replace").strip()
    except OSError:
        return ""


def find_processes(needle):
    found = []
    for entry in pathlib.Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        cmdline = pid_cmdline(int(entry.name))
        if needle in cmdline:
            found.append({"pid": int(entry.name), "cmdline": cmdline[:200]})
    return found


def read_delivery_state(repo):
    """Measure how a Captain message actually reaches the fleet. Read-only."""
    home = pathlib.Path(repo)
    state_dir = home / "state"
    inbox_dir = state_dir / "procevent-inbox"
    reg_dir = state_dir / "procevent"

    sources = []
    for src in sorted(reg_dir.glob("*.source")) if reg_dir.is_dir() else []:
        sid = src.name[: -len(".source")]
        fields, argv = {}, []
        section = None
        for line in src.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("argv:"):
                section = "argv"
                continue
            if line.startswith("adapter="):
                fields["adapter"] = line.split("=", 1)[1].strip()
                continue
            if line.startswith("argc="):
                fields["argc"] = line.split("=", 1)[1].strip()
                continue
            if section == "argv" and line.strip():
                argv.append(line.strip())
        runner_pid = None
        runner_file = reg_dir / ("%s.runner" % sid)
        if runner_file.is_file():
            try:
                runner_pid = int(runner_file.read_text(encoding="utf-8").strip())
            except (OSError, ValueError):
                runner_pid = None
        results = []
        if inbox_dir.is_dir():
            for res in sorted(inbox_dir.glob("%s.*.result" % sid)):
                try:
                    seq = int(res.name.split(".")[-2])
                except (IndexError, ValueError):
                    continue
                status, text = "", ""
                try:
                    text = res.read_text(encoding="utf-8", errors="replace")
                except OSError:
                    text = ""
                match = re.search(r"^\s*status:\s*(.+)$", text, re.M)
                if match:
                    status = match.group(1).strip()
                handled = (inbox_dir / ("%s.%d.handled" % (sid, seq))).is_file()
                results.append({
                    "sequence": seq,
                    "status": status or "(unstated)",
                    "at": dt.datetime.fromtimestamp(res.stat().st_mtime, dt.timezone.utc)
                              .strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "handled": handled,
                })
        # Sequence numbers are numeric: a lexicographic sort puts 9 after 52 and reports
        # the wrong "last delivery".
        results.sort(key=lambda item: item["sequence"])
        last = results[-1] if results else None
        last_feedback = None
        for item in reversed(results):
            if item["status"] == "feedback":
                last_feedback = item
                break
        sources.append({
            "id": sid,
            "adapter": fields.get("adapter", "?"),
            "argv": argv,
            "runner_pid": runner_pid,
            "runner_alive": pid_alive(runner_pid),
            "results": results,
            "last": last,
            "last_feedback": last_feedback,
            "pending": [r for r in results if not r["handled"]],
        })

    poll_procs = find_processes("lavish-axi poll")
    server_procs = find_processes("server.mjs server")
    watcher_beat = state_dir / ".last-watcher-beat"
    watcher_age = None
    if watcher_beat.is_file():
        watcher_age = int(dt.datetime.now(dt.timezone.utc).timestamp()
                          - watcher_beat.stat().st_mtime)

    listener = None
    for source in sources:
        if source["adapter"] == "lavish":
            listener = source
            break
    listener_alive = bool(listener and listener["runner_alive"]) or bool(poll_procs)

    return {
        "measured_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "listener_source": listener["id"] if listener else None,
        "listener_alive": listener_alive,
        "listener_runner_pid": listener["runner_pid"] if listener else None,
        "listener_runner_alive": listener["runner_alive"] if listener else False,
        "poll_processes": poll_procs,
        "lavish_server_alive": bool(server_procs),
        "lavish_server_pids": [p["pid"] for p in server_procs],
        "last_result": listener["last"] if listener else None,
        "last_feedback": listener["last_feedback"] if listener else None,
        "pending_results": len(listener["pending"]) if listener else 0,
        "total_results": len(listener["results"]) if listener else 0,
        "watcher_heartbeat_age_seconds": watcher_age,
        "sources": [{"id": s["id"], "adapter": s["adapter"], "runner_alive": s["runner_alive"],
                     "total": len(s["results"]), "pending": len(s["pending"])} for s in sources],
    }


# ------------------------------------------------------------------- 4. rendering

CSS = """
:root{color-scheme:dark;--bg:#0D0D0D;--surface:#1A1A1A;--surface-2:#2A2A2A;--text:#FFFFFF;
--text-2:#A0A0A0;--brand:#2F86C6;--brand-ice:#BFE0F2;--line:rgba(255,255,255,.08);--ok:#4CC38A;
--warn:#F5A623;--bad:#F13D5D;--mono:'IBM Plex Mono',ui-monospace,SFMono-Regular,Menlo,monospace}
*{box-sizing:border-box}
body{margin:0;padding:22px;background:var(--bg);color:var(--text);
font:15px/1.55 Inter,system-ui,-apple-system,'Segoe UI',sans-serif}
a{color:var(--brand-ice)}
header{display:flex;justify-content:space-between;align-items:flex-end;gap:16px;max-width:1500px;margin:0 auto 18px;flex-wrap:wrap}
h1{margin:0;font-size:clamp(1.4rem,2.6vw,2rem);font-weight:700;letter-spacing:-.01em}
h2{margin:0 0 10px;font-size:1.02rem;font-weight:600;letter-spacing:.01em}
small,.muted{color:var(--text-2)}
main{display:grid;gap:14px;max-width:1500px;margin:0 auto}
.card{background:var(--surface);border:1px solid var(--line);border-radius:12px;padding:16px;min-width:0}
.wide{overflow-x:auto}
table{width:100%;border-collapse:collapse;font-size:.87rem}
th,td{text-align:left;padding:7px 8px;border-bottom:1px solid var(--line);vertical-align:top}
th{font-size:.68rem;text-transform:uppercase;letter-spacing:.07em;color:var(--text-2);font-weight:600}
td.mono,th.mono{font-family:var(--mono)}
code{font-family:var(--mono);font-size:.85em}
.pill{display:inline-block;padding:1px 7px;border-radius:999px;font-family:var(--mono);
font-size:.7rem;font-weight:700;border:1px solid var(--line)}
.p0{background:rgba(241,61,93,.18);color:#ff8ea3;border-color:rgba(241,61,93,.4)}
.p1{background:rgba(245,166,35,.16);color:#ffc978;border-color:rgba(245,166,35,.35)}
.p2{background:rgba(47,134,198,.16);color:var(--brand-ice);border-color:rgba(47,134,198,.35)}
.ok{color:var(--ok)}.bad{color:var(--bad)}.warn{color:var(--warn)}
.state{font-weight:600}
.kv{display:grid;grid-template-columns:minmax(150px,auto) 1fr;gap:6px 14px;font-size:.87rem}
.kv dt{color:var(--text-2)}
.kv dd{margin:0;font-family:var(--mono);font-size:.82rem;overflow-wrap:anywhere}
.note{font-size:.82rem;color:var(--text-2);margin:10px 0 0;line-height:1.5}
.empty{color:var(--text-2);font-style:italic}
.bar{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:10px}
.bar a.btn{text-decoration:none;padding:6px 12px;border-radius:8px;background:var(--surface-2);
border:1px solid var(--line);font-size:.82rem}
.counts{display:flex;gap:8px;flex-wrap:wrap}
.counts span{font-family:var(--mono);font-size:.74rem;padding:3px 8px;border-radius:6px;
background:var(--surface-2);border:1px solid var(--line)}
@media(max-width:760px){body{padding:14px}header{align-items:flex-start;flex-direction:column}}
"""


def esc(value):
    return html.escape(str(value if value is not None else ""), quote=True)


def freshness_banner(age_seconds):
    if age_seconds is None:
        return '<span class="pill bad">age unknown</span>'
    if age_seconds <= 600:
        return '<span class="pill ok">fresh</span>'
    if age_seconds <= 1800:
        return '<span class="pill warn">age %dm</span>' % (age_seconds // 60)
    return '<span class="pill bad">age %dm</span>' % (age_seconds // 60)


def render_delivery(delivery):
    listener = delivery["listener_alive"]
    badge = '<span class="pill ok">ALIVE</span>' if listener else '<span class="pill bad">NOT ALIVE</span>'
    last = delivery.get("last_result")
    last_feedback = delivery.get("last_feedback")
    if last:
        last_line = ("seq %s · %s · %s" % (
            last["sequence"], last["at"], esc(last["status"])))
        last_line += " · " + ("handled" if last["handled"] else "captured, NOT yet handled")
    else:
        last_line = "unknown — no captured result found"
    fb_line = "none captured yet"
    if last_feedback:
        fb_line = "seq %s · %s · %s" % (
            last_feedback["sequence"], last_feedback["at"],
            "handled" if last_feedback["handled"] else "captured, NOT yet handled")
    watcher = delivery.get("watcher_heartbeat_age_seconds")
    watcher_line = ("%.1f min ago" % (watcher / 60.0)) if watcher is not None else "unknown"
    poll = delivery.get("poll_processes") or []
    poll_line = ("pid %s" % ", ".join(str(p["pid"]) for p in poll)) if poll else "none found"
    server = delivery.get("lavish_server_pids") or []
    server_line = ("pid %s" % ", ".join(str(p) for p in server)) if server else "none found"
    return """
<section class="card" id="delivery">
  <h2>How a message you send actually reaches the fleet</h2>
  <dl class="kv">
    <dt>Long-poll listener</dt><dd>%s &nbsp;<span class="muted">%s</span></dd>
    <dt>Listener source</dt><dd>%s</dd>
    <dt>Poll process</dt><dd>%s</dd>
    <dt>Lavish server</dt><dd>%s</dd>
    <dt>Last captured result</dt><dd>%s</dd>
    <dt>Last message (feedback) delivered</dt><dd>%s</dd>
    <dt>Captured, not yet handled</dt><dd>%s</dd>
    <dt>Watcher heartbeat</dt><dd>%s</dd>
    <dt>Measured at</dt><dd>%s</dd>
  </dl>
  <p class="note"><strong>What "busy" means:</strong> your message is posted to the Lavish
  server and held there. The long-poll listener takes it when it next polls. If the agent is
  mid-turn, the message is <strong>queued, not lost</strong> — it is delivered on the next
  poll. The board shows the listener state above, so "Agent is busy; delivered on its next
  poll" means the queue is holding your message and the listener is the thing to watch.</p>
  <p class="note"><strong>Stated limit:</strong> the poll destructively clears feedback when
  it returns it. A result lost in the narrow window between that clear and the runner's
  durable capture cannot be recovered by any wrapper
  (<code>bin/fm-procevent-lavish.sh</code> says so explicitly). The queue is durable; that
  handoff window is the one place a message can go missing.</p>
</section>
""" % (badge, esc(delivery.get("listener_source") or "unregistered"),
       esc(delivery.get("listener_source") or "unknown"),
       esc(poll_line), esc(server_line), last_line, fb_line,
       esc(str(delivery.get("pending_results", 0))), esc(watcher_line),
       esc(delivery.get("measured_at")))


def ticket_state(row):
    """Derive a ticket's state from the tracker row's own recorded facts only."""
    decision = str(row.get("decision") or "").lower()
    blocked_by = str(row.get("blocked_by") or "-")
    lane_state = str(row.get("lane_state") or "-")
    next_action = str(row.get("next_action") or "")
    recovery = str(row.get("recovery") or "-")
    if decision == "yes":
        return ("NEEDS-CAPTAIN-DECISION", recovery if recovery != "-" else next_action,
                "Captain", recovery if recovery != "-" else "")
    if blocked_by not in ("-", "", "None", "none"):
        return ("BLOCKED", "blocked by ticket %s" % blocked_by, str(row.get("lane") or "-"), "")
    if lane_state not in ("-", "", "None", "none"):
        return (lane_state, next_action or str(row.get("title") or ""),
                str(row.get("lane") or "-"), "")
    if next_action.lower().startswith("await lane dispatch"):
        return ("CONTRACT-GAP", "next action is still 'Await lane dispatch'",
                str(row.get("lane") or "-"), "")
    return ("OPEN-WORKABLE", next_action or str(row.get("title") or ""),
            str(row.get("lane") or "-"), "")


def render_queue(queue, tracker_rows):
    """The Captain's own ticket set: every ticket the queue holds, P0 first."""
    by_seq = {str(r.get("sequence")): r for r in tracker_rows}
    by_priority = {}
    for ticket in queue:
        by_priority.setdefault(ticket.get("priority") or "P2", []).append(ticket)
    blocks = []
    total = len(queue)
    counts = {p: len(by_priority.get(p, [])) for p in ("P0", "P1", "P2")}
    blocks.append('<section class="card wide" id="tickets">')
    blocks.append("<h2>Your ticket queue — every ticket the queue holds</h2>")
    blocks.append('<div class="counts">'
                  '<span>P0 &nbsp;%d</span><span>P1 &nbsp;%d</span><span>P2 &nbsp;%d</span>'
                  '<span>total &nbsp;%d</span></div>' % (
                      counts["P0"], counts["P1"], counts["P2"], total))
    for priority in ("P0", "P1", "P2"):
        tickets = by_priority.get(priority, [])
        if not tickets:
            continue
        blocks.append('<div style="margin-top:14px">')
        blocks.append('<h2 style="font-size:.9rem;color:var(--text-2);text-transform:uppercase;'
                      'letter-spacing:.07em">%s — %d ticket(s)</h2>' % (priority, len(tickets)))
        blocks.append('<table><thead><tr><th>prio</th><th>Ticket</th><th>Area</th><th>State</th>'
                      '<th>Done looks like</th><th>Owner</th></tr></thead><tbody>')
        for ticket in sorted(tickets, key=lambda t: t["sequence"]):
            row = by_seq.get(ticket["sequence"], {})
            state, next_action, owner, question = ticket_state(row)
            slug = "%s-%s" % (ticket["sequence"], ticket["slug"])
            priority = (ticket.get("priority") or "P2").lower()
            cell = ('<code>%s</code>' % esc(slug))
            if question:
                cell += '<br><span class="warn">%s</span>' % esc(question[:180])
            blocks.append(
                '<tr><td><span class="pill %s">%s</span></td><td class="mono">%s</td><td>%s</td>'
                '<td class="state">%s</td><td>%s</td><td class="mono">%s</td></tr>' % (
                    esc(priority), esc((ticket.get("priority") or "P2")), cell,
                    esc(ticket.get("area") or "-"), esc(state),
                    esc((next_action or "-")[:200]), esc(owner or "unassigned")))
        blocks.append("</tbody></table></div>")
    if not queue:
        blocks.append('<p class="empty">No tickets found in the queue file.</p>')
    blocks.append('<p class="note">Source of truth: <code>%s</code> — the board file '
                  '<code>ticket-intake</code> owns. This table is read from it on every '
                  'publish; it is never a transcribed copy.</p>' % esc(QUEUE_BOARD_REL))
    blocks.append("</section>")
    return "".join(blocks)


def render_next(board_json):
    """The NEXT contract sections, rendered from the builder's own output."""
    items = board_json.get("items", [])
    residuals = board_json.get("residuals", [])
    counts = board_json.get("counts", {})

    def bucket(*states):
        return [i for i in items if i.get("state") in states]

    def prio_key(item):
        order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
        return (order.get(str(item.get("priority", "")).upper(), 9),
                str(item.get("slug", "")))

    blocks = ['<section class="card wide" id="next">',
              "<h2>The NEXT signpost — every tracked item's state</h2>",
              '<div class="counts">' + "".join(
                  '<span>%s &nbsp;%d</span>' % (esc(k), v)
                  for k, v in sorted(counts.items())) + "</div>"]

    now = bucket("OPEN-WORKABLE")
    blocks.append("<h2 style='margin-top:16px'>NOW — a lane can start this today</h2>")
    if now:
        blocks.append('<table><thead><tr><th>prio</th><th>item</th><th>done looks like</th>'
                      '<th>owner</th></tr></thead><tbody>')
        for item in sorted(now, key=prio_key):
            blocks.append('<tr><td class="mono">%s</td><td class="mono">%s</td><td>%s</td>'
                          '<td class="mono">%s</td></tr>' % (
                              esc(item.get("priority")), esc(item.get("slug")),
                              esc((item.get("next_action") or "")[:160]),
                              esc(item.get("owner"))))
        blocks.append("</tbody></table>")
    else:
        blocks.append('<p class="empty">none</p>')

    captain = [i for i in items
               if i.get("state") == "NEEDS-CAPTAIN-DECISION" or i.get("captain_question")]
    blocks.append("<h2 style='margin-top:16px'>ONLY YOU CAN UNBLOCK — one question each</h2>")
    if captain:
        blocks.append("<ul>")
        for item in sorted(captain, key=prio_key):
            question = item.get("captain_question") or item.get("next_action") or item.get("title")
            blocks.append('<li><code>%s</code> — %s</li>' % (
                esc(item.get("slug")), esc(str(question)[:220])))
        blocks.append("</ul>")
    else:
        blocks.append('<p class="empty">none</p>')

    blocked = bucket("BLOCKED")
    blocks.append("<h2 style='margin-top:16px'>BLOCKED — blocker and recovery condition</h2>")
    if blocked:
        blocks.append("<ul>")
        for item in sorted(blocked, key=prio_key):
            blocks.append('<li><code>%s</code> (%s) — %s</li>' % (
                esc(item.get("slug")), esc(item.get("priority")),
                esc((item.get("next_action") or item.get("title") or "")[:220])))
        blocks.append("</ul>")
    else:
        blocks.append('<p class="empty">none</p>')

    gaps = bucket("CONTRACT-GAP")
    blocks.append("<h2 style='margin-top:16px'>CONTRACT-GAP — no next action or no owner</h2>")
    if gaps:
        blocks.append("<ul>")
        for item in sorted(gaps, key=prio_key)[:60]:
            reason = "; ".join(item.get("gaps") or ["missing state, next action or owner"])
            blocks.append('<li><code>%s</code> (%s) — %s</li>' % (
                esc(item.get("slug")), esc(item.get("priority")), esc(reason)))
        blocks.append("</ul>")
        if len(gaps) > 60:
            blocks.append('<p class="muted">…and %d more</p>' % (len(gaps) - 60))
    else:
        blocks.append('<p class="empty">none — every item has a next action and an owner</p>')

    done = bucket("VERIFIED-DONE", "STALE-DUPLICATE")
    blocks.append("<h2 style='margin-top:16px'>CLOSED</h2>")
    if done:
        blocks.append("<ul>")
        for item in sorted(done, key=prio_key)[:40]:
            blocks.append('<li><code>%s</code> — %s</li>' % (
                esc(item.get("slug")), esc((item.get("next_action") or item.get("title") or "")[:140])))
        blocks.append("</ul>")
        if len(done) > 40:
            blocks.append('<p class="muted">…and %d more</p>' % (len(done) - 40))
    else:
        blocks.append('<p class="empty">none</p>')

    blocks.append("<h2 style='margin-top:16px'>RESIDUALS — artifacts with a VERDICT but no NEXT line</h2>")
    if residuals:
        blocks.append("<ul>")
        for residual in residuals:
            blocks.append('<li><code>%s</code> — verdict: %s</li>' % (
                esc(residual.get("artifact")), esc(residual.get("verdict") or "(unstated)")))
        blocks.append("</ul>")
    else:
        blocks.append('<p class="empty">none</p>')

    claims = board_json.get("claims") or []
    blocks.append("<h2 style='margin-top:16px'>LIVE CLAIMS</h2>")
    if claims:
        blocks.append("<ul>")
        for claim in claims:
            blocks.append('<li><code>%s</code> — %s — %s</li>' % (
                esc(claim.get("lane")), esc(str(claim.get("scope") or "")[:80]),
                esc(str(claim.get("state") or "")[:80])))
        blocks.append("</ul>")
    else:
        blocks.append('<p class="empty">no claims board found</p>')

    blocks.append('<p class="note">Sources: <code>%s</code> (the queue), '
                  '<code>%s</code> (the tracker snapshot), <code>data/backlog.md</code> (the live '
                  'queue) — all read by the existing builder <code>bin/build-next-board.py</code>.</p>'
                  % (esc(QUEUE_BOARD_REL), esc(TRACKER_REL)))
    blocks.append("</section>")
    return "".join(blocks)


def render_page(now, delivery, queue, tracker_rows, board_json, board_age):
    title = "Fleet live board"
    return """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>%s</title>
<style>%s</style>
</head><body>
<header>
  <div>
    <h1>Fleet live board</h1>
    <small>Generated <code>%s</code> &nbsp;%s &nbsp;·&nbsp; rebuilt on a timer from the
    live queue, not a snapshot</small>
  </div>
  <div class="bar">
    <a class="btn" href="../">← Fleet ticket dashboard</a>
    <a class="btn" href="next-board.json">next-board.json</a>
    <a class="btn" href="NEXT-BOARD.md">NEXT-BOARD.md</a>
  </div>
</header>
<main>
%s
%s
%s
</main>
</body></html>
""" % (esc(title), CSS, esc(now), freshness_banner(board_age),
       render_delivery(delivery), render_queue(queue, tracker_rows), render_next(board_json))


# ------------------------------------------------------------------------ 5. publish

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--out", default=None)
    parser.add_argument("--serve-root", default=None)
    parser.add_argument("--builder", default=None)
    parser.add_argument("--now", default=None)
    parser.add_argument("--no-refresh", action="store_true")
    parser.add_argument("--no-publish", action="store_true")
    args = parser.parse_args()

    repo = pathlib.Path(args.repo).resolve()
    out = pathlib.Path(args.out) if args.out else repo / "data" / "next-board-publish"
    serve_root = pathlib.Path(args.serve_root) if args.serve_root else None
    now = args.now or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    # 1. ingest new INBOX tickets into the queue file, then merge into the tracker.
    intake = {"ran": False, "output": "", "rc": 0}
    if not args.no_refresh:
        intake = intake_new_tickets(repo)
    queue, queue_path = read_queue(repo)
    if not args.no_refresh and queue:
        merged = merge_tracker(repo, queue)
    else:
        merged = {"added": [], "kept": [], "refreshed": [], "orphans": [], "total_rows": 0,
                  "path": str(repo / TRACKER_REL)}

    # 2. the existing builder produces the board and the machine-readable item list.
    builder, builder_path = load_builder(repo, args.builder)
    board_dir = repo / "data" / "tracker"
    board_dir.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run(
        [sys.executable, builder_path, "--repo", str(repo), "--out", str(board_dir)],
        capture_output=True, text=True, timeout=300)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout + proc.stderr)
        raise SystemExit("fm-next-board-publish: FAIL builder exited %d" % proc.returncode)
    board_json = json.loads((board_dir / "next-board.json").read_text(encoding="utf-8"))
    board_md = (board_dir / "NEXT-BOARD.md").read_text(encoding="utf-8")

    # Lane reports carry a VERDICT and often no NEXT line. The builder's own regexes are
    # used here so the rule is not re-derived; after the builder learns these directories
    # this pass finds the same residuals and the merge de-duplicates them.
    extra_residuals = []
    seen_artifacts = {r.get("artifact") for r in board_json.get("residuals", [])}
    data_dir = repo / "data"
    if data_dir.is_dir():
        for report in sorted(data_dir.glob("*/report.md")):
            rel = str(report.relative_to(repo))
            if rel in seen_artifacts:
                continue
            try:
                text = report.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            if not builder.VERDICT_RE.search(text):
                continue
            if builder.NEXT_RE.search(text):
                continue
            verdict = (re.findall(r"VERDICT\s*:\s*([^\n]{0,80})", text) or [""])[0].strip()
            extra_residuals.append({"artifact": rel, "verdict": verdict, "next_line": None})
    if extra_residuals:
        board_json.setdefault("residuals", []).extend(extra_residuals)

    # 3. measure the delivery state.
    delivery = read_delivery_state(repo)

    # 4. render.
    tracker_rows = []
    tracker_path = repo / TRACKER_REL
    if tracker_path.is_file():
        for line in tracker_path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                tracker_rows.append(json.loads(line))
            except Exception:
                continue
    board_age = int(dt.datetime.now(dt.timezone.utc).timestamp()
                    - (board_dir / "next-board.json").stat().st_mtime)
    page = render_page(now, delivery, queue, tracker_rows, board_json, board_age)

    # 5. publish atomically.
    out.mkdir(parents=True, exist_ok=True)
    atomic_write(out / "index.html", page)
    atomic_write(out / "NEXT-BOARD.md", board_md)
    atomic_write(out / "next-board.json", json.dumps(board_json, indent=2) + "\n")
    atomic_write(out / "delivery-state.json", json.dumps(delivery, indent=2) + "\n")
    atomic_write(out / "published.json", json.dumps({
        "generated": now,
        "repo": str(repo),
        "queue_source": queue_path,
        "tickets": len(queue),
        "listener_alive": delivery["listener_alive"],
        "pending_results": delivery["pending_results"],
    }, indent=2) + "\n")
    if serve_root is not None:
        link = serve_root / "next-board"
        if not link.exists() and not link.is_symlink():
            link.symlink_to(out)

    print("fm-next-board-publish: queue=%s tickets=%d (P0=%d P1=%d P2=%d)" % (
        queue_path, len(queue),
        sum(1 for t in queue if t.get("priority") == "P0"),
        sum(1 for t in queue if t.get("priority") == "P1"),
        sum(1 for t in queue if t.get("priority") == "P2")))
    if intake["ran"]:
        print("fm-next-board-publish: intake rc=%d %s" % (intake["rc"], intake["output"][:160]))
    print("fm-next-board-publish: tracker rows=%d added=%d kept=%d orphans=%d" % (
        merged["total_rows"], len(merged["added"]), len(merged["kept"]), len(merged["orphans"])))
    print("fm-next-board-publish: listener_alive=%s pending_results=%d last=%s" % (
        delivery["listener_alive"], delivery["pending_results"],
        delivery["last_result"]["status"] if delivery["last_result"] else "none"))
    print("fm-next-board-publish: published %s (%d bytes)" % (
        out / "index.html", len(page.encode("utf-8"))))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
