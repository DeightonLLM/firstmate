#!/usr/bin/env python3
"""core-100-fixture-server.py - a controlled HTTP surface for the CORE-100 gate test.

The gate is a production gate: it normally talks to the live Lead Engine, the
live storefront and the retired second origin. This server stands in for all
three so the gate can be exercised end to end against a fixture, never against
production.

    core-100-fixture-server.py <docroot> <baseline-file> <mode> <port>

modes
  main     the Lead Engine fixture: the route table and the expected statuses
           come from the gate baseline file, the bodies come from the docroot.
           A path that is not in the route table is answered with the landing
           page, exactly like the nginx try_files fallback the gate must
           detect.
  retired  a second origin that is NOT the Lead Engine: it answers 410 with a
           plain body and never the landing marker.
  agents   the agent dashboard origin: it answers 301.

The baseline file is the same file the gate reads, so the fixture's expected
statuses and the fixture's served statuses cannot drift apart.
"""

import http.server
import os
import socketserver
import sys

CONTENT_TYPES = {
    ".js": "application/javascript",
    ".css": "text/css",
    ".webp": "image/webp",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".txt": "text/plain",
    ".xml": "text/xml",
    ".json": "application/json",
    ".html": "text/html; charset=UTF-8",
    ".php": "text/html; charset=UTF-8",
}


def load_baseline(path):
    routes = {}
    surfaces = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if parts[0] == "route":
                routes[parts[1]] = int(parts[2])
            elif parts[0] == "surface":
                surfaces[parts[1]] = parts[2:]
    return routes, surfaces


def main():
    if len(sys.argv) != 5:
        print(__doc__, file=sys.stderr)
        return 2
    docroot, baseline_file, mode, port = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
    routes, surfaces = load_baseline(baseline_file)
    landing = os.path.join(docroot, "index.php")

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *_args):
            pass

        def _send(self, code, body=b"", ctype="text/html; charset=UTF-8"):
            if isinstance(body, str):
                body = body.encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(body)

        def _serve_file(self, path):
            full = os.path.join(docroot, path.lstrip("/"))
            if not os.path.isfile(full):
                return False
            with open(full, "rb") as handle:
                body = handle.read()
            ext = os.path.splitext(full)[1].lower()
            self._send(200, body, CONTENT_TYPES.get(ext, "application/octet-stream"))
            return True

        def do_GET(self):
            path = self.path.split("?")[0]
            if mode == "retired":
                self._send(410, "this build is retired\n")
                return
            if mode == "agents":
                self.send_response(301)
                self.send_header("Location", "/dashboard")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            if path == "/" or path == "/index.php":
                if os.path.isfile(landing):
                    with open(landing, "rb") as handle:
                        self._send(200, handle.read(), CONTENT_TYPES[".php"])
                else:
                    self._send(404, "no landing page\n")
                return
            if path in routes:
                status = routes[path]
                if status == 200 and self._serve_file(path):
                    return
                self._send(status, "fixture status %d for %s\n" % (status, path))
                return
            # nginx serves an existing static file directly; only a missing
            # path falls through to the index.php try_files fallback. The gate
            # must detect exactly that fallback.
            if self._serve_file(path):
                return
            if os.path.isfile(landing):
                with open(landing, "rb") as handle:
                    self._send(200, handle.read(), CONTENT_TYPES[".php"])
            else:
                self._send(404, "not found\n")

        do_HEAD = do_GET

    class Server(socketserver.ThreadingTCPServer):
        allow_reuse_address = True
        daemon_threads = True

    with Server(("127.0.0.1", port), Handler) as httpd:
        httpd.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
