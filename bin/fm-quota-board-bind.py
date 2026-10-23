#!/usr/bin/env python3
"""fm-quota-board-bind.py - bind a quota-board snapshot into a board HTML file.

The band must work from a `file://` URL with no network and no fetch, so the
snapshot is inlined into the board rather than loaded at runtime. This binder:

  * replaces ONLY the JSON payload inside
    `<script id="quota-board-snapshot" type="application/json">`, located
    through the `HD2_QUOTA_BAND_SNAPSHOT_BEGIN` anchor;
  * escapes `<`, `>` and `&` so the payload can never close the script block;
  * is idempotent - re-binding identical data rewrites nothing;
  * refuses to write when the anchor, the script element or the snapshot is
    missing or unreadable (fail closed, the board is left untouched);
  * backs the board up before it changes any bytes.
"""
from __future__ import annotations

import argparse
import json
import os
import pathlib
import shutil
import sys
import tempfile
from datetime import datetime, timezone

ANCHOR_BEGIN = "<!-- HD2_QUOTA_BAND_SNAPSHOT_BEGIN -->"
ANCHOR_END = "<!-- HD2_QUOTA_BAND_SNAPSHOT_END -->"
SCRIPT_OPEN = '<script id="quota-board-snapshot" type="application/json">'
SNAPSHOT_SCHEMA = "hd2-quota-board-snapshot/v1"
BACKUP_TAG = "quotabind"


def backup_path(target):
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return "%s.bak-%s-%s" % (target, BACKUP_TAG, stamp)


def escaped_payload(document):
    """Compact JSON that can never terminate the script element."""
    text = json.dumps(document, separators=(",", ":"), ensure_ascii=False, sort_keys=True)
    return (
        text.replace("&", "\\u0026")
        .replace("<", "\\u003c")
        .replace(">", "\\u003e")
        .replace("\u2028", "\\u2028")
        .replace("\u2029", "\\u2029")
    )


def fail(message):
    """Fail closed: exit 2, the board is never touched."""
    sys.stderr.write("bind: FAIL %s\n" % message)
    raise SystemExit(2)


def locate_payload(html):
    """Return (start, end) offsets of the JSON payload inside the script block."""
    anchor = html.find(ANCHOR_BEGIN)
    if anchor < 0:
        fail("the board has no %s anchor" % ANCHOR_BEGIN)
    if ANCHOR_END not in html[anchor:]:
        fail("the board has no %s anchor" % ANCHOR_END)
    open_at = html.find(SCRIPT_OPEN, anchor)
    if open_at < 0:
        fail("the board has no %s element" % SCRIPT_OPEN)
    body_at = open_at + len(SCRIPT_OPEN)
    close_at = html.find("</script>", body_at)
    if close_at < 0:
        fail("the snapshot script element is not closed")
    return body_at, close_at


def write_atomic(path, text):
    path = pathlib.Path(path)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".quota-bind-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--snapshot", required=True, help="snapshot JSON produced by fm-quota-board-snapshot.py")
    parser.add_argument("--html", default=None, help="board HTML (default: <repo root>/unified-board.html)")
    parser.add_argument("--check", action="store_true", help="verify only; never write")
    parser.add_argument("--no-backup", action="store_true", help="skip the pre-write backup (not recommended)")
    parser.add_argument("--home", default=None, help="firstmate home (default: repo root)")
    args = parser.parse_args(argv)

    here = pathlib.Path(__file__).resolve().parents[1]
    home = pathlib.Path(args.home).resolve() if args.home else here
    html_path = pathlib.Path(args.html) if args.html else home / "unified-board.html"

    snapshot_path = pathlib.Path(args.snapshot)
    try:
        document = json.loads(snapshot_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        fail("the snapshot is unreadable: %s" % exc)
    if not isinstance(document, dict) or document.get("schema") != SNAPSHOT_SCHEMA:
        fail("the snapshot is not %s" % SNAPSHOT_SCHEMA)

    if not html_path.is_file():
        fail("the board is missing: %s" % html_path)
    html = html_path.read_text(encoding="utf-8")
    start, end = locate_payload(html)

    current = html[start:end].strip()
    payload = escaped_payload(document)
    updated = html[:start] + "\n    " + payload + "\n    " + html[end:]

    if current == payload:
        print("bind: already current (%s)" % html_path)
        return 0

    if args.check:
        print("bind: CHECK the embedded snapshot differs from %s" % snapshot_path)
        return 3

    if not args.no_backup:
        backup = backup_path(html_path)
        shutil.copy2(str(html_path), backup)
        print("bind: backup %s" % backup)

    write_atomic(html_path, updated)
    print("bind: wrote %s (%d bytes of snapshot payload)" % (html_path, len(payload)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
