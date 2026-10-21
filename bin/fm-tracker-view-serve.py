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
import socketserver
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

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
