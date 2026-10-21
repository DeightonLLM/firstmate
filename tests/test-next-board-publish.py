#!/usr/bin/env python3
"""
test-next-board-publish.py — the regression check for the Captain's live tracker board.

The tracker rotted once because nothing regenerated it: the page the Captain opened was a
four-day-old static preview. This check exists so that cannot happen again quietly. It is
non-interactive, it exits 0 (everything holds) or 1 (something is wrong), and it is safe to
run repeatedly — it only READS.

It fails when:
  * the published board is missing, or is older than the freshness bound;
  * the board does not carry every ticket the queue holds (the Captain's own tasks hidden);
  * the delivery-state block is missing, or the listener state the board claims does not
    match the listener state measured right now (a board that lies about delivery);
  * the NEXT contract is broken: an item with no state, an item that is neither closed nor
    carrying a next action and owner without being reported as a CONTRACT-GAP;
  * the tracker page cannot reach the board over HTTP, or the tracker's own page does not
    carry the one-click link to it;
  * the token band, the selected next work or the chat card renders wrongly: a floor
    weekly total shown as a whole week, an unknown day drawn as a zero, two quota
    windows that share an id merged into one row, a missing band crashing the publisher,
    a suggestion that is not the one the contract's rule picks, or a comment that reaches
    the browser unescaped.

usage: test-next-board-publish.py [--repo PATH] [--publish-dir DIR] [--serve-root DIR]
                                   [--max-age-minutes N] [--port N] [--bind ADDR]
"""
import argparse
import copy
import datetime as dt
import importlib.util
import json
import os
import pathlib
import re
import sys
import tempfile
import urllib.error
import urllib.request

QUEUE_BOARD_REL = "data/campaign-dashboard-20261015/board.md"
QUEUE_RECORD_RE = re.compile(
    r"^<!-- ticket-intake sha256=[0-9a-f]{64} sequence=([0-9]{4}) area=[^ ]+ priority=(P[012]) slug=([a-z0-9-]+) -->$",
    re.M,
)

FAILURES = []
CHECKS = []

# The publisher under test, and a scratch space for its fixtures. The scratch space
# lives inside this checkout so a test run never writes outside it.
REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBLISHER_PATH = REPO_ROOT / "bin" / "fm-next-board-publish.py"


def scratch_dir():
    """A scratch directory inside this checkout, removed when the block ends."""
    base = REPO_ROOT / "data"
    base.mkdir(parents=True, exist_ok=True)
    return tempfile.TemporaryDirectory(dir=str(base))


def load_publisher():
    """Load the publisher module the same way the timer does."""
    spec = importlib.util.spec_from_file_location("fm_next_board_publish", PUBLISHER_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def check(name, ok, detail=""):
    CHECKS.append((name, bool(ok), detail))
    if not ok:
        FAILURES.append("%s%s" % (name, (" — " + detail) if detail else ""))
    print("%s %s%s" % ("PASS" if ok else "FAIL", name, (" — " + detail) if detail else ""))
    return bool(ok)


def http_get(url, timeout=10):
    request = urllib.request.Request(url, headers={"User-Agent": "fm-next-board-check/1"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.status, response.read().decode("utf-8", "replace")


def measure_listener(repo):
    """Measure the listener state independently of the published board."""
    reg_dir = pathlib.Path(repo) / "state" / "procevent"
    alive = False
    source_id = None
    if reg_dir.is_dir():
        for src in sorted(reg_dir.glob("*.source")):
            sid = src.name[: -len(".source")]
            text = src.read_text(encoding="utf-8", errors="replace")
            if "lavish" not in text:
                continue
            source_id = sid
            runner = reg_dir / ("%s.runner" % sid)
            if runner.is_file():
                try:
                    pid = int(runner.read_text(encoding="utf-8").strip())
                except (OSError, ValueError):
                    pid = 0
                if pid and os.path.isdir("/proc/%d" % pid):
                    alive = True
    for entry in pathlib.Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            with open("/proc/%s/cmdline" % entry.name, "rb") as fh:
                cmdline = fh.read().replace(b"\0", b" ").decode("utf-8", "replace")
        except OSError:
            continue
        if "lavish-axi poll" in cmdline:
            alive = True
    return source_id, alive


# ------------------------------------------- the fixtures the render checks use

BAND_FIXTURE = {
    "schema": "firstmate-token-band/v1",
    "generated_at": "2026-10-21T05:00:00Z",
    "errors": [],
    "quota": {
        "ok": True,
        "error": None,
        "windows": [
            {
                "key": "codex|weekly|2026-10-27", "provider": "codex", "provider_label": "Codex",
                "account_id": "602f6bbb", "account_email": "boxedagency@gmail.com",
                "window_id": "weekly", "window_label": "week", "label": "Codex - week",
                "percent_remaining": 82, "percent_used": 18,
                "resets_at": "2026-10-27T06:34:19.000Z",
            },
            {
                "key": "agy|gemini_weekly|2026-10-23", "provider": "agy", "provider_label": "AGY",
                "account_id": "a1b2c3", "account_email": "ops@example.com",
                "window_id": "gemini_weekly", "window_label": "week", "label": "AGY - week",
                "percent_remaining": 41, "percent_used": 59,
                "resets_at": "2026-10-23T09:00:00.000Z",
            },
            {
                "key": "agy|gemini_weekly|2026-10-26", "provider": "agy", "provider_label": "AGY",
                "account_id": "d4e5f6", "account_email": "second@example.com",
                "window_id": "gemini_weekly", "window_label": "week", "label": "AGY - week",
                "percent_remaining": 96, "percent_used": 4,
                "resets_at": "2026-10-26T09:00:00.000Z",
            },
        ],
        "providers_without_windows": [
            {"provider": "claude", "state": "auth_required", "not_set_up": True},
        ],
    },
    "ledger": {
        "ok": True,
        "accounts": [
            {"id": "codex-local-unmapped", "label": "codex local (unmapped)", "provider": "codex"},
        ],
    },
    "daily": [
        {"date": "2026-10-15", "total_tokens": 158656541, "total_status": "measured",
         "accounts": {"codex-local-unmapped": 91313643, "glm-local-unmapped": 52021917}},
        {"date": "2026-10-16", "total_tokens": 101000000, "total_status": "measured",
         "accounts": {"codex-local-unmapped": 101000000}},
        {"date": "2026-10-17", "total_tokens": None, "total_status": "unknown", "accounts": {}},
    ],
    "weekly": {
        "start_date": "2026-10-15", "end_date": "2026-10-21", "days_expected": 7,
        "days_known": 2, "days_unknown": 5, "total_tokens": 655333299,
        "status": "partial", "is_floor": True,
        "per_account": {"codex-local-unmapped": 230674066, "glm-local-unmapped": 52021917},
        "per_account_known_days": {"codex-local-unmapped": 2, "glm-local-unmapped": 1},
    },
    "rollover": [
        {"key": "codex|five_hour|2026-10-21", "provider": "codex", "window_id": "five_hour",
         "label": "Codex - session", "resets_at": "2026-10-21T06:50:19.000Z",
         "resets_in_seconds": 2700, "percent_remaining": 70, "restores_percent": 100},
    ],
}

# The Captain's own queue, shaped the way the publisher reads it.
QUEUE_FIXTURE = [
    {"sequence": "0001", "slug": "captain-decision", "priority": "P0",
     "received": "2026-10-10T00:00:00Z", "area": "Ops", "source": "chat"},
    {"sequence": "0002", "slug": "blocked-ticket", "priority": "P1",
     "received": "2026-10-11T00:00:00Z", "area": "Ops", "source": "chat"},
    {"sequence": "0003", "slug": "no-next-action", "priority": "P1",
     "received": "2026-10-12T00:00:00Z", "area": "Ops", "source": "chat"},
    {"sequence": "0004", "slug": "newer-p1", "priority": "P1",
     "received": "2026-10-20T00:00:00Z", "area": "Ops", "source": "chat"},
    {"sequence": "0005", "slug": "older-p1", "priority": "P1",
     "received": "2026-10-18T00:00:00Z", "area": "Ops", "source": "chat"},
    {"sequence": "0006", "slug": "p2-ticket", "priority": "P2",
     "received": "2026-10-10T00:00:00Z", "area": "Ops", "source": "chat"},
]

TRACKER_FIXTURE = [
    {"sequence": "0001", "decision": "yes", "recovery": "Captain names the branch",
     "next_action": "Await Captain decision", "lane": "-", "lane_state": "-",
     "blocked_by": "-", "title": "Choose a branch"},
    {"sequence": "0002", "decision": "no", "blocked_by": "0001", "next_action": "Wait",
     "lane": "lane-a", "lane_state": "-", "title": "Wait for 0001"},
    {"sequence": "0003", "decision": "no", "blocked_by": "-", "next_action": "Await lane dispatch",
     "lane": "-", "lane_state": "-", "title": "Nobody holds this"},
    {"sequence": "0004", "decision": "no", "blocked_by": "-", "next_action": "Do the newer P1 work",
     "lane": "lane-b", "lane_state": "-", "title": "Do the newer P1 work"},
    {"sequence": "0005", "decision": "no", "blocked_by": "-", "next_action": "Do the older P1 work",
     "lane": "lane-c", "lane_state": "-", "title": "Do the older P1 work"},
    {"sequence": "0006", "decision": "no", "blocked_by": "-", "next_action": "Do the P2 work",
     "lane": "lane-d", "lane_state": "-", "title": "Do the P2 work"},
]

HOSTILE_COMMENT = '<script>alert("pwned")</script> and <b>bold</b>'


def band_fixture(generated_at=None):
    """The band fixture with a generation time that is fresh whenever the test runs."""
    band = copy.deepcopy(BAND_FIXTURE)
    band["generated_at"] = generated_at or (
        dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ")
    return band


def heat_grid(html_text):
    """The rendered heat map as {account: {date: cell html}}, plus the day-total row."""
    table = re.search(r'<table class="heat">.*?</table>', html_text, re.S)
    if table is None:
        return {}, [], {}
    body = table.group(0)
    head = re.search(r"<thead>(.*?)</thead>", body, re.S)
    dates = re.findall(r'title="(\d{4}-\d{2}-\d{2})"', head.group(1) if head else "")
    grid = {}
    total = {}
    for attrs, row in re.findall(r"<tr\b([^>]*)>(.*?)</tr>", body, re.S):
        cells = re.findall(r"<td\b[^>]*>(.*?)</td>", row, re.S)
        if len(cells) < 2:
            continue
        if 'class="total"' in attrs:
            total = dict(zip(dates, cells[1:1 + len(dates)]))
            continue
        owner = re.search(r'title="([^"]*)"', cells[0])
        name = owner.group(1) if owner else cells[0]
        grid[name] = dict(zip(dates, cells[1:1 + len(dates)]))
    return grid, dates, total


def run_render_checks():
    """The three rendered sections, checked against fixtures. Offline and self-contained."""
    if not PUBLISHER_PATH.is_file():
        check("the publisher under test exists", False, str(PUBLISHER_PATH))
        return
    publisher = load_publisher()

    with scratch_dir() as scratch:
        root = pathlib.Path(scratch)

        # 1. the band renders from a fixture band document
        band_path = root / "token-band.json"
        band_path.write_text(json.dumps(band_fixture()), encoding="utf-8")
        state = publisher.read_token_band(band_path)
        check("the fixture band document is read as fresh", state.get("state") == "ok",
              "%s (%s)" % (state.get("state"), state.get("detail")))
        band_html = publisher.render_token_band(state)
        check("the band renders its four parts",
              all(marker in band_html for marker in ('id="tokens"', "DAILY", "WEEKLY", "ROLLOVER")),
              "headline, heat map, quota windows, rollover")
        check("the band headline states the total, the accounts and the days covered",
              "655,333,299" in band_html and "2 account(s)" in band_html
              and "2 of 7 days measured" in band_html)

        # 2. a floor weekly total is never shown as a whole week
        check("a floor weekly total renders as 'at least'",
              "at least 655,333,299" in band_html and ">655,333,299 tokens<" not in band_html)

        # 3. an unknown day is blank, never zero
        grid, dates, total = heat_grid(band_html)
        check("the heat map carries a column for every day of the week and every ledger day",
              dates == ["2026-10-15", "2026-10-16", "2026-10-17", "2026-10-18",
                        "2026-10-19", "2026-10-20", "2026-10-21"],
              ",".join(dates))
        unknown_cells = [cells.get("2026-10-17", "") for cells in grid.values()]
        check("an unknown day renders blank for every account",
              bool(unknown_cells) and all(cell.strip() in ("", "&nbsp;") for cell in unknown_cells),
              " | ".join(cell.strip() for cell in unknown_cells))
        every_cell = [cell.strip() for cells in grid.values() for cell in cells.values()]
        check("no heat map cell shows a zero", "0" not in every_cell,
              " | ".join(cell for cell in every_cell if cell == "0"))
        check("the day the ledger marks unknown is shown as unknown in the day total",
              total.get("2026-10-17", "").strip() == "unknown",
              total.get("2026-10-17", "(missing)"))

        # 4. two quota windows that share an id stay two rows
        window_rows = re.findall(r"<tr><td>AGY</td>.*?</tr>", band_html, re.S)
        check("two quota windows with the same id render as two rows",
              len(window_rows) == 2, "%d rows" % len(window_rows))
        check("the two same-id windows are visibly distinguishable",
              len(window_rows) == 2 and "resets 2026-10-23" in window_rows[0]
              and "resets 2026-10-26" in window_rows[1])

        # 5. a missing band is a truthful note, not a crash
        missing = publisher.read_token_band(root / "no-such-band.json")
        missing_html = publisher.render_token_band(missing)
        check("a missing band file renders a truthful note",
              missing.get("state") == "missing" and "no token band document" in missing_html,
              missing.get("state"))

        # 5b. so is a malformed, a stale and an empty band
        broken_band = root / "broken-band.json"
        broken_band.write_text("{not json at all", encoding="utf-8")
        broken = publisher.read_token_band(broken_band)
        check("a malformed band file renders a truthful note",
              broken.get("state") == "malformed"
              and "not valid JSON" in publisher.render_token_band(broken),
              broken.get("state"))
        stale_band = root / "stale-band.json"
        stale_band.write_text(json.dumps(band_fixture(
            generated_at=(dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=3))
            .strftime("%Y-%m-%dT%H:%M:%SZ"))), encoding="utf-8")
        stale = publisher.read_token_band(stale_band)
        check("a stale band file is reported as stale",
              stale.get("state") == "stale" and "stale" in publisher.render_token_band(stale),
              stale.get("state"))
        null_band = root / "null-band.json"
        null_band.write_text(json.dumps({
            "generated_at": (dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=1))
            .strftime("%Y-%m-%dT%H:%M:%SZ"),
            "quota": {"ok": False, "error": "credentials_missing", "windows": None},
            "ledger": {"ok": False, "error": "no ledger", "accounts": None},
            "daily": None, "weekly": None, "rollover": None,
        }), encoding="utf-8")
        nulled = publisher.read_token_band(null_band)
        null_html = publisher.render_token_band(nulled)
        check("a band with null sections still renders and names the failed sources",
              'id="tokens"' in null_html and "credentials_missing" in null_html
              and "no ledger" in null_html)

        # 6. the selected next work, from a fixture queue
        selection, counts = publisher.select_next_work(QUEUE_FIXTURE, TRACKER_FIXTURE)
        check("the selected next work is the oldest OPEN-WORKABLE ticket at the lowest priority",
              selection is not None and selection["sequence"] == "0005",
              "picked %s" % (selection["sequence"] if selection else "nothing"))
        work_html = publisher.render_next_work(selection, counts)
        check("the selected work card shows the ticket, the priority, the rule, the next action, "
              "the owner and what done looks like",
              all(marker in work_html for marker in
                  ('id="next-work"', "0005-older-p1", "P1", "Why this one", "Next action", "Owner",
                   "Done looks like", "lane-c")))

        # 7. no eligible ticket means a plain statement, not an invention
        ineligible = [t for t in QUEUE_FIXTURE if t["sequence"] in ("0001", "0002", "0003")]
        rows = [r for r in TRACKER_FIXTURE if r["sequence"] in ("0001", "0002", "0003")]
        none_selection, none_counts = publisher.select_next_work(ineligible, rows)
        none_html = publisher.render_next_work(none_selection, none_counts)
        check("with no eligible ticket the board says so plainly",
              none_selection is None and "No ticket in the queue is OPEN-WORKABLE" in none_html)

        # 8. the chat card: the form, the session link, the conversation
        state_dir = root / "state"
        feedback_dir = state_dir / "next-board-feedback"
        replies_dir = feedback_dir / "replies"
        replies_dir.mkdir(parents=True, exist_ok=True)
        (feedback_dir / "20261021T051200Z-hostile.md").write_text(
            "# Board feedback\n\n- Timestamp: 2026-10-21T05:12:00Z\n- Ticket: 0005-older-p1\n"
            "- Source: form\n\n## Comment\n\n> %s\n> second line\n" % HOSTILE_COMMENT,
            encoding="utf-8")
        (replies_dir / "20261021T051500Z-answer.md").write_text(
            "# Board feedback\n\n- Timestamp: 2026-10-21T05:15:00Z\n- Ticket: 0005-older-p1\n"
            "- Source: agent\n\n## Comment\n\n> the agent answered\n", encoding="utf-8")
        talk = publisher.read_chat_state(root)
        talk_html = publisher.render_talk(talk)
        check("the chat card renders the form posting to /next-board/feedback",
              'action="/next-board/feedback"' in talk_html
              and 'name="ticket"' in talk_html and 'name="comment"' in talk_html)
        check("the chat card escapes a hostile comment",
              "<script>" not in talk_html and "&lt;script&gt;" in talk_html
              and "<b>bold</b>" not in talk_html)
        check("the conversation is newest first",
              talk_html.find("the agent answered") < talk_html.find("alert("),
              "the agent's reply comes before the Captain's message")
        check("a board with no session file never fabricates a session link",
              "session" not in talk_html.lower().split("<form")[0].replace("lavish session", "")
              or "http" not in talk_html.split("<form")[0])

        # the same board with a real session file carries the real link
        (state_dir / "next-board-session.json").write_text(json.dumps({
            "schema": "firstmate-next-board-session/v1",
            "opened_at": "2026-10-21T05:10:00Z",
            "source_id": "lavish-a1b2c3d4e5f60718",
            "session_id": "affb98427860194e",
            "url": "http://host.tailnet.ts.net:4387/session/affb98427860194e",
            "armed": True,
            "pending_results": 0,
        }), encoding="utf-8")
        talk_with_session = publisher.read_chat_state(root)
        session_html = publisher.render_talk(talk_with_session)
        check("a real session state file renders the session link",
              'href="http://host.tailnet.ts.net:4387/session/affb98427860194e"' in session_html)

        # a broken session file never becomes a link
        broken_state = root / "broken-state"
        (broken_state / "state").mkdir(parents=True)
        (broken_state / "state" / "next-board-session.json").write_text("{oops", encoding="utf-8")
        broken_talk = publisher.read_chat_state(broken_state)
        broken_html = publisher.render_talk(broken_talk)
        check("a malformed session file never fabricates a session link",
              "not valid JSON" in broken_talk["session_note"]
              and "http://" not in broken_html.split("<form")[0])

        # a feedback path that is not a directory is a note, not a crash
        odd_state = root / "odd-state"
        odd_state.mkdir()
        (odd_state / "next-board-feedback").write_text("not a directory", encoding="utf-8")
        odd_talk = publisher.read_chat_state(odd_state)
        check("a feedback path that is not a directory does not crash the card",
              'id="talk"' in publisher.render_talk(odd_talk))


def run_live_checks(args):
    """The published board itself: is it there, is it fresh, and does it tell the truth."""
    repo = pathlib.Path(args.repo).resolve()
    publish = pathlib.Path(args.publish_dir) if args.publish_dir else repo / "data" / "next-board-publish"

    # 1. the board exists at all
    index = publish / "index.html"
    board_json_path = publish / "next-board.json"
    board_md = publish / "NEXT-BOARD.md"
    ok = index.is_file() and board_json_path.is_file() and board_md.is_file()
    if not check("published board exists", ok, str(publish)):
        return

    # 2. it is fresh — the failure mode that produced the four-day-old preview
    age = int(dt.datetime.now(dt.timezone.utc).timestamp() - index.stat().st_mtime)
    age_minutes = age // 60
    check("published board is fresh (<=%d min)" % args.max_age_minutes,
          age <= args.max_age_minutes * 60,
          "age %dm%ds" % (age_minutes, age % 60))

    html = index.read_text(encoding="utf-8", errors="replace")
    board = json.loads(board_json_path.read_text(encoding="utf-8"))

    # 3. the Captain's own ticket set is on the board
    queue_file = repo / QUEUE_BOARD_REL
    if queue_file.is_file():
        queue_text = queue_file.read_text(encoding="utf-8", errors="replace")
        tickets = QUEUE_RECORD_RE.findall(queue_text)
        missing = [("%s-%s" % (seq, slug)) for seq, _p, slug in tickets
                   if ("%s-%s" % (seq, slug)) not in html]
        check("every queue ticket appears on the board", not missing,
              ("%d tickets, missing: %s" % (len(tickets), ", ".join(missing[:6])))
              if missing else "%d tickets" % len(tickets))
        check("board shows the ticket queue section", 'id="tickets"' in html)
    else:
        check("queue file is readable", False, str(queue_file))

    # 4. the delivery-state block is present and true
    check("board carries the delivery-state section", 'id="delivery"' in html)
    delivery_path = publish / "delivery-state.json"
    if check("delivery-state.json exists", delivery_path.is_file()):
        delivery = json.loads(delivery_path.read_text(encoding="utf-8"))
        for field in ("listener_alive", "last_result", "pending_results", "measured_at"):
            check("delivery state reports %s" % field, field in delivery)
        source_id, alive_now = measure_listener(repo)
        claimed = bool(delivery.get("listener_alive"))
        check("board's listener state matches reality", claimed == alive_now,
              "board says alive=%s, measured alive=%s (source %s)" % (claimed, alive_now, source_id))
        check("delivery state says when the last delivery happened",
              bool(delivery.get("last_result")) or delivery.get("total_results", 0) == 0)
        check("board explains that a busy agent queues the message",
              "queued, not lost" in html)

    # 5. the NEXT contract holds
    items = board.get("items", [])
    check("board items carry a state", all(i.get("state") for i in items),
          "%d items" % len(items))
    broken = []
    for item in items:
        state = item.get("state")
        if not state:
            broken.append("%s: no state" % item.get("slug"))
            continue
        if state in ("VERIFIED-DONE", "STALE-DUPLICATE"):
            continue
        if state == "CONTRACT-GAP":
            continue
        if not item.get("next_action") or not item.get("owner"):
            broken.append("%s: %s without next action/owner" % (item.get("slug"), state))
    check("every open item has a next action and an owner, or is a CONTRACT-GAP",
          not broken, "; ".join(broken[:5]) if broken else "%d items" % len(items))
    check("board has a RESIDUALS section", "RESIDUALS" in html)
    check("board names what only the Captain can decide",
          "ONLY YOU CAN UNBLOCK" in html or "ONLY THE CAPTAIN CAN UNBLOCK" in html)

    # 5b. the page opens on the signposts, not on a wall of rows
    #
    # The board grew into 70 visible rows and 195 list items, which buried the
    # signposts the Captain actually opens it for. The long lists now fold behind
    # a disclosure. These checks fail if a fold ever stops counting, stops being
    # collapsed by default, or starts hiding a ticket.
    def folded_summaries():
        return [re.sub(r"<[^>]+>", "", s)
                for s in re.findall(r"<summary>(.*?)</summary>", html, re.S)]

    def collapsed_bodies():
        return re.findall(r'<details class="fold"(?![^>]*\sopen)[^>]*>(.*?)</details>',
                          html, re.S)

    summaries = folded_summaries()
    check("the board folds its long lists away by default",
          len(collapsed_bodies()) >= 4,
          "%d collapsed disclosure(s)" % len(collapsed_bodies()))
    uncounted = [s for s in summaries if not re.search(r"\d", s)]
    check("every folded list states its count", not uncounted,
          "; ".join(uncounted[:3]) if uncounted else "%d folded list(s)" % len(summaries))

    for label in ("RESIDUALS", "CLOSED", "CONTRACT-GAP"):
        found = any(label in s for s in summaries)
        check("the %s list is folded, not expanded" % label, found,
              "folded: %s" % [s[:50] for s in summaries if label in s][:1])

    # Nothing is dropped: every ticket and every residual is still in the HTML,
    # folded or not.
    residuals = board.get("residuals", [])
    missing_residuals = [r.get("artifact") for r in residuals
                         if r.get("artifact") and r.get("artifact") not in html]
    check("every residual artifact is still on the page", not missing_residuals,
          ("%d residuals, missing: %s" % (len(residuals), ", ".join(missing_residuals[:4])))
          if missing_residuals else "%d residuals" % len(residuals))

    # The page must not open with a wall of rows.
    opened = re.sub(r'<details class="fold"(?![^>]*\sopen)[^>]*>.*?</details>', "", html, flags=re.S)
    open_rows = opened.count("<tr>")
    open_items = opened.count("<li>")
    check("the board opens with a readable number of rows", open_rows <= 40 and open_items <= 40,
          "%d row(s) and %d list item(s) visible on open" % (open_rows, open_items))

    # A residual's verdict is its own verdict line, not a sentence ABOUT verdicts.
    bad_verdicts = [r.get("artifact") for r in residuals
                    if "VERDICT:" in (r.get("verdict") or "")
                    or (r.get("verdict") or "").strip().startswith("`")]
    check("a residual's verdict is read from its own verdict line", not bad_verdicts,
          "; ".join(bad_verdicts[:3]) if bad_verdicts else "%d residual(s)" % len(residuals))

    # 6. the tracker page reaches the board, and the board is served over HTTP
    if not args.skip_http:
        base = "http://%s:%d" % (args.bind, args.port)
        try:
            status, body = http_get(base + "/next-board/")
            check("board is served over HTTP", status == 200 and "Fleet live board" in body,
                  "%s /next-board/ -> %d" % (base, status))
        except Exception as exc:
            check("board is served over HTTP", False, "%s: %s" % (base, exc))
        try:
            status, body = http_get(base + "/")
            has_link = ("next-board" in body and ("fm-live-board-link" in body
                                                  or "LIVE FLEET BOARD" in body))
            check("tracker page carries the one-click link to the live board",
                  status == 200 and has_link, "%s / -> %d" % (base, status))
            check("tracker page still serves the vendored board UI",
                  status == 200 and "Fleet ticket dashboard" in body)
        except Exception as exc:
            check("tracker page carries the one-click link to the live board", False, str(exc))

    print("")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default="/root/agent-work/deightonllm-firstmate")
    parser.add_argument("--publish-dir", default=None)
    parser.add_argument("--serve-root", default="/root/tracker-view")
    parser.add_argument("--max-age-minutes", type=int, default=30)
    parser.add_argument("--port", type=int, default=8477)
    parser.add_argument("--bind", default="100.117.47.27")
    parser.add_argument("--skip-http", action="store_true")
    args = parser.parse_args()

    # The rendered sections are checked against fixtures first: they do not depend on
    # the live board, so a broken renderer is reported even when the board is missing.
    run_render_checks()
    run_live_checks(args)

    print("")
    if FAILURES:
        print("REGRESSION CHECK: FAIL (%d of %d checks failed)" % (len(FAILURES), len(CHECKS)))
        for failure in FAILURES:
            print("  - %s" % failure)
        return 1
    print("REGRESSION CHECK: PASS (%d checks)" % len(CHECKS))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
