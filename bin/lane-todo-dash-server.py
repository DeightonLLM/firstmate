#!/usr/bin/env python3
"""Tailnet-only HTTP adapter for lane-todo-dash.sh's existing generator."""

from __future__ import annotations

import ipaddress
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlsplit


MAX_BODY = 16_384
MAX_COMMENT = 8_000
MAX_TICKET = 200


def tailscale_ipv4() -> str:
    result = subprocess.run(
        ["tailscale", "ip", "-4"],
        check=True,
        capture_output=True,
        text=True,
        timeout=5,
    )
    addresses = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if len(addresses) != 1:
        raise RuntimeError("tailscale ip -4 must return exactly one IPv4 address")
    address = ipaddress.ip_address(addresses[0])
    if address.version != 4:
        raise RuntimeError("tailscale ip -4 did not return an IPv4 address")
    return str(address)


def feedback_directory(generator: Path) -> Path:
    repo_root = generator.resolve().parent.parent
    home = Path(os.environ.get("FM_HOME") or os.environ.get("FM_ROOT_OVERRIDE") or repo_root)
    state = Path(os.environ.get("FM_STATE_OVERRIDE") or (home / "state")).resolve()
    directory = state / "dash-feedback"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    if directory.resolve().parent != state:
        raise RuntimeError("feedback directory resolves outside the configured state directory")
    return directory


def clean_text(value: str, limit: int) -> str:
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    value = "".join(character for character in value if character in "\n\t" or ord(character) >= 32)
    return value.strip()[:limit]


def write_feedback(directory: Path, ticket: str, comment: str) -> tuple[str, str]:
    ticket = clean_text(ticket, MAX_TICKET).replace("\n", " ")
    comment = clean_text(comment, MAX_COMMENT)
    if not ticket or not comment:
        raise ValueError("ticket reference and comment are required")
    now = datetime.now(timezone.utc).replace(microsecond=0)
    timestamp = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    filename_time = now.strftime("%Y%m%dT%H%M%SZ")
    slug = re.sub(r"[^a-z0-9]+", "-", ticket.lower()).strip("-")[:64] or "feedback"
    quoted_comment = "\n".join("> " + line if line else ">" for line in comment.split("\n"))
    document = (
        "# Dashboard feedback\n\n"
        f"- Timestamp: {timestamp}\n"
        f"- Ticket: {ticket}\n\n"
        "## Comment\n\n"
        f"{quoted_comment}\n"
    )
    suffix = 0
    while True:
        extra = "" if suffix == 0 else f"-{suffix}"
        path = directory / f"{filename_time}-{slug}{extra}.md"
        try:
            descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            suffix += 1
            continue
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as output:
            output.write(document)
        return path.name, timestamp


def render(generator: Path) -> bytes:
    descriptor, filename = tempfile.mkstemp(prefix="lane-todo-dash-", suffix=".html")
    os.close(descriptor)
    try:
        result = subprocess.run(
            ["bash", str(generator), filename],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip() or "dashboard generation failed")
        return Path(filename).read_bytes()
    finally:
        Path(filename).unlink(missing_ok=True)


class DashboardHandler(BaseHTTPRequestHandler):
    generator: Path
    inbox: Path
    origin: str

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def send_body(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; "
            "connect-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
        )
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if urlsplit(self.path).path not in ("/", "/index.html"):
            self.send_error(404)
            return
        try:
            page = render(self.generator)
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            self.send_body(500, f"Dashboard generation failed: {error}\n".encode(), "text/plain; charset=utf-8")
            return
        self.send_body(200, page, "text/html; charset=utf-8")

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        if urlsplit(self.path).path != "/feedback":
            self.send_error(404)
            return
        origin = self.headers.get("Origin")
        if origin != self.origin:
            self.send_error(403, "Cross-origin feedback is not accepted")
            return
        content_type = self.headers.get_content_type()
        if content_type != "application/x-www-form-urlencoded":
            self.send_error(415, "Use an HTML form submission")
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_error(400, "Invalid content length")
            return
        if length <= 0 or length > MAX_BODY:
            self.send_error(413 if length > MAX_BODY else 400, "Feedback body is empty or too large")
            return
        fields = parse_qs(self.rfile.read(length).decode("utf-8", errors="replace"), keep_blank_values=True)
        ticket = fields.get("ticket", [""])[0]
        comment = fields.get("comment", [""])[0]
        try:
            filename, timestamp = write_feedback(self.inbox, ticket, comment)
        except ValueError as error:
            self.send_error(400, str(error))
            return
        except OSError as error:
            self.send_error(500, f"Could not save feedback: {error}")
            return
        self.send_body(201, f"Saved {filename} at {timestamp}.".encode(), "text/plain; charset=utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        print("internal error: generator path missing", file=sys.stderr)
        return 2
    generator = Path(sys.argv[1]).resolve()
    try:
        address = tailscale_ipv4()
        port = int(os.environ.get("LANE_TODO_DASH_PORT", "8765"))
        if not 1 <= port <= 65535:
            raise ValueError("port must be between 1 and 65535")
        inbox = feedback_directory(generator)
        server = ThreadingHTTPServer((address, port), DashboardHandler)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print(f"serve refused: {error}", file=sys.stderr)
        return 1
    DashboardHandler.generator = generator
    DashboardHandler.inbox = inbox
    DashboardHandler.origin = f"http://{address}:{port}"
    print(f"Serving dashboard at {DashboardHandler.origin}/", flush=True)
    print(f"Feedback inbox: {inbox}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
