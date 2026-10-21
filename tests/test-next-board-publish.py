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
    carry the one-click link to it.

usage: test-next-board-publish.py [--repo PATH] [--publish-dir DIR] [--serve-root DIR]
                                   [--max-age-minutes N] [--port N] [--bind ADDR]
"""
import argparse
import datetime as dt
import json
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

QUEUE_BOARD_REL = "data/campaign-dashboard-20261015/board.md"
QUEUE_RECORD_RE = re.compile(
    r"^<!-- ticket-intake sha256=[0-9a-f]{64} sequence=([0-9]{4}) area=[^ ]+ priority=(P[012]) slug=([a-z0-9-]+) -->$",
    re.M,
)

FAILURES = []
CHECKS = []


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

    repo = pathlib.Path(args.repo).resolve()
    publish = pathlib.Path(args.publish_dir) if args.publish_dir else repo / "data" / "next-board-publish"

    # 1. the board exists at all
    index = publish / "index.html"
    board_json_path = publish / "next-board.json"
    board_md = publish / "NEXT-BOARD.md"
    ok = index.is_file() and board_json_path.is_file() and board_md.is_file()
    if not check("published board exists", ok, str(publish)):
        print("\n%s" % ("; ".join(FAILURES)))
        return 1

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
    if FAILURES:
        print("REGRESSION CHECK: FAIL (%d of %d checks failed)" % (len(FAILURES), len(CHECKS)))
        for failure in FAILURES:
            print("  - %s" % failure)
        return 1
    print("REGRESSION CHECK: PASS (%d checks)" % len(CHECKS))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
