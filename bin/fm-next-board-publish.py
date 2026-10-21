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

On top of that it renders three sections the Captain asked for, each built from a source
this file does not own:

  * the TOKEN BAND - the weekly total, the daily heat map across every account, the live
    quota windows and the rollover timeline - read from the band document the collector
    writes (data/next-board-publish/token-band.json; the shape is owned by
    docs/next-board-token-and-chat-contract.md);
  * the SELECTED NEXT WORK - one ticket from the Captain's own queue, picked by the
    contract's rule (OPEN-WORKABLE only, lowest priority number, oldest received, then
    sequence), and never invented;
  * the CHAT CARD - the Lavish session link when there is one, the form that posts to
    /next-board/feedback, and the recent conversation.

Every one of the three degrades to a truthful note when its source is missing, stale or
malformed. The publisher runs on a timer and never crashes it.

usage: fm-next-board-publish.py --repo PATH [--out DIR] [--serve-root DIR] [--now ISO]
                                [--band PATH]
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

# The token band and the chat state. The shapes are owned by
# docs/next-board-token-and-chat-contract.md; this file only renders them.
BAND_REL = "data/next-board-publish/token-band.json"
SESSION_REL = "state/next-board-session.json"
FEEDBACK_REL = "state/next-board-feedback"
# A band older than this is reported as stale rather than shown as current.
BAND_STALE_SECONDS = 3600
# How many conversation entries the chat card shows, newest first.
TALK_ENTRIES_SHOWN = 12
# The Captain's own words for a ticket's acceptance. When a ticket states one, the
# card shows it verbatim; otherwise the card says what closing a ticket means here.
DONE_MARKERS = ("Requirements for whoever picks this up:", "Required actions:",
                "Acceptance criteria:")


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
details.fold{border:1px solid var(--line);border-radius:10px;margin-top:12px;
background:rgba(255,255,255,.015)}
details.fold>summary{cursor:pointer;padding:9px 12px;font-size:.86rem;font-weight:600;
list-style:none;display:flex;gap:8px;align-items:center}
details.fold>summary::-webkit-details-marker{display:none}
details.fold>summary::before{content:"▸";color:var(--text-2);font-size:.78rem;
transition:transform .12s ease}
details.fold[open]>summary::before{transform:rotate(90deg)}
details.fold>summary:hover{color:var(--brand-ice)}
details.fold>.foldbody{padding:2px 12px 12px}
.bar{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:10px}
.bar a.btn{text-decoration:none;padding:6px 12px;border-radius:8px;background:var(--surface-2);
border:1px solid var(--line);font-size:.82rem}
.counts{display:flex;gap:8px;flex-wrap:wrap}
.counts span{font-family:var(--mono);font-size:.74rem;padding:3px 8px;border-radius:6px;
background:var(--surface-2);border:1px solid var(--line)}
.headline{margin:10px 0 4px;font-size:.9rem;color:var(--text-2)}
.headline strong{font-size:1.35rem;font-family:var(--mono);color:var(--text);letter-spacing:-.01em}
table.heat td.cell,table.heat th{text-align:right;white-space:nowrap}
table.heat td.cell.blank{color:var(--text-2)}
table.heat td.cell.unknown{color:var(--warn);font-size:.7rem;letter-spacing:.04em}
table.heat tr.total td{font-weight:600;border-top:1px solid var(--line)}
.meter{display:inline-block;width:64px;height:8px;border-radius:4px;background:var(--surface-2);
border:1px solid var(--line);margin-left:6px;vertical-align:middle;overflow:hidden}
.meter i{display:block;height:100%;background:var(--brand)}
.selhead{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:2px 0 10px}
.selhead code{font-size:1rem}
.talkbar{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-bottom:10px}
.talkform{display:grid;gap:6px;max-width:760px;margin:12px 0}
.talkform label{font-size:.72rem;text-transform:uppercase;letter-spacing:.07em;color:var(--text-2)}
.talkform input,.talkform textarea{background:var(--surface-2);border:1px solid var(--line);
border-radius:8px;color:var(--text);font:inherit;padding:8px 10px;width:100%}
.talkform button{justify-self:start;padding:8px 16px;border-radius:8px;background:var(--brand);
border:1px solid var(--line);color:#fff;font:inherit;font-weight:600;cursor:pointer}
ul.talklog{list-style:none;margin:0;padding:0;display:grid;gap:10px}
ul.talklog li{border:1px solid var(--line);border-radius:10px;padding:10px 12px;background:var(--surface-2)}
.talkhead{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-bottom:6px}
.talkbody{font-size:.87rem;overflow-wrap:anywhere}
@media(max-width:760px){body{padding:14px}header{align-items:flex-start;flex-direction:column}}
"""


def esc(value):
    return html.escape(str(value if value is not None else ""), quote=True)


def fold(summary, body, open_=False):
    """A collapsed disclosure block.

    The board is a working surface, not an archive. Long lists (closed work, contract
    gaps, residual artifacts) stay on the page - the Captain's data is never dropped -
    but they fold away by default so the page opens on the signposts instead of a wall
    of rows. The summary always carries the count, so a folded block never hides that
    something is behind it.
    """
    if not body:
        return ""
    return ('<details class="fold"%s><summary>%s</summary>'
            '<div class="foldbody">%s</div></details>'
            % (" open" if open_ else "", summary, body))


def data_rows(table_html):
    """How many data rows a rendered table holds, ignoring its header row."""
    if not table_html:
        return 0
    return max(0, table_html.count("<tr>") - 1)


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


def render_queue(queue, tracker_rows, known_items=None):
    """The Captain's own ticket set: every ticket the queue holds, P0 first.

    Every ticket is still rendered - the queue is never truncated - but only P0 is
    expanded. P1 and P2 fold away behind a count, so the page opens on what is on
    fire rather than on forty rows of context.

    The queue and the NEXT card must agree about the same ticket. A ticket's own
    tracker row wins whenever it carries a real annotation. When that row is still
    the "Await lane dispatch" placeholder, the board's own verified state for the
    same slug is used instead - otherwise the queue reports CONTRACT-GAP about work
    the NEXT card has already proved done, which is the board disagreeing with
    itself.
    """
    known = {}
    for item in (known_items or []):
        slug = item.get("slug")
        if slug:
            known[slug] = item
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
        rows = []
        for ticket in sorted(tickets, key=lambda t: t["sequence"]):
            row = by_seq.get(ticket["sequence"], {})
            state, next_action, owner, question = ticket_state(row)
            slug = "%s-%s" % (ticket["sequence"], ticket["slug"])
            # The board's own verified state for this ticket, when the ticket's own
            # tracker row has not caught up.
            #
            # A tracker row that carries a lane's own annotation - a lane_state, an
            # artifact, a verdict or evidence - is the ticket's authoritative record
            # and wins. A row that is still the intake scaffolding has nothing to
            # say: its next_action is the literal "Await lane dispatch" placeholder,
            # its blocked_by may name a blocker that was resolved weeks ago, and its
            # decision may predate the work. The board's evidence-backed state for
            # that slug is used instead - that state carries a command and its
            # result, which is what the protocol requires before an item moves.
            item = known.get(row.get("slug") or ticket["slug"])
            row_is_scaffolding = all(
                not row.get(field) or row.get(field) in ("-", "None", "")
                for field in ("lane_state", "artifact", "verdict", "evidence"))
            placeholder_next = (not next_action) \
                or next_action.lower().startswith("await lane dispatch")
            if item and (row_is_scaffolding or state == "CONTRACT-GAP" or placeholder_next):
                if row_is_scaffolding:
                    # The row has nothing to say at all, so the evidence-backed state
                    # replaces it outright - including a BLOCKED-by-a-stale-dependency
                    # or a NEEDS-CAPTAIN-DECISION recorded before the work happened.
                    if item.get("state"):
                        state = item["state"]
                elif state == "CONTRACT-GAP" and item.get("state") \
                        and item.get("state") != "CONTRACT-GAP":
                    state = item["state"]
                if item.get("next_action"):
                    next_action = item["next_action"]
                if item.get("owner") and item.get("owner") not in ("-", "None", ""):
                    owner = item["owner"]
                if item.get("captain_question"):
                    question = item["captain_question"]
            pill = (ticket.get("priority") or "P2").lower()
            cell = ('<code>%s</code>' % esc(slug))
            if question:
                cell += '<br><span class="warn">%s</span>' % esc(truncate(question, 150))
            rows.append(
                '<tr><td><span class="pill %s">%s</span></td><td class="mono">%s</td><td>%s</td>'
                '<td class="state">%s</td><td>%s</td><td class="mono">%s</td></tr>' % (
                    esc(pill), esc(ticket.get("priority") or "P2"), cell,
                    esc(ticket.get("area") or "-"), esc(state),
                    esc(truncate(next_action or "-", 110)), esc(owner or "unassigned")))
        table = ('<table><thead><tr><th>prio</th><th>Ticket</th><th>Area</th><th>State</th>'
                 '<th>Done looks like</th><th>Owner</th></tr></thead><tbody>'
                 + "".join(rows) + "</tbody></table>")
        heading = ("%s — %d ticket(s)" % (priority, len(tickets)))
        if priority == "P0":
            blocks.append('<div style="margin-top:14px">')
            blocks.append('<h2 style="font-size:.9rem;color:var(--text-2);text-transform:uppercase;'
                          'letter-spacing:.07em">%s</h2>' % heading)
            blocks.append(table)
            blocks.append("</div>")
        else:
            blocks.append(fold(heading, table))
    if not queue:
        blocks.append('<p class="empty">No tickets found in the queue file.</p>')
    blocks.append('<p class="note">Source of truth: <code>%s</code> — the board file '
                  '<code>ticket-intake</code> owns. This table is read from it on every '
                  'publish; it is never a transcribed copy. P1 and P2 are folded — open them '
                  'to read the full list.</p>' % esc(QUEUE_BOARD_REL))
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

    # How many rows stay open on the page. The signposts (NOW, the Captain's own
    # questions, BLOCKED) stay open because they are what the page is for. The
    # long tail (contract gaps, closed work, residual artifacts) folds behind a count,
    # and every count is shown so nothing is silently dropped.
    OPEN_NOW = 8
    OPEN_CAPTAIN = 6

    now = bucket("OPEN-WORKABLE")
    blocks.append("<h2 style='margin-top:16px'>NOW — a lane can start this today "
                  "<span class='muted'>(%d item(s))</span></h2>" % len(now))
    if now:
        def now_row(item):
            return ('<tr><td class="mono">%s</td><td class="mono">%s</td><td>%s</td>'
                    '<td class="mono">%s</td></tr>' % (
                        esc(item.get("priority")), esc(item.get("slug")),
                        esc(truncate(item.get("next_action") or "", 110)),
                        esc(item.get("owner"))))

        ordered = sorted(now, key=prio_key)
        blocks.append('<table><thead><tr><th>prio</th><th>item</th><th>done looks like</th>'
                      '<th>owner</th></tr></thead><tbody>'
                      + "".join(now_row(i) for i in ordered[:OPEN_NOW]) + "</tbody></table>")
        if len(ordered) > OPEN_NOW:
            rest = ('<table><thead><tr><th>prio</th><th>item</th><th>done looks like</th>'
                    '<th>owner</th></tr></thead><tbody>'
                    + "".join(now_row(i) for i in ordered[OPEN_NOW:]) + "</tbody></table>")
            blocks.append(fold("…and %d more workable item(s)" % (len(ordered) - OPEN_NOW),
                               rest))
    else:
        blocks.append('<p class="empty">none</p>')

    captain = [i for i in items
               if i.get("state") == "NEEDS-CAPTAIN-DECISION" or i.get("captain_question")]
    captain.sort(key=prio_key)
    blocks.append("<h2 style='margin-top:16px'>ONLY YOU CAN UNBLOCK — one question each "
                  "<span class='muted'>(%d question(s))</span></h2>" % len(captain))
    if captain:
        def question_line(item):
            question = item.get("captain_question") or item.get("next_action") or item.get("title")
            return '<li><code>%s</code> — %s</li>' % (esc(item.get("slug")),
                                                      esc(truncate(question, 200)))

        blocks.append("<ul>" + "".join(question_line(i) for i in captain[:OPEN_CAPTAIN])
                      + "</ul>")
        if len(captain) > OPEN_CAPTAIN:
            rest = "<ul>" + "".join(question_line(i) for i in captain[OPEN_CAPTAIN:]) + "</ul>"
            blocks.append(fold("…and %d more question(s) waiting on you"
                               % (len(captain) - OPEN_CAPTAIN), rest))
    else:
        blocks.append('<p class="empty">none</p>')

    blocked = bucket("BLOCKED")
    blocks.append("<h2 style='margin-top:16px'>BLOCKED — blocker and recovery condition "
                  "<span class='muted'>(%d item(s))</span></h2>" % len(blocked))
    if blocked:
        blocks.append("<ul>")
        for item in sorted(blocked, key=prio_key):
            blocks.append('<li><code>%s</code> (%s) — %s</li>' % (
                esc(item.get("slug")), esc(item.get("priority")),
                esc(truncate(item.get("next_action") or item.get("title") or "", 200))))
        blocks.append("</ul>")
    else:
        blocks.append('<p class="empty">none</p>')

    gaps = bucket("CONTRACT-GAP")
    gap_body = ""
    if gaps:
        items_html = []
        for item in sorted(gaps, key=prio_key):
            reason = "; ".join(item.get("gaps") or ["missing state, next action or owner"])
            items_html.append('<li><code>%s</code> (%s) — %s</li>' % (
                esc(item.get("slug")), esc(item.get("priority")), esc(reason)))
        gap_body = "<ul>" + "".join(items_html) + "</ul>"
    else:
        gap_body = '<p class="empty">none — every item has a next action and an owner</p>'
    blocks.append(fold("CONTRACT-GAP — no next action or no owner (%d item(s))" % len(gaps),
                       gap_body))

    done = bucket("VERIFIED-DONE", "STALE-DUPLICATE")
    done_body = ""
    if done:
        items_html = []
        for item in sorted(done, key=prio_key):
            items_html.append('<li><code>%s</code> — %s</li>' % (
                esc(item.get("slug")),
                esc(truncate(item.get("next_action") or item.get("title") or "", 140))))
        done_body = "<ul>" + "".join(items_html) + "</ul>"
    else:
        done_body = '<p class="empty">none</p>'
    blocks.append(fold("CLOSED — finished work (%d item(s))" % len(done), done_body))

    # Residual artifacts: every one is still listed, but the fold keeps 86 rows off the
    # Captain's first screen. Nothing is dropped - the fold opens onto the full
    # register. The verdict is clipped to one line so a long report sentence cannot
    # stretch a row.
    residual_body = ""
    if residuals:
        residual_body = "<ul>" + "".join(
            '<li><code>%s</code> — verdict: %s</li>' % (
                esc(residual.get("artifact")),
                esc(truncate(residual.get("verdict") or "(unstated)", 140)))
            for residual in residuals) + "</ul>"
    else:
        residual_body = '<p class="empty">none</p>'
    blocks.append(fold("RESIDUALS — artifacts with a VERDICT but no NEXT line "
                       "(%d artifact(s))" % len(residuals), residual_body))

    claims = board_json.get("claims") or []
    claim_body = ""
    if claims:
        claim_body = "<ul>" + "".join(
            '<li><code>%s</code> — %s — %s</li>' % (
                esc(claim.get("lane")), esc(truncate(claim.get("scope") or "", 80)),
                esc(truncate(claim.get("state") or "", 80)))
            for claim in claims) + "</ul>"
    else:
        claim_body = '<p class="empty">no claims board found</p>'
    blocks.append(fold("LIVE CLAIMS — who holds what right now (%d)" % len(claims), claim_body))

    blocks.append('<p class="note">Sources: <code>%s</code> (the queue), '
                  '<code>%s</code> (the tracker snapshot), <code>data/backlog.md</code> (the live '
                  'queue) — all read by the existing builder <code>bin/build-next-board.py</code>. '
                  'Folded blocks are collapsed, not removed: open any of them to read it in full.'
                  '</p>' % (esc(QUEUE_BOARD_REL), esc(TRACKER_REL)))
    blocks.append("</section>")
    return "".join(blocks)


# ------------------------------------------------------------------ small helpers

def parse_iso(value):
    """Parse an ISO-8601 instant. A trailing Z is accepted; a naive stamp is UTC."""
    if not value:
        return None
    text = str(value).strip()
    if text.endswith(("Z", "z")):
        text = text[:-1] + "+00:00"
    try:
        parsed = dt.datetime.fromisoformat(text)
    except (TypeError, ValueError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed


def fmt_int(value):
    """A thousands-separated count, or 'unknown'. Never a silent zero."""
    if value is None or isinstance(value, bool):
        return "unknown"
    try:
        return "{:,}".format(int(value))
    except (TypeError, ValueError):
        return "unknown"


def fmt_compact(value):
    """A short form of a token count for a dense cell: 91.3M, 655.3M, 1.20B."""
    if value is None or isinstance(value, bool):
        return "?"
    try:
        number = float(value)
    except (TypeError, ValueError):
        return "?"
    if number >= 1_000_000_000:
        return "%.2fB" % (number / 1_000_000_000)
    if number >= 1_000_000:
        return "%.1fM" % (number / 1_000_000)
    if number >= 1_000:
        return "%.1fk" % (number / 1_000)
    return "%d" % number


def fmt_pct(value):
    """A percentage, or 'unknown' when the source reports none."""
    if value is None or isinstance(value, bool):
        return "unknown"
    try:
        number = float(value)
    except (TypeError, ValueError):
        return "unknown"
    if number == int(number):
        return "%d%%" % int(number)
    return "%.1f%%" % number


def truncate(text, limit):
    """One line, whitespace collapsed, clipped to a length."""
    flat = " ".join(str(text or "").split())
    if len(flat) <= limit:
        return flat
    return flat[:limit].rstrip() + "…"


def clip(text, limit):
    """Clip to a length but keep the line breaks."""
    raw = str(text or "")
    if len(raw) <= limit:
        return raw
    return raw[:limit].rstrip() + "…"


def esc_multiline(text):
    """Escape a multi-line body, then turn its newlines into line breaks."""
    return esc(text).replace("\n", "<br>")


def rel_time(resets_at, seconds=None):
    """How long until a reset, in words. A past reset says so."""
    stamp = parse_iso(resets_at)
    if stamp is None:
        if isinstance(seconds, (int, float)) and not isinstance(seconds, bool):
            return "in %.0f min" % (seconds / 60.0)
        return "unknown"
    delta = (stamp - dt.datetime.now(dt.timezone.utc)).total_seconds()
    if delta < 0:
        return "%.0f min ago" % (abs(delta) / 60.0)
    if delta < 3600:
        return "in %.0f min" % (delta / 60.0)
    if delta < 86400:
        return "in %.1f h" % (delta / 3600.0)
    return "in %.1f d" % (delta / 86400.0)


# ------------------------------------------------------------------ the token band

def resolve_band_path(repo, out, explicit=None):
    """Where the band document lives.

    The collector writes the band into the publish directory, so that directory is
    looked at first when the publisher is pointed somewhere else. Otherwise the
    contract's own path under the repo is used.
    """
    if explicit:
        return pathlib.Path(explicit)
    default_out = pathlib.Path(repo) / "data" / "next-board-publish"
    if out is not None and pathlib.Path(out) != default_out:
        candidate = pathlib.Path(out) / "token-band.json"
        if candidate.is_file():
            return candidate
    return default_out / "token-band.json"


def read_token_band(path):
    """Read the band. Never raises: a bad band is a state the board can report."""
    path = pathlib.Path(path)
    state = {"path": str(path), "state": "missing", "detail": "", "band": None,
             "age_seconds": None, "problems": []}
    if not path.is_file():
        state["detail"] = "no token band document at %s" % path
        return state
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        state["state"] = "unreadable"
        state["detail"] = "cannot read %s: %s" % (path, exc)
        return state
    try:
        band = json.loads(raw)
    except ValueError as exc:
        state["state"] = "malformed"
        state["detail"] = "%s is not valid JSON: %s" % (path, exc)
        return state
    if not isinstance(band, dict):
        state["state"] = "malformed"
        state["detail"] = "%s does not hold a JSON object" % path
        return state
    state["band"] = band
    for problem in band.get("errors") or []:
        state["problems"].append(str(problem))
    quota = band.get("quota") or {}
    if isinstance(quota, dict) and quota.get("ok") is False:
        state["problems"].append("quota unavailable: %s" % (quota.get("error") or "no reason given"))
    ledger = band.get("ledger") or {}
    if isinstance(ledger, dict) and ledger.get("ok") is False:
        state["problems"].append("ledger unavailable: %s" % (ledger.get("error") or "no reason given"))
    stamp = parse_iso(band.get("generated_at"))
    age = None
    if stamp is not None:
        age = (dt.datetime.now(dt.timezone.utc) - stamp).total_seconds()
    else:
        try:
            age = dt.datetime.now(dt.timezone.utc).timestamp() - path.stat().st_mtime
        except OSError:
            age = None
    state["age_seconds"] = age
    if age is None:
        state["state"] = "ok"
        state["detail"] = "the band carries no usable generation time; its age is unknown"
    elif age > BAND_STALE_SECONDS:
        state["state"] = "stale"
        state["detail"] = "the band was generated %s — %.0f min old, over the %d min bound" % (
            band.get("generated_at"), age / 60.0, BAND_STALE_SECONDS // 60)
    else:
        state["state"] = "ok"
    return state


def band_account_ids(band):
    """Every account the band mentions, in a stable order."""
    ids = []
    weekly = band.get("weekly") if isinstance(band.get("weekly"), dict) else {}
    for account in (weekly.get("per_account") or {}):
        if account not in ids:
            ids.append(account)
    for day in band.get("daily") or []:
        if not isinstance(day, dict):
            continue
        for account in (day.get("accounts") or {}):
            if account not in ids:
                ids.append(account)
    return ids


def band_account_labels(band):
    """Account id -> the label the ledger gives it."""
    labels = {}
    ledger = band.get("ledger") if isinstance(band.get("ledger"), dict) else {}
    for account in ledger.get("accounts") or []:
        if isinstance(account, dict) and account.get("id"):
            labels[str(account["id"])] = str(account.get("label") or account["id"])
    return labels


def band_day_columns(band):
    """The day columns of the heat map: the weekly window plus any extra ledger day."""
    weekly = band.get("weekly") if isinstance(band.get("weekly"), dict) else {}
    columns = []

    def add(value):
        text = str(value or "")
        if len(text) == 10 and text not in columns:
            columns.append(text)

    start = weekly.get("start_date")
    end = weekly.get("end_date")
    expected = weekly.get("days_expected")
    if start and end:
        try:
            first = dt.date.fromisoformat(str(start))
            last = dt.date.fromisoformat(str(end))
        except ValueError:
            first = last = None
        if first and last:
            span = (last - first).days + 1
            if isinstance(expected, int) and not isinstance(expected, bool) and expected > 0:
                span = min(span, expected)
            for offset in range(max(span, 0)):
                add((first + dt.timedelta(days=offset)).isoformat())
    for day in band.get("daily") or []:
        if isinstance(day, dict):
            add(day.get("date"))
    columns.sort()
    return columns


def heat_cell(day_row, account):
    """One account-day cell: (value, why). An absent reading is never a zero."""
    if day_row is None:
        return None, "no ledger day for this date"
    if str(day_row.get("total_status") or "") == "unknown":
        return None, "the ledger's total for this day is unknown"
    accounts = day_row.get("accounts") or {}
    if account not in accounts:
        return None, "no reading for this account on this day"
    value = accounts.get(account)
    if value is None:
        return None, "the ledger reports this account as unknown on this day"
    try:
        return int(value), "measured"
    except (TypeError, ValueError):
        return None, "the ledger reports an unreadable value for this account"


def render_heat_map(band):
    """One row per account, one column per day, shaded by magnitude."""
    daily = [d for d in (band.get("daily") or []) if isinstance(d, dict)]
    columns = band_day_columns(band)
    accounts = band_account_ids(band)
    if not columns and not accounts:
        return '<p class="empty">the band carries no daily readings and no accounts</p>'
    by_date = {str(day.get("date")): day for day in daily}
    labels = band_account_labels(band)

    largest = 0
    for date in columns:
        day_row = by_date.get(date)
        for account in accounts:
            value, _why = heat_cell(day_row, account)
            if value is not None and value > largest:
                largest = value

    blocks = ['<table class="heat"><thead><tr><th>account</th>']
    for date in columns:
        day_row = by_date.get(date)
        status = str((day_row or {}).get("total_status") or "")
        if day_row is None:
            marker = '<br><span class="warn">no day</span>'
        elif status == "unknown":
            marker = '<br><span class="warn">unknown</span>'
        elif status == "partial":
            marker = '<br><span class="muted">partial</span>'
        else:
            marker = ""
        blocks.append('<th class="mono" title="%s">%s%s</th>' % (
            esc(date), esc(date[5:]), marker))
    blocks.append('<th class="mono">total</th></tr></thead><tbody>')

    for account in accounts:
        label = labels.get(account, account)
        blocks.append('<tr><td class="mono" title="%s">%s</td>' % (esc(account), esc(label)))
        known_total = 0
        known_days = 0
        for date in columns:
            value, why = heat_cell(by_date.get(date), account)
            if value is None:
                blocks.append('<td class="cell blank" title="%s">&nbsp;</td>' % esc(why))
                continue
            known_total += value
            known_days += 1
            share = (value / largest) if largest else 0.0
            blocks.append('<td class="cell mono" style="background:rgba(47,134,198,%.2f)" '
                          'title="%s tokens on %s">%s</td>' % (
                              0.08 + 0.52 * share, fmt_int(value), esc(date),
                              esc(fmt_compact(value))))
        floor = "≥" if known_days < len(columns) else ""
        blocks.append('<td class="mono">%s%s</td></tr>' % (floor, esc(fmt_compact(known_total))))

    blocks.append('<tr class="total"><td class="mono">day total (ledger)</td>')
    for date in columns:
        day_row = by_date.get(date)
        if day_row is None:
            blocks.append('<td class="cell blank" title="no ledger day for this date">&nbsp;</td>')
            continue
        status = str(day_row.get("total_status") or "")
        value = day_row.get("total_tokens")
        if value is None or status == "unknown":
            blocks.append('<td class="cell mono unknown" '
                          'title="the ledger\'s total for this day is unknown">unknown</td>')
            continue
        prefix = "≥" if status == "partial" else ""
        blocks.append('<td class="cell mono" title="%s tokens on %s">%s%s</td>' % (
            fmt_int(value), esc(date), prefix, esc(fmt_compact(value))))
    blocks.append('<td class="mono"></td></tr>')
    blocks.append("</tbody></table>")
    blocks.append('<p class="note">Scale: the cell shade runs from the lightest at zero to the '
                  'darkest at the largest account-day reading (%s tokens). A blank cell means there '
                  'was no reading for that account on that day — it is not a zero. A day the ledger '
                  'marks unknown is shown as unknown in the day-total row, and its account cells stay '
                  'blank. A total with a ≥ is a floor: some days carried no reading.</p>' % esc(fmt_int(largest)))
    return "".join(blocks)


def render_quota_windows(band):
    """The live quota windows, one row per account-window."""
    quota = band.get("quota") if isinstance(band.get("quota"), dict) else {}
    windows = [w for w in (quota.get("windows") or []) if isinstance(w, dict)]
    blocks = []
    if not windows:
        blocks.append('<p class="empty">the band carries no quota windows</p>')
    else:
        groups = {}
        for window in windows:
            key = (str(window.get("provider") or ""), str(window.get("window_id") or ""))
            groups.setdefault(key, []).append(window)
        blocks.append('<table><thead><tr><th>provider</th><th>account</th><th>window</th>'
                      '<th>% left</th><th>% used</th><th>resets</th></tr></thead><tbody>')
        for window in windows:
            key = (str(window.get("provider") or ""), str(window.get("window_id") or ""))
            group = groups[key]
            label = str(window.get("label") or window.get("window_label")
                        or window.get("window_id") or "window")
            if len(group) > 1:
                # Two windows that share an id are two windows: the reset day tells them apart.
                label = "%s (resets %s)" % (label, str(window.get("resets_at") or "unknown")[:10])
            account = str(window.get("account_email") or window.get("account_id")
                          or "unknown account")
            remaining = window.get("percent_remaining")
            meter = ""
            if isinstance(remaining, (int, float)) and not isinstance(remaining, bool):
                width = max(0.0, min(100.0, float(remaining)))
                meter = '<span class="meter"><i style="width:%.0f%%"></i></span>' % width
            blocks.append(
                '<tr><td>%s</td><td class="mono">%s</td><td class="mono">%s</td>'
                '<td class="mono">%s%s</td><td class="mono">%s</td><td class="mono">%s</td></tr>' % (
                    esc(window.get("provider_label") or window.get("provider") or "unknown"),
                    esc(account), esc(label),
                    esc(fmt_pct(remaining)), meter, esc(fmt_pct(window.get("percent_used"))),
                    esc(str(window.get("resets_at") or "unknown"))))
        blocks.append("</tbody></table>")
    without = [p for p in (quota.get("providers_without_windows") or []) if isinstance(p, dict)]
    if without:
        blocks.append('<p class="note">Providers with no usable window: %s</p>' % esc("; ".join(
            "%s (%s)" % (p.get("provider") or "?", p.get("state") or "no window")
            for p in without)))
    return "".join(blocks)


def render_rollover(band):
    """The rollover timeline: what each reset restores, soonest first."""
    rows = []
    for row in band.get("rollover") or []:
        if not isinstance(row, dict):
            continue
        if not row.get("resets_at"):
            continue
        rows.append(row)
    rows.sort(key=lambda r: (str(r.get("resets_at") or ""), str(r.get("key") or "")))
    if not rows:
        return '<p class="empty">the band schedules no quota reset</p>'
    blocks = ['<table><thead><tr><th>resets</th><th>in</th><th>window</th>'
              '<th>restores</th></tr></thead><tbody>']
    for row in rows:
        blocks.append('<tr><td class="mono">%s</td><td class="mono">%s</td><td class="mono">%s</td>'
                      '<td class="mono">%s</td></tr>' % (
                          esc(str(row.get("resets_at"))),
                          esc(rel_time(row.get("resets_at"), row.get("resets_in_seconds"))),
                          esc(str(row.get("label") or row.get("window_id") or "window")),
                          esc("restores %s of the window" % fmt_pct(row.get("restores_percent")))))
    blocks.append("</tbody></table>")
    return "".join(blocks)


def render_token_band(state):
    """The token band: headline, daily heat map, quota windows, rollover timeline."""
    blocks = ['<section class="card wide" id="tokens">']
    blocks.append("<h2>Token band — every account, every day</h2>")
    band = state.get("band")
    if band is None:
        blocks.append('<p class="empty">%s</p>' % esc(state.get("detail") or "no band document"))
        blocks.append('<p class="note">The band is written by <code>bin/fm-token-collect.py</code> '
                      'into <code>data/next-board-publish/token-band.json</code>. Until it lands, this '
                      'panel says so — an empty band is never drawn as if all were well.</p>')
        blocks.append("</section>")
        return "".join(blocks)

    age = state.get("age_seconds")
    age_text = "age unknown" if age is None else "%.0f min old" % (age / 60.0)
    pill_class = {"ok": "ok", "stale": "warn"}.get(state.get("state"), "bad")
    blocks.append('<div class="counts"><span>band &nbsp;%s</span><span>generated &nbsp;%s</span>'
                  '<span>%s</span></div>' % (
                      esc(state.get("state") or "unknown"),
                      esc(str(band.get("generated_at") or "unknown")), esc(age_text)))
    if state.get("detail") and state.get("state") != "ok":
        blocks.append('<p class="note">%s</p>' % esc(state["detail"]))
    for problem in state.get("problems") or []:
        blocks.append('<p class="note warn">%s</p>' % esc(problem))

    weekly = band.get("weekly") if isinstance(band.get("weekly"), dict) else {}
    if weekly:
        total = weekly.get("total_tokens")
        per_account = weekly.get("per_account") or {}
        account_count = len(per_account) or len(band_account_ids(band))
        days_known = weekly.get("days_known")
        days_expected = weekly.get("days_expected")
        if days_known is not None and days_expected is not None:
            day_text = "%s of %s days measured" % (fmt_int(days_known), fmt_int(days_expected))
        elif days_known is not None:
            day_text = "%s days measured" % fmt_int(days_known)
        else:
            day_text = "days measured unknown"
        if total is None:
            headline = "weekly total unknown"
        elif weekly.get("is_floor"):
            headline = "at least %s tokens" % fmt_int(total)
        else:
            headline = "%s tokens" % fmt_int(total)
        blocks.append('<p class="headline"><strong>%s</strong> &nbsp;·&nbsp; %d account(s) '
                      '&nbsp;·&nbsp; %s</p>' % (esc(headline), account_count, esc(day_text)))
        if weekly.get("is_floor"):
            unknown = weekly.get("days_unknown")
            blocks.append('<p class="note">The weekly total is a FLOOR, not a whole week: %s day(s) in '
                          'the window carry no reading%s, so the real total is higher than the number '
                          'above.</p>' % (
                              fmt_int(unknown) if unknown is not None else "some",
                              (" (of %s)" % fmt_int(days_expected)) if days_expected is not None else ""))
    else:
        blocks.append('<p class="note">The band carries no weekly block, so there is no weekly total '
                      'to report.</p>')

    blocks.append("<h2 style='margin-top:16px'>DAILY — every account, every day</h2>")
    blocks.append(render_heat_map(band))
    # The weekly total is the headline and stays open. The window list and the
    # rollover detail are the same information at row level, so they fold.
    windows_html = render_quota_windows(band)
    rollover_html = render_rollover(band)
    blocks.append(fold("WEEKLY — the live quota windows (%d window(s))"
                       % data_rows(windows_html), windows_html))
    blocks.append(fold("ROLLOVER — what each reset restores (%d row(s))"
                       % data_rows(rollover_html), rollover_html))
    blocks.append('<p class="note">Source of truth: <code>%s</code>, written by '
                  '<code>bin/fm-token-collect.py</code>. The shape is owned by '
                  '<code>docs/next-board-token-and-chat-contract.md</code>. An unknown value is never '
                  'drawn as a zero.</p>' % esc(str(state.get("path") or BAND_REL)))
    blocks.append("</section>")
    return "".join(blocks)


# --------------------------------------------------------- the selected next work

def select_next_work(queue, tracker_rows):
    """Pick the Captain's next work from his own ticket queue.

    The rule is the contract's, applied in order: only OPEN-WORKABLE tickets are
    eligible; the lowest priority number wins; ties break by the oldest received
    timestamp and then by sequence. No ticket is ever invented.
    """
    by_seq = {str(row.get("sequence")): row for row in tracker_rows if row.get("sequence")}
    eligible = []
    counts = {}
    for ticket in queue:
        seq = str(ticket.get("sequence") or "")
        row = by_seq.get(seq, {})
        state, next_action, owner, _question = ticket_state(row)
        if state == "OPEN-WORKABLE" and not str(next_action or "").strip():
            # A ticket with no recorded next action is not workable - the board's own
            # vocabulary calls that a contract gap. It is counted, never suggested.
            state = "OPEN-WORKABLE (no next action)"
        counts[state] = counts.get(state, 0) + 1
        if state != "OPEN-WORKABLE":
            continue
        priority = str(ticket.get("priority") or row.get("priority") or "P2").upper()
        eligible.append({
            "sequence": seq,
            "slug": str(ticket.get("slug") or row.get("slug") or ""),
            "priority": priority if priority in PRIORITY_ORDER else "P2",
            "received": str(ticket.get("received") or row.get("received") or ""),
            "area": str(ticket.get("area") or row.get("area") or "-"),
            "source": str(ticket.get("source") or row.get("source") or "-"),
            "next_action": next_action,
            "owner": owner,
            "title": str(row.get("title") or ""),
        })

    if not eligible:
        return None, counts

    def sort_key(item):
        try:
            sequence = int(item["sequence"])
        except (TypeError, ValueError):
            sequence = 0
        stamp = parse_iso(item["received"])
        if stamp is None:
            return (PRIORITY_ORDER.get(item["priority"], 9), 1, 0.0, sequence)
        return (PRIORITY_ORDER.get(item["priority"], 9), 0, stamp.timestamp(), sequence)

    eligible.sort(key=sort_key)
    chosen = eligible[0]
    same_priority = [e for e in eligible if e["priority"] == chosen["priority"]]
    tied = [e for e in same_priority if e["received"] == chosen["received"]]
    parts = []
    if len(same_priority) == 1:
        parts.append("the only OPEN-WORKABLE ticket at %s" % chosen["priority"])
    else:
        parts.append("the oldest of %d OPEN-WORKABLE tickets at %s (received %s)" % (
            len(same_priority), chosen["priority"], chosen["received"] or "unknown"))
        if len(tied) > 1:
            parts.append("tied on the received stamp, broken by sequence")
    parts.append("the lowest priority number of the %d OPEN-WORKABLE ticket(s)" % len(eligible))
    chosen["reason"] = " · ".join(parts)
    chosen["eligible_count"] = len(eligible)
    return chosen, counts


def done_looks_like(selection):
    """What closing this ticket looks like, taken from the ticket's own words."""
    text = selection.get("title") or selection.get("next_action") or ""
    for marker in DONE_MARKERS:
        index = text.find(marker)
        if index >= 0:
            return truncate(text[index:], 400)
    if not text:
        return "closed with a VERDICT and an artifact recorded in the tracker"
    return "closed with a VERDICT and an artifact recorded in the tracker — %s" % truncate(text, 200)


def render_next_work(selection, counts):
    """The one selected next work, at the top of the board."""
    blocks = ['<section class="card wide" id="next-work">']
    blocks.append("<h2>Selected next work — the one to start now</h2>")
    if selection is None:
        breakdown = ", ".join("%s %d" % (state, count) for state, count in sorted(counts.items()))
        blocks.append('<p class="empty">No ticket in the queue is OPEN-WORKABLE right now, so there is '
                      'nothing truthful to suggest. The queue holds: %s.</p>' % esc(breakdown or "nothing"))
        blocks.append('<p class="note">A ticket becomes OPEN-WORKABLE when it carries a real next action '
                      'and an owner, and is neither blocked nor waiting on a Captain decision. This card '
                      'never invents a suggestion.</p>')
        blocks.append("</section>")
        return "".join(blocks)
    slug = "%s-%s" % (selection["sequence"], selection["slug"]) if selection["slug"] else selection["sequence"]
    priority = selection["priority"].lower()
    owner = selection["owner"]
    owner_text = "unassigned — no lane holds it" if owner in ("-", "", "None", "none") else owner
    blocks.append('<div class="selhead"><span class="pill %s">%s</span><code>%s</code>'
                  '<span class="muted">%s &nbsp;·&nbsp; received %s &nbsp;·&nbsp; source %s</span></div>' % (
                      esc(priority), esc(selection["priority"]), esc(slug),
                      esc(selection["area"]), esc(selection["received"] or "unknown"),
                      esc(selection["source"])))
    blocks.append('<dl class="kv">')
    blocks.append('<dt>Why this one</dt><dd>%s</dd>' % esc(selection["reason"]))
    blocks.append('<dt>Next action</dt><dd>%s</dd>' % esc(truncate(selection["next_action"], 320) or "-"))
    blocks.append('<dt>Owner</dt><dd>%s</dd>' % esc(owner_text))
    blocks.append('<dt>Done looks like</dt><dd>%s</dd>' % esc(done_looks_like(selection)))
    blocks.append("</dl>")
    blocks.append('<p class="note">Chosen by the contract\'s rule from the Captain\'s own ticket queue '
                  '(<code>%s</code>), not from a separate plan.</p>' % esc(QUEUE_BOARD_REL))
    blocks.append("</section>")
    return "".join(blocks)


# ------------------------------------------------------------------ the chat card

def feedback_stamp(path, timestamp):
    """When a feedback entry was written, as an epoch float, or None."""
    match = re.match(r"^(\d{8}T\d{6}Z)", path.name)
    if match:
        try:
            parsed = dt.datetime.strptime(match.group(1), "%Y%m%dT%H%M%SZ")
            return parsed.replace(tzinfo=dt.timezone.utc).timestamp()
        except ValueError:
            pass
    parsed = parse_iso(timestamp)
    if parsed is not None:
        return parsed.timestamp()
    try:
        return path.stat().st_mtime
    except OSError:
        return None


def read_feedback_entry(path, kind):
    """One feedback file, read into the fields the board shows."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    timestamp = ""
    match = re.search(r"^-\s*Timestamp:\s*(.+)$", text, re.M)
    if match:
        timestamp = match.group(1).strip()
    ticket = ""
    match = re.search(r"^-\s*Ticket:\s*(.+)$", text, re.M)
    if match:
        ticket = match.group(1).strip()
    source = ""
    match = re.search(r"^-\s*Source:\s*(.+)$", text, re.M)
    if match:
        source = match.group(1).strip()
    comment = ""
    match = re.search(r"^##\s*Comment\s*$(.*?)(?=\n##\s|\Z)", text, re.M | re.S)
    if match:
        lines = []
        for line in match.group(1).splitlines():
            if not line.strip():
                continue
            stripped = re.sub(r"^\s*>\s?", "", line)
            # A body that restates the section it is already in adds a heading
            # to the board, not a message. The heading the section was matched on
            # has already been consumed above, so a second one is redundant.
            if re.match(r"^##\s*Comment\s*$", stripped):
                continue
            lines.append(stripped)
        comment = "\n".join(lines).strip()
    if not comment:
        comment = text.strip()
    return {
        "kind": kind,
        "file": path.name,
        "ticket": ticket or "(no ticket)",
        "source": source or "unknown",
        "timestamp": timestamp or "unknown",
        "stamp": feedback_stamp(path, timestamp),
        "comment": comment,
    }


def read_chat_state(repo):
    """The board's chat state: the Lavish session and the recent conversation."""
    state = {"session": None, "session_note": "", "entries": [], "entries_note": ""}
    session_path = pathlib.Path(repo) / SESSION_REL
    if session_path.is_file():
        try:
            data = json.loads(session_path.read_text(encoding="utf-8", errors="replace"))
            if isinstance(data, dict):
                state["session"] = data
            else:
                state["session_note"] = "the session state file does not hold a JSON object"
        except OSError as exc:
            state["session_note"] = "cannot read the session state file: %s" % exc
        except ValueError as exc:
            state["session_note"] = "the session state file is not valid JSON: %s" % exc
    else:
        state["session_note"] = ("no Lavish session is open for this board — open one with "
                                 "bin/fm-next-board-chat.sh review")

    feedback_dir = pathlib.Path(repo) / FEEDBACK_REL
    if not feedback_dir.is_dir():
        state["entries_note"] = "no message has been sent to this board yet"
        return state
    entries = []
    try:
        for path in sorted(feedback_dir.glob("*.md")):
            entry = read_feedback_entry(path, "captain")
            if entry:
                entries.append(entry)
        replies_dir = feedback_dir / "replies"
        if replies_dir.is_dir():
            for path in sorted(replies_dir.glob("*.md")):
                entry = read_feedback_entry(path, "agent")
                if entry:
                    entries.append(entry)
    except OSError as exc:
        state["entries_note"] = "cannot read the feedback directory: %s" % exc
        return state
    if not entries:
        state["entries_note"] = "no message has been sent to this board yet"
    entries.sort(key=lambda e: (0, e["stamp"]) if e["stamp"] is not None else (1, 0.0), reverse=True)
    state["entries"] = entries
    return state


def format_session_value(value):
    if isinstance(value, bool):
        return "yes" if value else "no"
    if value is None:
        return "unknown"
    return str(value)


def render_talk(chat_state):
    """The chat card: the session link, the form, and the recent conversation."""
    blocks = ['<section class="card wide" id="talk">']
    blocks.append("<h2>Talk to the agent — this board is live</h2>")
    session = chat_state.get("session") or {}
    url = str(session.get("url") or "").strip()
    blocks.append('<div class="talkbar">')
    if url:
        blocks.append('<a class="btn" href="%s" rel="noopener">Open the Lavish session</a>' % esc(url))
    else:
        blocks.append('<span class="pill warn">no Lavish session open</span>')
    note = chat_state.get("session_note") or ""
    if note:
        blocks.append('<span class="muted">%s</span>' % esc(note))
    blocks.append("</div>")
    if session:
        blocks.append('<dl class="kv">')
        for label, key in (("Session id", "session_id"), ("Source id", "source_id"),
                           ("Opened", "opened_at"), ("Armed", "armed"),
                           ("Pending results", "pending_results"),
                           ("Last result", "last_result_at")):
            if key in session:
                blocks.append('<dt>%s</dt><dd>%s</dd>' % (
                    esc(label), esc(format_session_value(session.get(key)))))
        blocks.append("</dl>")

    blocks.append('<form method="post" action="/next-board/feedback" class="talkform">')
    blocks.append('<label for="talk-ticket">Ticket</label>')
    blocks.append('<input id="talk-ticket" name="ticket" type="text" maxlength="200" '
                  'placeholder="0042-wordpress-staging-and-port-parity">')
    blocks.append('<label for="talk-comment">Comment</label>')
    blocks.append('<textarea id="talk-comment" name="comment" rows="4" maxlength="8000" '
                  'placeholder="what you want the agent to do next"></textarea>')
    blocks.append('<button type="submit">Send to the agent</button>')
    blocks.append("</form>")
    blocks.append('<p class="note">The form posts to <code>/next-board/feedback</code>. The Captain\'s '
                  'message lands in the tracker\'s durable state and wakes the agent; the agent\'s reply '
                  'appears below.</p>')

    blocks.append("<h2 style='margin-top:16px'>Recent conversation</h2>")
    entries = chat_state.get("entries") or []
    if not entries:
        blocks.append('<p class="empty">%s</p>' % esc(chat_state.get("entries_note")
                                                       or "no message has been sent to this board yet"))
    else:
        blocks.append('<ul class="talklog">')
        for entry in entries[:TALK_ENTRIES_SHOWN]:
            from_agent = entry["kind"] == "agent"
            blocks.append('<li><div class="talkhead"><span class="pill %s">%s</span><code>%s</code>'
                          '<span class="muted">%s</span></div><div class="talkbody">%s</div></li>' % (
                              "ok" if from_agent else "p2",
                              "agent" if from_agent else "you",
                              esc(entry["ticket"]), esc(entry["timestamp"]),
                              esc_multiline(clip(entry["comment"], 1200))))
        blocks.append("</ul>")
        if len(entries) > TALK_ENTRIES_SHOWN:
            blocks.append('<p class="muted">…and %d more</p>' % (len(entries) - TALK_ENTRIES_SHOWN))
    blocks.append("</section>")
    return "".join(blocks)


def safe_render(renderer, args, section_id):
    """Render one section, or a plain note. The publisher runs on a timer and never dies."""
    try:
        return renderer(*args)
    except Exception as exc:  # a bad input must never take the timer down
        return ('<section class="card wide" id="%s"><h2>%s</h2><p class="empty">this section '
                'could not be rendered: %s</p></section>' % (section_id, esc(section_id), esc(exc)))


def render_page(now, delivery, queue, tracker_rows, board_json, board_age,
                band_state=None, chat_state=None, selection=None, counts=None):
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
%s
%s
%s
</main>
</body></html>
""" % (esc(title), CSS, esc(now), freshness_banner(board_age),
       safe_render(render_next_work, (selection, counts or {}), "next-work"),
       safe_render(render_token_band, (band_state or {},), "tokens"),
       safe_render(render_talk, (chat_state or {},), "talk"),
       render_delivery(delivery), render_queue(queue, tracker_rows, board_json.get("items")),
       render_next(board_json))


# ------------------------------------------------------------------------ 5. publish

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--out", default=None)
    parser.add_argument("--serve-root", default=None)
    parser.add_argument("--builder", default=None)
    parser.add_argument("--band", default=None,
                        help="path to the token band document (default: the publish directory)")
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
            verdict = builder.verdict_text(text)
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

    # 4b. the token band, the chat state and the one selected next work. Each one
    # degrades to a truthful note: the publisher runs on a timer and never crashes it.
    band_path = resolve_band_path(repo, out, args.band)
    try:
        band_state = read_token_band(band_path)
    except Exception as exc:
        band_state = {"path": str(band_path), "state": "error", "band": None, "age_seconds": None,
                      "detail": "the band could not be read: %s" % exc, "problems": []}
    try:
        chat_state = read_chat_state(repo)
    except Exception as exc:
        chat_state = {"session": None, "session_note": "the chat state could not be read: %s" % exc,
                      "entries": [], "entries_note": "the chat state could not be read"}
    try:
        selection, state_counts = select_next_work(queue, tracker_rows)
    except Exception as exc:
        selection, state_counts = None, {}
        sys.stderr.write("fm-next-board-publish: WARNING next work not selected: %s\n" % exc)
    page = render_page(now, delivery, queue, tracker_rows, board_json, board_age,
                        band_state, chat_state, selection, state_counts)

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
        "token_band": {"path": band_state["path"], "state": band_state["state"],
                       "detail": band_state["detail"]},
        "next_work": ("%s-%s" % (selection["sequence"], selection["slug"])) if selection else None,
        "talk_entries": len(chat_state.get("entries") or []),
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
    print("fm-next-board-publish: band=%s next_work=%s talk_entries=%d" % (
        band_state["state"],
        ("%s-%s" % (selection["sequence"], selection["slug"])) if selection else "none",
        len(chat_state.get("entries") or [])))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
