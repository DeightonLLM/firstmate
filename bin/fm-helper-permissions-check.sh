#!/usr/bin/env bash
# bin/fm-helper-permissions-check.sh - Drift detection between tracked helper
# permission rules and live host containment configurations.
#
# Audits the live containment files:
#   - /root/.config/lean-ctx/config.toml (shell_allowlist_extra)
#   - /root/.config/lean-ctx-contabo/config.toml (shell_allowlist_extra, exclude_paths)
#   - /root/.minimax/permission.json (version, read_roots, write_roots)
# against the canonical tracked rule definition in docs/helper-permissions.json.
#
# Flags:
#   --tracked PATH          Override path to tracked rules JSON
#   --lean-ctx PATH         Override path to live lean-ctx config.toml
#   --lean-ctx-contabo PATH Override path to live lean-ctx-contabo config.toml
#   --minimax PATH          Override path to live minimax permission.json
#   --quiet                 Suppress non-error output
#   --help                  Show this help text
#
# Exit codes:
#   0 - Tracked rule and live configurations match exactly (no drift)
#   1 - Drift detected between tracked rule and live configurations
#   2 - Configuration file missing or unparseable
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TRACKED_DEF="$ROOT/docs/helper-permissions.json"
LEAN_CTX_CONF="/root/.config/lean-ctx/config.toml"
LEAN_CTX_CONTABO_CONF="/root/.config/lean-ctx-contabo/config.toml"
MINIMAX_CONF="/root/.minimax/permission.json"
QUIET=0

usage() {
  cat <<'EOF'
Usage: fm-helper-permissions-check.sh [OPTIONS]

Audit helper permission rules against live containment configuration files.

Options:
  --tracked PATH          Path to tracked helper-permissions.json
  --lean-ctx PATH         Path to lean-ctx config.toml
  --lean-ctx-contabo PATH Path to lean-ctx-contabo config.toml
  --minimax PATH          Path to minimax permission.json
  --quiet                 Suppress informational output
  --help                  Show this help message
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tracked)
      TRACKED_DEF="$2"
      shift 2
      ;;
    --lean-ctx)
      LEAN_CTX_CONF="$2"
      shift 2
      ;;
    --lean-ctx-contabo)
      LEAN_CTX_CONTABO_CONF="$2"
      shift 2
      ;;
    --minimax)
      MINIMAX_CONF="$2"
      shift 2
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ ! -f "$TRACKED_DEF" ]; then
  printf 'Error: Tracked definition file not found: %s\n' "$TRACKED_DEF" >&2
  exit 2
fi

# Run the python auditor to inspect TOML and JSON structures
python3 - "$TRACKED_DEF" "$LEAN_CTX_CONF" "$LEAN_CTX_CONTABO_CONF" "$MINIMAX_CONF" "$QUIET" <<'PY'
import sys
import json
from pathlib import Path

try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib
    except ImportError:
        print("Error: Python tomllib/tomli module required", file=sys.stderr)
        sys.exit(2)

tracked_path = Path(sys.argv[1])
lean_ctx_path = Path(sys.argv[2])
contabo_path = Path(sys.argv[3])
minimax_path = Path(sys.argv[4])
quiet = sys.argv[5] == "1"

try:
    with open(tracked_path, "r", encoding="utf-8") as f:
        tracked = json.load(f)
except Exception as e:
    print(f"Error reading tracked definition {tracked_path}: {e}", file=sys.stderr)
    sys.exit(2)

drifts = []

def log(msg):
    if not quiet:
        print(msg)

# 1. Check lean-ctx config
#
# A tracked live file that is absent is a hard MISSING drift when the tracked
# definition declares it required on this host (the default). A profile the
# tracked definition declares NOT required - the plain lean-ctx profile, which
# was superseded on 2026-10-17 in favour of lean-ctx-contabo - is declared
# unavailable instead of being dropped or mislabeled. Declaring it unavailable
# is never a silent pass: the safety invariant in step 4 still runs over the
# tracked definition, and the profile's rules stay documented.
def profile_required(section):
    return bool(tracked.get(section, {}).get("required", True))


# 1. Check lean-ctx config
if not lean_ctx_path.exists():
    if profile_required("lean_ctx"):
        drifts.append(f"MISSING: lean-ctx config not found at {lean_ctx_path}")
    else:
        log(f"UNAVAILABLE: lean-ctx config not installed on this host ({lean_ctx_path})")
else:
    try:
        with open(lean_ctx_path, "rb") as f:
            live_lc = tomllib.load(f)
        live_extra = sorted(live_lc.get("shell_allowlist_extra", []))
        tracked_extra = sorted(tracked.get("lean_ctx", {}).get("shell_allowlist_extra", []))
        if live_extra != tracked_extra:
            missing_in_tracked = set(live_extra) - set(tracked_extra)
            extra_in_tracked = set(tracked_extra) - set(live_extra)
            diff_parts = []
            if missing_in_tracked:
                diff_parts.append(f"live has additional: {sorted(missing_in_tracked)}")
            if extra_in_tracked:
                diff_parts.append(f"tracked expects: {sorted(extra_in_tracked)}")
            drifts.append(f"DRIFT: lean-ctx shell_allowlist_extra mismatch ({'; '.join(diff_parts)})")
        else:
            log("OK: lean-ctx shell_allowlist_extra matches tracked definition")
    except Exception as e:
        drifts.append(f"ERROR: failed parsing {lean_ctx_path}: {e}")

# 2. Check lean-ctx-contabo config
if not contabo_path.exists():
    if profile_required("lean_ctx_contabo"):
        drifts.append(f"MISSING: lean-ctx-contabo config not found at {contabo_path}")
    else:
        log(f"UNAVAILABLE: lean-ctx-contabo config not installed on this host ({contabo_path})")
else:
    try:
        with open(contabo_path, "rb") as f:
            live_cb = tomllib.load(f)
        live_cb_extra = sorted(live_cb.get("shell_allowlist_extra", []))
        tracked_cb_extra = sorted(tracked.get("lean_ctx_contabo", {}).get("shell_allowlist_extra", []))
        if live_cb_extra != tracked_cb_extra:
            missing_cb = set(live_cb_extra) - set(tracked_cb_extra)
            extra_cb = set(tracked_cb_extra) - set(live_cb_extra)
            diff_parts = []
            if missing_cb:
                diff_parts.append(f"live has additional: {sorted(missing_cb)}")
            if extra_cb:
                diff_parts.append(f"tracked expects: {sorted(extra_cb)}")
            drifts.append(f"DRIFT: lean-ctx-contabo shell_allowlist_extra mismatch ({'; '.join(diff_parts)})")
        else:
            log("OK: lean-ctx-contabo shell_allowlist_extra matches tracked definition")

        live_cb_excl = sorted(live_cb.get("exclude_paths", []))
        tracked_cb_excl = sorted(tracked.get("lean_ctx_contabo", {}).get("exclude_paths", []))
        if live_cb_excl != tracked_cb_excl:
            drifts.append(f"DRIFT: lean-ctx-contabo exclude_paths mismatch (live={live_cb_excl}, tracked={tracked_cb_excl})")
        else:
            log("OK: lean-ctx-contabo exclude_paths matches tracked definition")
    except Exception as e:
        drifts.append(f"ERROR: failed parsing {contabo_path}: {e}")

# 3. Check minimax permission.json
#
# live_read_roots / live_write_roots are hoisted so the safety invariant in
# step 4 can inspect the live roots even when the file is absent.
live_read_roots = []
live_write_roots = []
if not minimax_path.exists():
    if profile_required("minimax"):
        drifts.append(f"MISSING: minimax permission file not found at {minimax_path}")
    else:
        log(f"UNAVAILABLE: minimax permission file not installed on this host ({minimax_path})")
else:
    try:
        with open(minimax_path, "r", encoding="utf-8") as f:
            live_mm = json.load(f)
        live_read_roots = []
        live_write_roots = []
        for item in live_mm.get("allow", []):
            m = item.get("matcher", {})
            if m.get("kind") == "path":
                p = m.get("pattern")
                actions = m.get("actions", [])
                if "read" in actions and p not in live_read_roots:
                    live_read_roots.append(p)
                if "write" in actions and p not in live_write_roots:
                    live_write_roots.append(p)
        live_read_roots.sort()
        live_write_roots.sort()

        tracked_read_roots = sorted(tracked.get("minimax", {}).get("read_roots", []))
        tracked_write_roots = sorted(tracked.get("minimax", {}).get("write_roots", []))

        if live_read_roots != tracked_read_roots:
            missing_reads = set(live_read_roots) - set(tracked_read_roots)
            extra_reads = set(tracked_read_roots) - set(live_read_roots)
            diff_parts = []
            if missing_reads:
                diff_parts.append(f"live has additional: {sorted(missing_reads)}")
            if extra_reads:
                diff_parts.append(f"tracked expects: {sorted(extra_reads)}")
            drifts.append(f"DRIFT: minimax read_roots mismatch ({'; '.join(diff_parts)})")
        else:
            log("OK: minimax read_roots matches tracked definition")

        if live_write_roots != tracked_write_roots:
            missing_writes = set(live_write_roots) - set(tracked_write_roots)
            extra_writes = set(tracked_write_roots) - set(live_write_roots)
            diff_parts = []
            if missing_writes:
                diff_parts.append(f"live has additional: {sorted(missing_writes)}")
            if extra_writes:
                diff_parts.append(f"tracked expects: {sorted(extra_writes)}")
            drifts.append(f"DRIFT: minimax write_roots mismatch ({'; '.join(diff_parts)})")
        else:
            log("OK: minimax write_roots matches tracked definition")
    except Exception as e:
        drifts.append(f"ERROR: failed parsing {minimax_path}: {e}")

# 4. Safety invariant check: assert no secret paths admitted in tracked read_roots or allowlists.
#
# The prohibited secret roots apply to write_roots exactly as they do to
# read_roots: a blanket write to a secret root is never admissible. This is
# the narrow route's refusal edge - it names the exact offending rule instead
# of widening the tracked definition to match an unsafe live store.
secret_patterns = ["/root/.ssh", "/root/.secrets", "/root/secret-quarantine", "/root/.codex/auth.json", "/root/.bash_history"]
tracked_all_reads = tracked.get("minimax", {}).get("read_roots", [])
tracked_all_writes = tracked.get("minimax", {}).get("write_roots", [])


def secret_root_of(pattern):
    """Return the prohibited secret root a path pattern sits under, or None.

    /root/.ssh is the one documented exception: the tracked rules admit
    /root/.ssh/** for READ so known_hosts and ssh config can be inspected, and
    only the private-key paths themselves are refused. A WRITE to /root/.ssh is
    never admissible and is refused below like any other secret root.
    """
    for sec in secret_patterns:
        if sec == "/root/.ssh":
            continue
        if pattern == sec or pattern == f"{sec}/**" or pattern.startswith(f"{sec}/"):
            return sec
    return None


PRIVATE_KEY_PATHS = ("/root/.ssh/id_rsa", "/root/.ssh/id_ed25519")

for sec in secret_patterns:
    if sec == "/root/.ssh":
        # /root/.ssh/** is present for known_hosts / config reading, but private keys must not be explicit
        if "/root/.ssh/id_rsa" in tracked_all_reads or "/root/.ssh/id_ed25519" in tracked_all_reads:
            drifts.append(f"SAFETY HAZARD: tracked rules admit private key path: {sec}")
        if "/root/.ssh/id_rsa" in tracked_all_writes or "/root/.ssh/id_ed25519" in tracked_all_writes:
            drifts.append(f"SAFETY HAZARD: tracked rules admit private key write path: {sec}")
    elif sec in tracked_all_reads or f"{sec}/**" in tracked_all_reads:
        drifts.append(f"SAFETY HAZARD: tracked rules admit forbidden secret root: {sec}")

for pattern in tracked_all_writes:
    if pattern in PRIVATE_KEY_PATHS:
        drifts.append(f"SAFETY HAZARD: tracked rules admit private key write path: {pattern}")
        continue
    sec = secret_root_of(pattern)
    if sec:
        drifts.append(f"SAFETY HAZARD: tracked rules admit forbidden secret root for write: {pattern} (under {sec})")
    elif pattern == "/root/.ssh/**" or pattern.startswith("/root/.ssh/"):
        drifts.append(f"SAFETY HAZARD: tracked rules admit forbidden secret root for write: {pattern} (under /root/.ssh)")

for pattern in live_write_roots:
    if pattern in PRIVATE_KEY_PATHS:
        drifts.append(f"SAFETY HAZARD: live rules admit private key write path: {pattern}")
        continue
    sec = secret_root_of(pattern)
    if sec:
        drifts.append(f"SAFETY HAZARD: live rules admit forbidden secret root for write: {pattern} (under {sec})")
    elif pattern == "/root/.ssh/**" or pattern.startswith("/root/.ssh/"):
        drifts.append(f"SAFETY HAZARD: live rules admit forbidden secret root for write: {pattern} (under /root/.ssh)")

for pattern in live_read_roots:
    if pattern in PRIVATE_KEY_PATHS:
        drifts.append(f"SAFETY HAZARD: live rules admit private key path: {pattern}")
        continue
    sec = secret_root_of(pattern)
    if sec:
        drifts.append(f"SAFETY HAZARD: live rules admit forbidden secret root for read: {pattern} (under {sec})")

if drifts:
    print("FAILED: helper permission rules drift detected:", file=sys.stderr)
    for d in drifts:
        print(f"  - {d}", file=sys.stderr)
    sys.exit(1)

log("PASS: helper permission rules match live configurations with 0 drift")
sys.exit(0)
PY
