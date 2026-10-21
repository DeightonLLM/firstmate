#!/usr/bin/env python3
"""
test-tracker-view-serve.py — the contract check for the tracker view server.

Two things are checked here, and both are load-bearing.

1. The GET path is unchanged. The tracker page the Captain opens is a vendored
   artifact; the serving layer may only add the one-click link bar to it, and nothing
   else. The check compares the served bytes with the artifact's own bytes plus
   exactly that banner, so an accidental change to the serving path fails here rather
   than in the Captain's browser. The board's own directory must also stay undecorated.

2. The board's own form works end to end. A POST to /next-board/feedback (or to the
   /feedback alias) with a ticket and a comment is saved durably in the contract's
   document shape, with mode 0600, and the agent is woken. Every refusal - cross
   origin, wrong content type, over-sized body, blank comment, over-long ticket or
   comment, unknown endpoint - is proven by a check, and a refusal never writes a file.
   A message whose wake cannot be raised is still saved, and the answer says so.

Non-interactive. It exits 0 when everything holds and 1 when something does not. It
binds ONE ephemeral port on the loopback interface, and its server is stopped before
the script exits.

usage: test-tracker-view-serve.py [--keep-temp]
"""
import argparse
import http.client
import importlib.util
import json
import os
import pathlib
import re
import shutil
import stat
import sys
import tempfile

REPO = pathlib.Path(__file__).resolve().parent.parent
SERVER = REPO / "bin" / "fm-tracker-view-serve.py"

MAX_BODY = 16384
MAX_COMMENT = 8000
MAX_TICKET = 200

CHECKS = []
FAILURES = []


def check(name, ok, detail=""):
    ok = bool(ok)
    CHECKS.append((name, ok, detail))
    if not ok:
        FAILURES.append("%s%s" % (name, (" — " + detail) if detail else ""))
    print("%s %s%s" % ("PASS" if ok else "FAIL", name, (" — " + detail) if detail else ""))
    return ok


def load_server_module():
    spec = importlib.util.spec_from_file_location("fm_tracker_view_serve", str(SERVER))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def request(port, method, path, body=None, headers=None):
    """One HTTP request. Returns (status, headers, body bytes)."""
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=15)
    try:
        connection.request(method, path, body=body, headers=headers or {})
        response = connection.getresponse()
        payload = response.read()
        return response.status, dict(response.getheaders()), payload
    finally:
        connection.close()


def form_body(fields):
    from urllib.parse import urlencode
    return urlencode(fields).encode("utf-8")


def feedback_files(state_dir):
    directory = pathlib.Path(state_dir) / "next-board-feedback"
    if not directory.is_dir():
        return []
    return sorted(path for path in directory.iterdir() if path.is_file())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--keep-temp", action="store_true")
    args = parser.parse_args()

    module = load_server_module()
    temp = pathlib.Path(tempfile.mkdtemp(prefix="fm-tracker-view-test."))
    root = temp / "tracker-view"
    state = temp / "state"
    root.mkdir(parents=True)
    state.mkdir(parents=True)

    # The served artifact: a vendored page with no links of its own.
    artifact = root / "index.html"
    original = (b"<!doctype html>\n<html><head><title>tracker</title></head>\n"
                b"<body>\n<div id=\"ticket-dashboard\">the vendored artifact</div>\n</body>\n</html>\n")
    artifact.write_bytes(original)

    # The board lives behind a symlink in the served tree, and is not decorated.
    board = root / "next-board"
    board.mkdir()
    (board / "index.html").write_bytes(b"<!doctype html>\n<html><body>live board</body></html>\n")

    # A stand-in for the wake script another lane writes: it records the path it was
    # handed, so the test can prove the wake was really raised.
    wake_log = temp / "wake.log"
    wake_script = temp / "fm-next-board-feedback.sh"
    wake_script.write_text(
        "#!/usr/bin/env bash\nprintf '%s\\n' \"$1\" >> \"$FM_TEST_WAKE_LOG\"\nexit 0\n",
        encoding="utf-8",
    )
    wake_script.chmod(0o755)

    saved_env = {key: os.environ.get(key) for key in
                 ("FM_STATE_OVERRIDE", "FM_NEXT_BOARD_FEEDBACK_SCRIPT", "FM_TEST_WAKE_LOG",
                  "FM_HOME", "FM_ROOT_OVERRIDE", "FM_ROOT", "STATE")}
    os.environ["FM_STATE_OVERRIDE"] = str(state)
    os.environ["FM_NEXT_BOARD_FEEDBACK_SCRIPT"] = str(wake_script)
    os.environ["FM_TEST_WAKE_LOG"] = str(wake_log)

    server = None
    try:
        handler = lambda *a, **k: module.Handler(*a, directory=str(root), **k)
        server = module.Server(("127.0.0.1", 0), handler)
        port = server.server_address[1]
        import threading
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        check("test server bound a high unused loopback port",
              port > 1024, "port %d" % port)

        origin = "http://127.0.0.1:%d" % port

        # --- 1. the GET path is unchanged ---------------------------------------
        status, headers, body = request(port, "GET", "/")
        banner = module.build_banner(str(root), "next-board").encode("utf-8")
        index = original.lower().rfind(b"</body>")
        expected = original[:index] + banner + original[index:]
        check("GET / answers 200", status == 200, "status %d" % status)
        check("GET / serves the artifact plus exactly the injected link bar",
              body == expected,
              "served %d bytes, expected %d" % (len(body), len(expected)))
        check("GET / injects the live-board link bar",
              b'id="fm-live-board-link"' in body and b'href="/next-board/"' in body)
        check("GET / keeps the artifact's own bytes",
              b'id="ticket-dashboard"' in body and b"</html>" in body)
        check("GET / is served as HTML", "text/html" in headers.get("Content-Type", ""),
              headers.get("Content-Type", ""))

        status, _, board_body = request(port, "GET", "/next-board/")
        check("GET /next-board/ is not decorated with a link to itself",
              status == 200 and b"fm-live-board-link" not in board_body,
              "status %d" % status)

        # --- 2. a good POST is accepted, saved and wakes the agent --------------
        before = feedback_files(state)
        status, _, payload = request(
            port, "POST", "/next-board/feedback",
            body=form_body({"ticket": "0042-some-slug", "comment": "first line\nsecond line"}),
            headers={"Content-Type": "application/x-www-form-urlencoded", "Origin": origin},
        )
        check("POST /next-board/feedback answers 201", status == 201, "status %d" % status)
        try:
            answer = json.loads(payload.decode("utf-8"))
        except Exception as error:
            answer = {}
            check("POST answer is JSON", False, str(error))
        check("POST answer carries the saved filename and the timestamp",
              bool(answer.get("file")) and bool(answer.get("timestamp")),
              json.dumps(answer))
        check("POST answer reports the wake was raised",
              answer.get("wake") == "raised", str(answer.get("wake")))

        saved = feedback_files(state)
        check("the message was saved as exactly one new file",
              len(saved) == len(before) + 1,
              "%d file(s) before, %d after" % (len(before), len(saved)))
        if saved:
            path = saved[-1]
            name = path.name
            check("the saved filename carries the UTC stamp and the ticket slug",
                  bool(re.match(r"^\d{8}T\d{6}Z-0042-some-slug(-\d+)?\.md$", name)), name)
            mode = stat.S_IMODE(path.stat().st_mode)
            check("the saved file is mode 0600", mode == 0o600, "mode %o" % mode)
            timestamp = answer.get("timestamp", "")
            check("the filename stamp and the document timestamp agree",
                  timestamp.replace("-", "").replace(":", "") in name,
                  "%s vs %s" % (timestamp, name))
            expected_document = (
                "# Board feedback\n\n"
                "- Timestamp: %s\n"
                "- Ticket: 0042-some-slug\n"
                "- Source: form\n\n"
                "## Comment\n\n"
                "> first line\n"
                "> second line\n" % timestamp
            )
            check("the saved document is exactly the contract's shape",
                  path.read_text(encoding="utf-8") == expected_document,
                  repr(path.read_text(encoding="utf-8")))
        if wake_log.exists():
            woken = wake_log.read_text(encoding="utf-8").strip().splitlines()
            check("the wake was raised with the saved path",
                  bool(woken) and saved and woken[-1] == str(saved[-1]),
                  woken[-1] if woken else "no wake recorded")
        else:
            check("the wake was raised with the saved path", False, "no wake recorded")

        # the /feedback alias works too
        status, _, payload = request(
            port, "POST", "/feedback",
            body=form_body({"ticket": "0043-alias", "comment": "via the alias"}),
            headers={"Content-Type": "application/x-www-form-urlencoded", "Origin": origin},
        )
        check("POST /feedback answers 201", status == 201, "status %d" % status)

        # a client that sends no Origin is allowed: browsers always send one
        status, _, payload = request(
            port, "POST", "/next-board/feedback",
            body=form_body({"ticket": "0044-noorigin", "comment": "no origin header"}),
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        check("a POST without an Origin header is accepted", status == 201, "status %d" % status)

        # --- 3. every refusal ----------------------------------------------------
        def refuse(name, path_, expected_status, body_bytes=None, headers_=None):
            before = feedback_files(state)
            status, _, payload = request(port, "POST", path_,
                                         body=body_bytes, headers=headers_ or {})
            after = feedback_files(state)
            detail = ""
            try:
                reason = json.loads(payload.decode("utf-8")).get("error", "")
                detail = reason
            except Exception:
                detail = payload[:120].decode("utf-8", "replace")
            check("%s is refused with %d" % (name, expected_status),
                  status == expected_status, "status %d (%s)" % (status, detail))
            check("%s writes no file" % name, before == after,
                  "%d before, %d after" % (len(before), len(after)))
            check("%s answers with a one-line reason, not a traceback" % name,
                  bool(detail) and "\n" not in detail and "Traceback" not in payload.decode("utf-8", "replace"),
                  detail)

        refuse("a cross-origin Origin", "/next-board/feedback", 403,
               form_body({"ticket": "0100", "comment": "from elsewhere"}),
               {"Content-Type": "application/x-www-form-urlencoded",
                "Origin": "http://evil.example"})

        refuse("a mismatched Origin port", "/next-board/feedback", 403,
               form_body({"ticket": "0101", "comment": "from another port"}),
               {"Content-Type": "application/x-www-form-urlencoded",
                "Origin": "http://127.0.0.1:1"})

        refuse("a wrong content type", "/next-board/feedback", 415,
               json.dumps({"ticket": "0102", "comment": "not a form"}).encode("utf-8"),
               {"Content-Type": "application/json"})

        refuse("a body over the cap", "/next-board/feedback", 413,
               form_body({"ticket": "0103", "comment": "x" * (MAX_BODY + 10)}),
               {"Content-Type": "application/x-www-form-urlencoded", "Origin": origin})

        refuse("a blank comment", "/next-board/feedback", 400,
               form_body({"ticket": "0104", "comment": ""}),
               {"Content-Type": "application/x-www-form-urlencoded", "Origin": origin})

        refuse("a comment that is only whitespace", "/next-board/feedback", 400,
               form_body({"ticket": "0105", "comment": "   \n  "}),
               {"Content-Type": "application/x-www-form-urlencoded", "Origin": origin})

        refuse("an over-long ticket", "/next-board/feedback", 400,
               form_body({"ticket": "T" * (MAX_TICKET + 1), "comment": "too long a ticket"}),
               {"Content-Type": "application/x-www-form-urlencoded", "Origin": origin})

        refuse("an over-long comment", "/next-board/feedback", 400,
               form_body({"ticket": "0106", "comment": "c" * (MAX_COMMENT + 1)}),
               {"Content-Type": "application/x-www-form-urlencoded", "Origin": origin})

        refuse("an unknown endpoint", "/next-board/nope", 404,
               form_body({"ticket": "0107", "comment": "nowhere"}),
               {"Content-Type": "application/x-www-form-urlencoded", "Origin": origin})

        # --- 4. a message whose wake cannot be raised is still saved -------------
        missing_wake = temp / "there-is-no-such-wake-script.sh"
        os.environ["FM_NEXT_BOARD_FEEDBACK_SCRIPT"] = str(missing_wake)
        before = feedback_files(state)
        status, _, payload = request(
            port, "POST", "/next-board/feedback",
            body=form_body({"ticket": "0108-nowake", "comment": "the wake script is missing"}),
            headers={"Content-Type": "application/x-www-form-urlencoded", "Origin": origin},
        )
        after = feedback_files(state)
        try:
            answer = json.loads(payload.decode("utf-8"))
        except Exception:
            answer = {}
        check("a missing wake script still answers 201", status == 201, "status %d" % status)
        check("a missing wake script still saves the message",
              len(after) == len(before) + 1,
              "%d before, %d after" % (len(before), len(after)))
        check("a missing wake script is reported, not swallowed",
              answer.get("wake") == "not_raised" and "wake could not be raised" in answer.get("message", ""),
              str(answer.get("message", "")))
        os.environ["FM_NEXT_BOARD_FEEDBACK_SCRIPT"] = str(wake_script)

        # --- 5. the GET path still works after all of that ----------------------
        status, _, body = request(port, "GET", "/")
        check("GET / is unchanged after the POST work",
              status == 200 and body == expected, "status %d" % status)

    finally:
        if server is not None:
            server.shutdown()
            server.server_close()
        for key, value in saved_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        if args.keep_temp:
            print("kept: %s" % temp)
        else:
            shutil.rmtree(temp, ignore_errors=True)

    print("")
    if FAILURES:
        print("CONTRACT CHECK: FAIL (%d of %d checks failed)" % (len(FAILURES), len(CHECKS)))
        for failure in FAILURES:
            print("  - %s" % failure)
        return 1
    print("CONTRACT CHECK: PASS (%d checks)" % len(CHECKS))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
