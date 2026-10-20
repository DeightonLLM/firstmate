#!/usr/bin/env bash
# Check a crewmate brief for required write targets outside its declared boundary.
# Usage: bash bin/fm-brief-preflight.sh <brief-path>
# The check also requires an explicit prohibition on editing existing warehouse reports.
set -euo pipefail

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
  sed -n '2,4p' "$0" | sed 's/^# //'
  exit 0
fi
if [[ $# -ne 1 || ! -f $1 ]]; then
  printf 'usage error: provide one existing brief file path\n' >&2
  exit 2
fi

python3 - "$1" <<'PY'
import posixpath
import re
import sys
from pathlib import Path

brief_path = Path(sys.argv[1]).resolve()
text = brief_path.read_text(encoding="utf-8")
lines = text.splitlines()
errors = []

boundary_line = next((line for line in lines if line.startswith("WRITE BOUNDARY:")), None)
if boundary_line is None:
    errors.append("missing WRITE BOUNDARY declaration")
    boundary = None
else:
    match = re.fullmatch(r"WRITE BOUNDARY:\s*(.+?)\. Read-only everywhere else\.", boundary_line.strip())
    if not match:
        errors.append("WRITE BOUNDARY must use: WRITE BOUNDARY: <directory>. Read-only everywhere else.")
        boundary = None
    else:
        boundary = match.group(1).strip()

forbidden = any(
    line.startswith("STRICTLY FORBIDDEN:")
    and re.search(r"modifying,?\s*updating,?\s*appending to or deleting ANY existing file in warehouse/reports/", line, re.I)
    and re.search(r"INDEX\.md", line, re.I)
    for line in lines
)
if not forbidden:
    errors.append("missing STRICTLY FORBIDDEN prohibition on editing existing warehouse/reports/ files (including INDEX.md)")

additional_paths = []
for line in lines:
    match = re.search(r"IN ADDITION AUTHORI[ZS]ED:\s*(.+)$", line)
    if match:
        clause = match.group(1)
        paths = re.findall(r"(?:/[^\s<>]+|(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+)", clause)
        if not re.search(r"create ONE new file", clause, re.I) or not re.search(r"byte-identical copy of the report", clause, re.I):
            errors.append("IN ADDITION AUTHORISED clause must authorize one new file as a byte-identical copy of the report")
        additional_paths.extend(paths)

def normalized(path):
    path = path.rstrip(".,;:)")
    if not path.startswith("/"):
        path = posixpath.join(str(brief_path.parent), path)
    return posixpath.normpath(path)

def within(path, directory):
    return path == directory or path.startswith(directory.rstrip("/") + "/")

required = []
for line in lines:
    candidates = []
    # Explicit report destinations, copy destinations, warehouse report files,
    # and authoring directories are all write requirements even if phrased differently.
    candidates.extend(re.findall(r"\b(?:report(?:\s+(?:at|to|path))?|copy\s+to)\s+((?:/|(?:[\w.-]+/))[\w./-]+)", line, re.I))
    candidates.extend(re.findall(r"((?:/[^\s<>]+|(?:[\w.-]+/)+[\w.-]+))", line))
    for target in candidates:
        target = target.rstrip(".,;:)")
        if target.endswith("/report.md") or "warehouse/reports/" in target or re.search(r"\breport\b", line, re.I) and target.endswith(".md"):
            required.append(target)
        if re.search(r"authoring\s+directory", line, re.I) and target not in {boundary, *additional_paths}:
            required.append(target)

# Preserve order while avoiding duplicate reports caused by overlapping matchers.
required = list(dict.fromkeys(required))
if boundary is not None:
    boundary_abs = normalized(boundary)
    additional_abs = [normalized(path) for path in additional_paths]
    for target in required:
        target_abs = normalized(target)
        if not within(target_abs, boundary_abs) and target_abs not in additional_abs:
            errors.append(f"required write target outside WRITE BOUNDARY and not explicitly authorised: {target}")

if errors:
    for error in errors:
        print(f"FAIL: {error}", file=sys.stderr)
    sys.exit(1)
print(f"PASS: brief write targets are covered by boundary or explicit additional authorisation ({len(required)} target(s))")
PY
