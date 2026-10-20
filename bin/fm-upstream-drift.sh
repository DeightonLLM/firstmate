#!/usr/bin/env bash
# fm-upstream-drift.sh - read-only drift detector for the firstmate upstream.
#
# The upstream is the public firstmate repository at https://github.com/kunchenguid/firstmate.
# This repo is a fork of it, and its local docs/ tree is a MANUAL PORT of upstream docs/.
# A manual port goes stale by default, so this detector compares the two trees and
# reports, per file, whether the local copy is identical, divergent, missing locally,
# or local-only.
#
# Requirements & Contract:
# 1. Read-only. It never writes into docs/, never stages or commits anything, and
#    never adds or changes a remote. The self-guard below refuses to run when a
#    mutating version-control subcommand is ever introduced into this file.
# 2. No upstream remote is required. The default mode reads the public GitHub API.
#    The --upstream-dir mode compares against an already fetched upstream tree, so
#    the same comparison runs fully offline.
# 3. Honest numbers. A value the detector cannot determine is printed as unknown,
#    never as a fabricated count or byte size.
# 4. Bounded content. Upstream file content is read only for files that are not
#    already proven identical, and the number of content reads is capped by
#    --max-fetch. When the cap is reached the report says so.
# 5. Identical means identical. Equality is decided by the git blob digest of both
#    sides, so a same-size but different file is never reported as identical.
#
# Usage:
#   fm-upstream-drift.sh [--local-dir <path>] [--upstream-dir <path>]
#                         [--upstream-repo <owner/name>] [--upstream-ref <ref>]
#                         [--max-fetch <n>] [--tracked-only] [--quiet-summary]
#
# Environment:
#   FM_UPSTREAM_DRIFT_NO_GH   set to 1 to force the unauthenticated API path
#
# Exit codes:
#   0 - no drift
#   1 - drift detected
#   2 - usage error, or the comparison could not be performed
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SELF_DIR/$(basename "${BASH_SOURCE[0]}")"
ROOT="$(cd "$SELF_DIR/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'fm-upstream-drift.sh: python3 is required and was not found.\n' >&2
  exit 2
fi

export FM_UPSTREAM_DRIFT_SELF="$SELF"
export FM_UPSTREAM_DRIFT_ROOT="$ROOT"

exec python3 - "$@" <<'PY'
from __future__ import annotations

import base64
import difflib
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote

DEFAULT_REPO = "kunchenguid/firstmate"
DEFAULT_MAX_FETCH = 200
DOC_PREFIX = "docs/"
SKIP_DIRS = {".git", "__pycache__", ".no-mistakes"}
UNKNOWN = "unknown"
API_ROOT = "https://api.github.com/"
RAW_ROOT = "https://raw.githubusercontent.com/"

# The detector must stay read-only. These patterns are the mutating
# version-control subcommands it refuses to carry, so a future edit cannot
# introduce one without the self-guard failing the script outright.
MUTATING_VCS_PATTERNS = [
    r"\bgit\s+add\b",
    r"\bgit\s+am\b",
    r"\bgit\s+apply\b",
    r"\bgit\s+branch\b",
    r"\bgit\s+cherry-pick\b",
    r"\bgit\s+clean\b",
    r"\bgit\s+commit\b",
    r"\bgit\s+commit-tree\b",
    r"\bgit\s+config\b",
    r"\bgit\s+fetch\b",
    r"\bgit\s+gc\b",
    r"\bgit\s+merge\b",
    r"\bgit\s+notes\b",
    r"\bgit\s+pull\b",
    r"\bgit\s+push\b",
    r"\bgit\s+rebase\b",
    r"\bgit\s+repack\b",
    r"\bgit\s+reset\b",
    r"\bgit\s+restore\b",
    r"\bgit\s+revert\b",
    r"\bgit\s+rm\b",
    r"\bgit\s+stash\b",
    r"\bgit\s+switch\b",
    r"\bgit\s+tag\b",
    r"\bgit\s+update-ref\b",
    r"\bgit\s+worktree\b",
    r"\bgit\s+write-tree\b",
    r"\bgit\s+remote\s+add\b",
    r"\bgit\s+remote\s+rename\b",
    r"\bgit\s+remote\s+remove\b",
    r"\bgit\s+remote\s+set-url\b",
    r"\bgit\s+remote\s+prune\b",
    r"\bgit\s+remote\s+update\b",
]

SELF = Path(os.environ.get("FM_UPSTREAM_DRIFT_SELF", "")).resolve()
ROOT = Path(os.environ.get("FM_UPSTREAM_DRIFT_ROOT", str(SELF.parent.parent)))


def usage_text() -> str:
    try:
        lines = SELF.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return "Usage: fm-upstream-drift.sh [--local-dir <path>] [--upstream-dir <path>]"
    head = []
    for line in lines[1:]:
        if not line.startswith("#"):
            break
        head.append(line[2:] if line.startswith("# ") else line[1:])
    return "\n".join(head).rstrip()


def die_usage(message: str) -> None:
    sys.stderr.write("fm-upstream-drift.sh: %s\n" % message)
    sys.stderr.write(usage_text() + "\n")
    sys.exit(2)


def die_runtime(message: str) -> None:
    sys.stderr.write("fm-upstream-drift.sh: %s\n" % message)
    print("SUMMARY: total=unknown identical=unknown divergent=unknown missing=unknown "
          "local_only=unknown upstream_files=unknown local_files=unknown")
    print("VERDICT: UNKNOWN")
    sys.exit(2)


def self_guard() -> None:
    """Refuse to run when a mutating version-control subcommand is present."""
    try:
        source = SELF.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        die_usage("cannot read this script for the read-only self-guard: %s" % exc)
    for pattern in MUTATING_VCS_PATTERNS:
        found = re.search(pattern, source)
        if found:
            die_usage("the read-only self-guard refused to run: this script contains '%s'"
                      % found.group(0))


def git_blob_digest(data: bytes) -> str:
    """The git blob object id of the given bytes."""
    header = b"blob %d\0" % len(data)
    return hashlib.sha1(header + data).hexdigest()


def take_value(argv: list, index: int, name: str):
    if index + 1 >= len(argv):
        die_usage("%s requires a value" % name)
    return argv[index + 1], index + 2


def parse_args(argv: list) -> dict:
    opts = {
        "local_dir": None,
        "upstream_dir": None,
        "upstream_repo": DEFAULT_REPO,
        "upstream_ref": None,
        "max_fetch": DEFAULT_MAX_FETCH,
        "tracked_only": False,
        "quiet_summary": False,
    }
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg in ("-h", "--help"):
            print(usage_text())
            sys.exit(0)
        if arg == "--local-dir":
            opts["local_dir"], index = take_value(argv, index, arg)
            continue
        if arg == "--upstream-dir":
            opts["upstream_dir"], index = take_value(argv, index, arg)
            continue
        if arg == "--upstream-repo":
            opts["upstream_repo"], index = take_value(argv, index, arg)
            continue
        if arg == "--upstream-ref":
            opts["upstream_ref"], index = take_value(argv, index, arg)
            continue
        if arg == "--max-fetch":
            value, index = take_value(argv, index, arg)
            if not value.isdigit():
                die_usage("--max-fetch must be a non-negative integer, got '%s'" % value)
            opts["max_fetch"] = int(value)
            continue
        if arg == "--tracked-only":
            opts["tracked_only"] = True
            index += 1
            continue
        if arg == "--quiet-summary":
            opts["quiet_summary"] = True
            index += 1
            continue
        die_usage("unknown argument: %s" % arg)
    if opts["upstream_repo"].count("/") != 1 or opts["upstream_repo"].startswith("/"):
        die_usage("--upstream-repo must look like owner/name, got '%s'" % opts["upstream_repo"])
    return opts


def run_tool(command: list, timeout: int = 120):
    try:
        return subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=timeout, check=False)
    except (OSError, subprocess.SubprocessError):
        return None


_GH_READY: "None" = None


def gh_is_ready() -> bool:
    """True when an authenticated GitHub client is available."""
    global _GH_READY
    if _GH_READY is None:
        _GH_READY = False
        if os.environ.get("FM_UPSTREAM_DRIFT_NO_GH", "").strip() in ("", "0"):
            if shutil.which("gh"):
                proc = run_tool(["gh", "auth", "status"], timeout=60)
                _GH_READY = proc is not None and proc.returncode == 0
    return bool(_GH_READY)


def api_json(endpoint: str):
    """Read one GitHub API endpoint, preferring an authenticated client."""
    errors = []
    if gh_is_ready():
        proc = run_tool(["gh", "api", endpoint])
        if proc is not None and proc.returncode == 0:
            try:
                return json.loads(proc.stdout.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                errors.append("the authenticated client returned unreadable JSON: %s" % exc)
        elif proc is not None:
            errors.append("the authenticated client failed: %s"
                          % proc.stderr.decode("utf-8", "replace").strip())
    if shutil.which("curl"):
        url = API_ROOT + endpoint
        proc = run_tool(["curl", "-fsSL", "-H", "Accept: application/vnd.github+json", url])
        if proc is not None and proc.returncode == 0:
            try:
                return json.loads(proc.stdout.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError) as exc:
                errors.append("the plain client returned unreadable JSON: %s" % exc)
        elif proc is not None:
            errors.append("the plain client failed for %s: %s"
                          % (endpoint, proc.stderr.decode("utf-8", "replace").strip()))
    detail = "; ".join(errors) if errors else "no API client is available"
    raise RuntimeError("cannot read the upstream API: %s" % detail)


def resolve_ref(repo: str) -> str:
    payload = api_json("repos/%s" % repo)
    if not isinstance(payload, dict):
        raise RuntimeError("the upstream repository metadata is not usable")
    ref = payload.get("default_branch")
    if not isinstance(ref, str) or not ref:
        raise RuntimeError("the upstream repository has no usable default branch")
    return ref


def upstream_tree_from_api(repo: str, ref: str):
    """Return {relative_path: {size, sha}} for the upstream docs/ tree."""
    payload = api_json("repos/%s/git/trees/%s?recursive=1" % (repo, quote(ref, safe="")))
    if not isinstance(payload, dict):
        raise RuntimeError("the upstream tree payload is not usable")
    entries = {}
    for node in payload.get("tree", []):
        if not isinstance(node, dict):
            continue
        if node.get("type") != "blob":
            continue
        path = node.get("path")
        if not isinstance(path, str) or not path.startswith(DOC_PREFIX):
            continue
        rel = path[len(DOC_PREFIX):]
        if not rel:
            continue
        size = node.get("size")
        sha = node.get("sha")
        entries[rel] = {
            "size": size if isinstance(size, int) else None,
            "sha": sha if isinstance(sha, str) else None,
        }
    truncated = bool(payload.get("truncated"))
    return entries, truncated


def upstream_tree_from_dir(root: Path):
    """Return {relative_path: {size, sha, path}} for a local upstream docs/ tree."""
    entries = {}
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        dirnames[:] = sorted(name for name in dirnames if name not in SKIP_DIRS)
        for name in sorted(filenames):
            full = Path(dirpath) / name
            rel = full.relative_to(root).as_posix()
            try:
                data = full.read_bytes()
            except OSError:
                entries[rel] = {"size": None, "sha": None, "path": full}
                continue
            entries[rel] = {"size": len(data), "sha": git_blob_digest(data), "path": full}
    return entries


def local_tree_from_dir(root: Path, tracked_only: bool):
    """Return {relative_path: {size, sha, path}} for the local docs/ tree."""
    allowed = None
    if tracked_only:
        allowed = tracked_relpaths(root)
        if allowed is None:
            print("NOTE: --tracked-only was requested but the local tree is not inside a "
                  "version-control work tree, so the whole filesystem was compared.")
    entries = {}
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        dirnames[:] = sorted(name for name in dirnames if name not in SKIP_DIRS)
        for name in sorted(filenames):
            full = Path(dirpath) / name
            rel = full.relative_to(root).as_posix()
            if allowed is not None and rel not in allowed:
                continue
            try:
                data = full.read_bytes()
            except OSError:
                entries[rel] = {"size": None, "sha": None, "path": full}
                continue
            entries[rel] = {"size": len(data), "sha": git_blob_digest(data), "path": full}
    return entries


def tracked_relpaths(local_dir: Path):
    """The relative paths under local_dir that the enclosing work tree tracks."""
    proc = run_tool(["git", "-C", str(local_dir), "rev-parse", "--show-toplevel"], timeout=60)
    if proc is None or proc.returncode != 0:
        return None
    top = proc.stdout.decode("utf-8", "replace").strip()
    if not top:
        return None
    try:
        prefix = os.path.relpath(str(local_dir.resolve()), os.path.realpath(top))
    except ValueError:
        return None
    listing = run_tool(["git", "-C", top, "ls-files", "-z", "--", prefix], timeout=120)
    if listing is None or listing.returncode != 0:
        return None
    names = [name for name in listing.stdout.decode("utf-8", "replace").split("\0") if name]
    allowed = set()
    for name in names:
        if name == prefix:
            continue
        rel = os.path.relpath(name, prefix)
        if rel.startswith(".."):
            continue
        allowed.add(Path(rel).as_posix())
    return allowed


def fetch_upstream_bytes(rel: str, sha, ref: str, repo: str):
    """Read one upstream file body, or None when it cannot be read."""
    if sha and gh_is_ready():
        payload = api_json("repos/%s/git/blobs/%s" % (repo, sha))
        if isinstance(payload, dict) and payload.get("encoding") == "base64":
            content = payload.get("content")
            if isinstance(content, str):
                try:
                    return base64.b64decode(content)
                except (ValueError, TypeError):
                    pass
    if shutil.which("curl"):
        url = "%s%s/%s/%s%s" % (RAW_ROOT, repo, quote(ref, safe=""), DOC_PREFIX, quote(rel, safe="/"))
        proc = run_tool(["curl", "-fsSL", url])
        if proc is not None and proc.returncode == 0:
            return proc.stdout
    return None


def diff_line_counts(local_bytes: bytes, upstream_bytes: bytes):
    local_lines = local_bytes.decode("utf-8", "replace").splitlines()
    upstream_lines = upstream_bytes.decode("utf-8", "replace").splitlines()
    added = 0
    removed = 0
    for line in difflib.unified_diff(local_lines, upstream_lines, lineterm="", n=0):
        if line.startswith("+++") or line.startswith("---"):
            continue
        if line.startswith("+"):
            added += 1
        elif line.startswith("-"):
            removed += 1
    return added, removed


def size_text(value) -> str:
    return UNKNOWN if value is None else str(value)


def read_local_body(path: Path):
    try:
        return path.read_bytes()
    except OSError:
        return None


def classify(local_entry: dict, upstream_entry: dict) -> str:
    local_size = local_entry.get("size")
    upstream_size = upstream_entry.get("size")
    if local_size is None or upstream_size is None:
        return UNKNOWN
    if upstream_size > local_size:
        return "upstream-newer"
    if upstream_size < local_size:
        return "upstream-smaller"
    return "content-divergent"


def compare(local_entries: dict, upstream_entries: dict):
    """Split the common paths into identical, divergent, and content-to-verify."""
    identical = []
    divergent = []
    unverified = []
    for rel in sorted(set(local_entries) & set(upstream_entries)):
        local_entry = local_entries[rel]
        upstream_entry = upstream_entries[rel]
        local_sha = local_entry.get("sha")
        upstream_sha = upstream_entry.get("sha")
        if local_sha and upstream_sha:
            if local_sha == upstream_sha:
                identical.append(rel)
            else:
                divergent.append(rel)
            continue
        local_size = local_entry.get("size")
        upstream_size = upstream_entry.get("size")
        if local_size is not None and upstream_size is not None and local_size == upstream_size:
            unverified.append(rel)
            continue
        divergent.append(rel)
    missing = sorted(set(upstream_entries) - set(local_entries))
    local_only = sorted(set(local_entries) - set(upstream_entries))
    return identical, divergent, unverified, missing, local_only


def main() -> int:
    self_guard()
    opts = parse_args(sys.argv[1:])

    local_dir = Path(opts["local_dir"]).expanduser() if opts["local_dir"] else ROOT / "docs"
    local_dir = local_dir.resolve()
    if not local_dir.is_dir():
        die_usage("the local docs directory does not exist: %s" % local_dir)

    repo = opts["upstream_repo"]
    mode = "github-api"
    truncated = False
    ref = opts["upstream_ref"] or ""

    if opts["upstream_dir"]:
        mode = "local-dir"
        upstream_root = Path(opts["upstream_dir"]).expanduser()
        if not upstream_root.is_dir():
            die_usage("the upstream directory does not exist: %s" % upstream_root)
        if (upstream_root / "docs").is_dir():
            upstream_root = upstream_root / "docs"
        upstream_entries = upstream_tree_from_dir(upstream_root)
        ref = ref or "local"
        source_desc = "local upstream tree (%d files) at %s" % (len(upstream_entries), upstream_root)
    else:
        if not ref:
            ref = resolve_ref(repo)
        upstream_entries, truncated = upstream_tree_from_api(repo, ref)
        source_desc = "github tree api for %s@%s (%d files)" % (repo, ref, len(upstream_entries))

    local_entries = local_tree_from_dir(local_dir, opts["tracked_only"])
    identical, divergent, unverified, missing, local_only = compare(local_entries, upstream_entries)

    budget = opts["max_fetch"]
    fetched = 0
    capped = 0
    details = {}
    for rel in list(unverified) + list(divergent):
        if budget <= 0:
            capped += 1
            details[rel] = "content=not-compared(fetch-cap)"
            continue
        budget -= 1
        fetched += 1
        upstream_bytes = None
        if mode == "local-dir":
            path = upstream_entries[rel].get("path")
            if path is not None:
                upstream_bytes = read_local_body(path)
        else:
            upstream_bytes = fetch_upstream_bytes(rel, upstream_entries[rel].get("sha"), ref, repo)
        local_bytes = read_local_body(local_entries[rel]["path"])
        if upstream_bytes is None or local_bytes is None:
            details[rel] = "content=unavailable"
            continue
        if rel in unverified:
            if upstream_bytes == local_bytes:
                identical.append(rel)
                unverified.remove(rel)
                details.pop(rel, None)
                continue
            divergent.append(rel)
            unverified.remove(rel)
        added, removed = diff_line_counts(local_bytes, upstream_bytes)
        details[rel] = "content=compared +%d/-%d lines" % (added, removed)

    # A file whose digests could not be compared and whose content could not be
    # read is never silently dropped: it stays in the report as divergent.
    for rel in list(unverified):
        divergent.append(rel)

    identical.sort()
    divergent.sort()
    missing.sort()
    local_only.sort()
    total = len(identical) + len(divergent) + len(missing) + len(local_only)
    drift = len(divergent) + len(missing)
    verdict = "DRIFT" if drift > 0 else "NO-DRIFT"

    quiet = opts["quiet_summary"]
    print("UPSTREAM-DRIFT: repo=%s ref=%s mode=%s" % (repo, ref, mode))
    print("LOCAL-DIR: %s" % local_dir)
    print("UPSTREAM-SOURCE: %s" % source_desc)
    if truncated:
        print("NOTE: the upstream tree listing is truncated, so the comparison covers only "
              "the listed files.")
    if not quiet:
        print("IDENTICAL (%d):" % len(identical))
        for rel in identical:
            print("  %s%s  bytes=%s"
                  % (DOC_PREFIX, rel, size_text(local_entries[rel].get("size"))))
        print("DIVERGENT (%d):" % len(divergent))
        for rel in divergent:
            local_entry = local_entries[rel]
            upstream_entry = upstream_entries[rel]
            print("  %s%s  local=%s upstream=%s kind=%s %s"
                  % (DOC_PREFIX, rel,
                     size_text(local_entry.get("size")),
                     size_text(upstream_entry.get("size")),
                     classify(local_entry, upstream_entry),
                     details.get(rel, "content=not-compared")))
        print("MISSING-LOCALLY (%d):" % len(missing))
        for rel in missing:
            print("  %s%s  upstream=%s"
                  % (DOC_PREFIX, rel, size_text(upstream_entries[rel].get("size"))))
        print("LOCAL-ONLY (%d):" % len(local_only))
        for rel in local_only:
            print("  %s%s  local=%s"
                  % (DOC_PREFIX, rel, size_text(local_entries[rel].get("size"))))
    print("CONTENT-FETCH: used=%d cap=%d capped_files=%d" % (fetched, opts["max_fetch"], capped))
    print("SUMMARY: total=%d identical=%d divergent=%d missing=%d local_only=%d "
          "upstream_files=%d local_files=%d"
          % (total, len(identical), len(divergent), len(missing), len(local_only),
             len(upstream_entries), len(local_entries)))
    print("DRIFT-BASIS: divergent+missing; local-only files are house additions and are "
          "not counted as drift")
    print("VERDICT: %s" % verdict)
    return 1 if drift > 0 else 0


try:
    sys.exit(main())
except RuntimeError as exc:
    die_runtime(str(exc))
except KeyboardInterrupt:
    sys.exit(130)
PY
