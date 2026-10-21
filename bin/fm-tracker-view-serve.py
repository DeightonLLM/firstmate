#!/usr/bin/env python3
"""
fm-tracker-view-serve.py — serve the Captain's tracker directory with ONE click to the live board.

Why this exists. The tracker page the Captain opens is a vendored Lavish build artifact: a
single self-contained HTML file with no <a> tags at all, served as a symlink from
/root/tracker-view/index.html. The artifact is read-only and must stay that way, so a link
to the live board cannot be written into it. The only place a link can honestly live is the
serving layer.

So this wrapper does exactly one thing more than `python3 -m http.server`: for HTML
responses it injects a small, fixed-position link bar pointing at the live board, and it
injects NOTHING else. The page's own bytes are never modified on disk; the artifact stays
read-only.

Failure behaviour is fail-open: if the board's metadata cannot be read, the banner says so
rather than inventing an age; if the injection itself cannot be performed, the original
bytes are served unchanged. A broken banner must never become a broken tracker.

usage: fm-tracker-view-serve.py --root DIR [--port 8477] [--bind ADDR] [--board-path next-board]
"""
import argparse
import datetime as dt
import html
import json
import os
import pathlib
import re
import socket
import socketserver
import subprocess
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

BANNER_CSS = (
    "position:fixed;left:12px;bottom:12px;z-index:2147483000;"
    "background:#1A1A1A;color:#fff;border:1px solid rgba(255,255,255,.16);"
    "border-radius:10px;padding:9px 13px;font:600 13px/1.35 Inter,system-ui,sans-serif;"
    "box-shadow:0 8px 26px rgba(0,0,0,.55);display:flex;align-items:center;gap:9px;"
    "max-width:min(92vw,420px)"
)
BANNER_LINK_CSS = "color:#BFE0F2;text-decoration:none;white-space:nowrap"
BANNER_META_CSS = "color:#A0A0A0;font-weight:400;font-size:11.5px"


def read_board_meta(root, board_path):
    """Read the publisher's own metadata. Never invent a value."""
    meta_path = pathlib.Path(root) / board_path / "published.json"
    try:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    except Exception:
        return None
    return meta if isinstance(meta, dict) else None


def age_text(meta):
    if not meta:
        return "age unknown"
    generated = meta.get("generated")
    if not generated:
        return "age unknown"
    try:
        stamp = dt.datetime.strptime(str(generated), "%Y-%m-%dT%H:%M:%SZ").replace(
            tzinfo=dt.timezone.utc)
    except ValueError:
        return "age unknown"
    seconds = int(dt.datetime.now(dt.timezone.utc).timestamp() - stamp.timestamp())
    if seconds < 0:
        return "just updated"
    if seconds < 60:
        return "updated %ds ago" % seconds
    if seconds < 3600:
        return "updated %dm ago" % (seconds // 60)
    return "updated %dh %dm ago" % (seconds // 3600, (seconds % 3600) // 60)


def build_banner(root, board_path):
    meta = read_board_meta(root, board_path)
    href = "/" + str(board_path).strip("/") + "/"
    return (
        '<div id="fm-live-board-link" style="%s">'
        '<a href="%s" style="%s">LIVE FLEET BOARD &rarr;</a>'
        '<span style="%s">%s</span>'
        "</div>" % (
            BANNER_CSS, html.escape(href, quote=True), BANNER_LINK_CSS,
            BANNER_META_CSS, html.escape(age_text(meta)))
    )


# --- the board's own inbound form (Contract B, section 3.2) -------------------------
#
# The board renders a form that POSTs to /next-board/feedback with a ticket and a
# comment. The message is saved durably under the home's state directory, and the agent
# is woken through bin/fm-next-board-feedback.sh, which owns the durable wake queue.
#
# Two rules hold here. A message that was accepted is never silently dropped: if the
# wake cannot be raised the message is still saved and the answer says so. And a refusal
# is always a status code and a one-line reason: the browser never sees a traceback.

MAX_BODY = 16384
MAX_COMMENT = 8000
MAX_TICKET = 200
FEEDBACK_DIRNAME = "next-board-feedback"
FEEDBACK_SOURCE = "form"
WAKE_SCRIPT_NAME = "fm-next-board-feedback.sh"

def resolve_home():
    """The firstmate home that owns this server's state.

    The tracked source lives at <home>/bin/; the runtime copy the systemd unit runs
    lives at <home>/data/next-board-publish/. The home is found by walking up to the
    directory that owns bin/fm-wake-lib.sh, so this copy and the wake library agree
    on where the wake queue and the feedback inbox live.
    """
    override = os.environ.get("FM_HOME") or os.environ.get("FM_ROOT_OVERRIDE")
    if override:
        return pathlib.Path(override).resolve()
    here = pathlib.Path(__file__).resolve().parent
    for candidate in (here,) + tuple(here.parents):
        if (candidate / "bin" / "fm-wake-lib.sh").is_file():
            return candidate
    return here.parent

def resolve_state_dir():
    """The state directory, resolved exactly as bin/fm-wake-lib.sh resolves it."""
    home = resolve_home()
    fm_root = os.environ.get("FM_ROOT_OVERRIDE") or os.environ.get("FM_ROOT") or str(home)
    fm_home = os.environ.get("FM_HOME") or os.environ.get("FM_ROOT_OVERRIDE") or fm_root
    state = os.environ.get("FM_STATE_OVERRIDE") or os.environ.get("STATE") or os.path.join(fm_home, "state")
    return pathlib.Path(state).resolve()

def feedback_directory():
    """The durable inbox for board feedback, inside the configured state directory."""
    state = resolve_state_dir()
    directory = state / FEEDBACK_DIRNAME
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    if directory.resolve().parent != state:
        raise RuntimeError("feedback directory resolves outside the configured state directory")
    return directory

def wake_script():
    """The script that appends the durable wake. Another lane writes it; it may be absent."""
    override = os.environ.get("FM_NEXT_BOARD_FEEDBACK_SCRIPT")
    if override:
        return pathlib.Path(override).expanduser()
    sibling = pathlib.Path(__file__).resolve().parent / WAKE_SCRIPT_NAME
    if sibling.is_file():
        return sibling
    return resolve_home() / "bin" / WAKE_SCRIPT_NAME

def clean_text(value):
    """Normalise line endings and drop control characters. Never silently truncates."""
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    return "".join(character for character in value
                   if character in "\n\t" or ord(character) >= 32).strip()

def slugify(value):
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")[:64]

def build_feedback_document(ticket, comment, timestamp):
    """The document shape the contract defines, exactly."""
    quoted = "\n".join("> " + line if line else ">" for line in comment.split("\n"))
    return (
        "# Board feedback\n\n"
        "- Timestamp: %s\n"
        "- Ticket: %s\n"
        "- Source: %s\n\n"
        "## Comment\n\n"
        "%s\n" % (timestamp, ticket, FEEDBACK_SOURCE, quoted)
    )

def write_feedback(directory, ticket, comment):
    """Write the message durably. Returns (filename, timestamp, path)."""
    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    timestamp = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    filename_time = now.strftime("%Y%m%dT%H%M%SZ")
    slug = slugify(ticket) or "feedback"
    document = build_feedback_document(ticket or "none", comment, timestamp)
    suffix = 0
    while True:
        name = "%s-%s%s.md" % (filename_time, slug, "" if suffix == 0 else "-%d" % suffix)
        path = directory / name
        try:
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            suffix += 1
            continue
        try:
            os.fchmod(descriptor, 0o600)
        except OSError:
            pass
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as output:
            output.write(document)
        return name, timestamp, path

def wake_agent(path):
    """Raise the durable wake. Returns (raised, detail). Never raises."""
    script = wake_script()
    if not script.is_file():
        return False, "wake script not found: %s" % script
    try:
        result = subprocess.run(
            ["bash", str(script), str(path)],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
            cwd=str(resolve_home()),
        )
    except (OSError, subprocess.SubprocessError) as error:
        return False, "wake could not be raised: %s" % error
    if result.returncode != 0:
        output = (result.stderr or result.stdout or "").strip().splitlines()
        return False, "wake script exited %d: %s" % (result.returncode,
                                                     output[-1] if output else "no output")
    return True, "wake raised"

class Handler(SimpleHTTPRequestHandler):
    server_version = "fm-tracker-view"
    board_path = "next-board"

    def _injectable(self):
        """True when this request resolves to an HTML file we may decorate."""
        path = self.translate_path(self.path)
        # Python 3.12's translate_path does NOT resolve the directory index - the base
        # class does that later inside send_head. A request for "/" therefore translates
        # to the directory itself, and the index has to be appended here.
        if os.path.isdir(path):
            path = os.path.join(path, "index.html")
        if not os.path.isfile(path):
            return None
        # The live board carries its own link back to the tracker page; do not decorate
        # the board with a link to itself.
        board_root = os.path.join(self.directory, self.board_path)
        try:
            if os.path.abspath(path).startswith(os.path.abspath(board_root) + os.sep):
                return None
        except (TypeError, ValueError):
            pass
        try:
            with open(path, "rb") as fh:
                head = fh.read(4096)
        except OSError:
            return None
        if b"<html" not in head.lower():
            return None
        return path

    def send_head(self):
        path = self._injectable()
        if path is None:
            return super().send_head()
        try:
            with open(path, "rb") as fh:
                body = fh.read()
            banner = build_banner(self.directory, self.board_path).encode("utf-8")
            lowered = body.lower()
            marker = b"</body>"
            index = lowered.rfind(marker)
            if index == -1:
                index = len(body)
                decorated = body + banner
            else:
                decorated = body[:index] + banner + body[index:]
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(decorated)))
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Last-Modified", self.date_time_string(
                os.stat(path).st_mtime))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(decorated)
            return None
        except Exception:
            # Fail open: any failure serves the original bytes.
            import traceback
            sys.stderr.write("fm-tracker-view: injection failed, serving original bytes\n")
            traceback.print_exc()
            return super().send_head()

    def log_message(self, fmt, *args):
        if os.environ.get("FM_TRACKER_VIEW_LOG"):
            sys.stderr.write("fm-tracker-view: " + (fmt % args) + "\n")

    # --- the board's own inbound form ------------------------------------------------

    def _feedback_paths(self):
        base = "/" + str(self.board_path).strip("/")
        return {base + "/feedback", "/feedback"}

    def _local_addresses(self):
        addresses = {"127.0.0.1", "::1"}
        try:
            for info in socket.getaddrinfo(socket.gethostname(), None):
                addresses.add(info[4][0])
        except OSError:
            pass
        return addresses

    def _resolves_to(self, host, address):
        try:
            resolved = {info[4][0] for info in socket.getaddrinfo(host, None)}
        except (socket.gaierror, UnicodeError, OSError):
            return False
        if address is None:
            return bool(resolved & self._local_addresses())
        return address in resolved

    def _origin_allowed(self, origin):
        """Same-origin only. An absent Origin is allowed: non-browser clients send none."""
        if not origin:
            return True
        extra = [item.strip() for item in
                 os.environ.get("FM_TRACKER_VIEW_ALLOWED_ORIGINS", "").split(",") if item.strip()]
        if origin in extra:
            return True
        try:
            parsed = urlsplit(origin)
            port = parsed.port
            host = parsed.hostname
        except ValueError:
            return False
        if parsed.scheme not in ("http", "https") or not host:
            return False
        host = host.lower()
        default_port = 443 if parsed.scheme == "https" else 80
        if port is None:
            port = default_port
        bound_host = str(self.server.server_address[0])
        bound_port = int(self.server.server_address[1])
        if port != bound_port and port != default_port:
            return False
        if bound_host not in ("", "0.0.0.0", "::", "[::]"):
            if host == bound_host.lower():
                return True
            return self._resolves_to(host, bound_host)
        # A wildcard bind still only accepts an origin that names this machine.
        return self._resolves_to(host, None)

    def _send_json(self, status, payload):
        body = (json.dumps(payload, sort_keys=True) + "\n").encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        try:
            self.wfile.write(body)
        except OSError:
            pass

    def _refuse(self, status, reason):
        reason = " ".join(str(reason).split())
        self._send_json(status, {"ok": False, "status": status, "error": reason})

    def do_POST(self):
        """The board's own form posts here. Contract B, section 3.2."""
        try:
            self._handle_feedback_post()
        except Exception as error:  # never a traceback to the client
            self._refuse(500, "The feedback could not be accepted: %s" % error)

    def _handle_feedback_post(self):
        if urlsplit(self.path).path not in self._feedback_paths():
            self._refuse(404, "No such endpoint")
            return
        if not self._origin_allowed(self.headers.get("Origin")):
            self._refuse(403, "Cross-origin feedback is not accepted")
            return
        if self.headers.get_content_type() != "application/x-www-form-urlencoded":
            self._refuse(415, "Use an HTML form submission")
            return
        raw_length = self.headers.get("Content-Length")
        try:
            length = int(raw_length) if raw_length is not None else -1
        except ValueError:
            self._refuse(400, "Invalid content length")
            return
        if length < 0:
            self._refuse(400, "Content-Length is required")
            return
        if length == 0:
            self._refuse(400, "Feedback body is empty")
            return
        if length > MAX_BODY:
            self._refuse(413, "Feedback body is larger than %d bytes" % MAX_BODY)
            return
        body = self.rfile.read(length)
        fields = parse_qs(body.decode("utf-8", errors="replace"), keep_blank_values=True)
        ticket = fields.get("ticket", [""])[0]
        comment = fields.get("comment", [""])[0]
        if len(ticket) > MAX_TICKET:
            self._refuse(400, "Ticket reference is longer than %d characters" % MAX_TICKET)
            return
        if len(comment) > MAX_COMMENT:
            self._refuse(400, "Comment is longer than %d characters" % MAX_COMMENT)
            return
        clean_ticket = clean_text(ticket).replace("\n", " ")
        clean_comment = clean_text(comment)
        if not clean_comment:
            self._refuse(400, "A comment is required")
            return
        try:
            directory = feedback_directory()
        except (OSError, RuntimeError) as error:
            self._refuse(500, "Could not prepare the feedback directory: %s" % error)
            return
        try:
            filename, timestamp, path = write_feedback(directory, clean_ticket, clean_comment)
        except OSError as error:
            self._refuse(500, "Could not save the feedback: %s" % error)
            return
        raised, detail = wake_agent(path)
        message = "Saved %s at %s." % (filename, timestamp)
        if not raised:
            message = "Saved %s at %s, but the wake could not be raised: %s" % (filename, timestamp, detail)
        self._send_json(201, {
            "ok": True,
            "file": filename,
            "timestamp": timestamp,
            "wake": "raised" if raised else "not_raised",
            "message": message,
        })


class Server(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--port", type=int, default=8477)
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--board-path", default="next-board")
    args = parser.parse_args()

    root = pathlib.Path(args.root).resolve()
    if not root.is_dir():
        sys.stderr.write("fm-tracker-view: root directory is unavailable: %s\n" % root)
        return 2
    Handler.board_path = args.board_path
    handler = lambda *a, **k: Handler(*a, directory=str(root), **k)
    with Server((args.bind, args.port), handler) as httpd:
        sys.stderr.write("fm-tracker-view: serving %s on %s:%d\n" % (root, args.bind, args.port))
        sys.stderr.flush()
        httpd.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
