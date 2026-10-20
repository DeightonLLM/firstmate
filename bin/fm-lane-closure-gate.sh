#!/usr/bin/env bash
# fm-lane-closure-gate.sh - fail closed when a lane is claimed closed without a verifiable artifact.
#
# Requirements & Contract:
# 1. Authority: a lane is closed only when its artifact exists on disk and carries
#    the verdict the programme configuration requires. A dispatch, a plan, a status
#    line, or an agent's own claim is never evidence of closure.
# 2. Fails closed: a lane marked closed whose artifact is missing, empty, or verdictless
#    is a VIOLATION and exits non-zero. An unreadable manifest is a VIOLATION, never
#    a silent pass.
# 3. Honest states: a lane still dispatched is reported OPEN, which is a normal state
#    and not an error, unless --strict is requested.
# 4. The manifest is the durable programme configuration and is the single source of
#    the lane list, the artifact paths, and the required verdict.
# 5. Never touches an artifact. Read-only.
#
# Usage:
#   fm-lane-closure-gate.sh [--manifest <path>] [--lane <id>] [--strict] [--home <path>]
#
# Environment:
#   FM_HOME                      home that owns the programme configuration
#   FM_LANE_MANIFEST             explicit manifest path, overrides the default
#
# Exit codes:
#   0 - no violation, and every checked lane is closed when --strict is set
#   1 - violation: a closed lane has no verifiable artifact, or the manifest is unusable
#   2 - usage error
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"

MANIFEST=""
LANE=""
HOME_OVERRIDE=""
STRICT=0

usage() {
  printf 'Usage: %s [--manifest <path>] [--lane <id>] [--home <path>] [--strict]\n' "$(basename "$0")"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      MANIFEST="$2"
      shift 2
      ;;
    --lane)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      LANE="$2"
      shift 2
      ;;
    --home)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      HOME_OVERRIDE="$2"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$MANIFEST" ]; then
  MANIFEST="${FM_LANE_MANIFEST:-$FM_HOME/data/core-remediation/lanes.json}"
fi

if [ ! -f "$MANIFEST" ]; then
  printf 'VIOLATION: lane manifest not found: %s\n' "$MANIFEST" >&2
  exit 1
fi

# The manifest owns the programme, so its own home owns the artifact paths it declares.
# The manifest lives at <home>/data/<programme>/lanes.json, so the home is the part before
# the data/ component. An explicit --home wins, and FM_HOME is the fallback.
case "$MANIFEST" in
  */data/*) MANIFEST_HOME="${MANIFEST%%/data/*}" ;;
  *) MANIFEST_HOME="$FM_HOME" ;;
esac
if [ -n "$HOME_OVERRIDE" ]; then
  MANIFEST_HOME="$HOME_OVERRIDE"
fi

python3 - "$MANIFEST" "$MANIFEST_HOME" "$LANE" "$STRICT" <<'PY'
import json
import os
import sys

manifest_path, home, only_lane, strict = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"

try:
    with open(manifest_path, encoding="utf-8") as handle:
        manifest = json.load(handle)
except Exception as exc:
    print(f"VIOLATION: lane manifest is unreadable: {exc}", file=sys.stderr)
    sys.exit(1)

lanes = manifest.get("lanes")
if not isinstance(lanes, list) or not lanes:
    print("VIOLATION: lane manifest declares no lanes", file=sys.stderr)
    sys.exit(1)

violations = []
open_lanes = []

print(f"programme: {manifest.get('programme', 'unknown')}  manifest: {manifest_path}")
print(f"{'lane':<34} {'state':<10} {'verdict':<12} artifact")
print("-" * 100)

for lane in lanes:
    lane_id = str(lane.get("id", "?"))
    if only_lane and lane_id != only_lane:
        continue
    artifact_rel = str(lane.get("artifact", ""))
    artifact = artifact_rel if os.path.isabs(artifact_rel) else os.path.join(home, artifact_rel)
    claimed = str(lane.get("status", "open"))
    required = str(lane.get("verdict_prefix", "VERDICT:"))

    verdict = "none"
    exists = os.path.isfile(artifact)
    if exists:
        try:
            with open(artifact, encoding="utf-8", errors="replace") as handle:
                body = handle.read()
        except Exception:
            body = ""
        for line in body.splitlines():
            if line.strip().startswith(required):
                verdict = line.strip()[len(required):].strip().split(".")[0][:10]
                break
        if not body.strip():
            verdict = "empty"

    if claimed == "closed" and (not exists or verdict in ("none", "empty")):
        state = "VIOLATION"
        detail = "closed without a verifiable artifact" if not exists else "closed without a verdict"
        violations.append(f"{lane_id}: {detail} ({artifact})")
    elif exists and verdict not in ("none", "empty"):
        state = "closed" if claimed == "closed" else "artifact"
    else:
        state = "open"
        open_lanes.append(lane_id)

    shown = artifact_rel or "(none)"
    print(f"{lane_id:<34} {state:<10} {verdict:<12} {shown}")

if only_lane and not any(str(l.get("id")) == only_lane for l in lanes):
    print(f"VIOLATION: lane not found in manifest: {only_lane}", file=sys.stderr)
    sys.exit(1)

print()
for note in violations:
    print(f"VIOLATION: {note}", file=sys.stderr)

if violations:
    sys.exit(1)
if strict and open_lanes:
    print(f"VIOLATION: strict mode, still open: {', '.join(open_lanes)}", file=sys.stderr)
    sys.exit(1)
if open_lanes:
    print(f"open lanes (not yet closed): {', '.join(open_lanes)}")
sys.exit(0)
PY
exit $?
