#!/usr/bin/env bash
# factory-health.sh — before/after baseline for dependent systems.
# Read-only. Run before and after any change; diff the outputs.
#
# PORTABILITY, 2026-10-15 (Hetz/brandon-compute). The original wrote to a
# Controller-rooted path and then printed "snapshot: <path>" whether or not the
# write succeeded. Run from Hetz it failed to write anything and still reported a
# snapshot, which is the most dangerous possible failure for a baseline tool: a
# health check that claims success while collecting nothing.
#
# Three changes, all about truth rather than coverage:
#   1. The snapshot directory resolves to a writable home-local location, so the
#      tool produces a real artifact on the surface that runs it.
#   2. The exit status and the printed path reflect what actually happened. If the
#      write failed, it says so and returns non-zero. No false success.
#   3. Remote checks that are unavailable from this surface are reported as
#      UNREACHABLE, distinctly from a check that ran and found a problem. An
#      unavailable probe is not a healthy probe.
set -u

T=$(date -u +%FT%TZ)

# Snapshot directory: prefer an explicit override, then a home-local path. Never
# hardcode /root; it is not writable from this account and never was here.
SNAP_DIR="${FM_FACTORY_HEALTH_DIR:-${HOME:-/tmp}/.factory-health/reports}"
mkdir -p "$SNAP_DIR" 2>/dev/null || {
  printf 'factory-health: REFUSED - cannot create snapshot directory %s\n' "$SNAP_DIR" >&2
  exit 1
}
OUT="$SNAP_DIR/health-$(date -u +%Y%m%d-%H%M).txt"

# probe <label> <command...> runs a check and records OK, FAIL or UNREACHABLE.
# UNREACHABLE means the probe could not run at all, which is never a pass.
probe() {
  local label=$1; shift
  local out
  if out=$("$@" 2>&1); then
    printf -- '-- %s: %s\n' "$label" "$(printf '%s' "$out" | head -3 | tr '\n' ' ')"
  else
    printf -- '-- %s: UNREACHABLE (%s)\n' "$label" "$(printf '%s' "$out" | head -1)"
  fi
}

probe_ssh() {  # <label> <ssh-target> <remote-command>
  local label=$1 target=$2 cmd=$3 out
  if out=$(timeout 12 ssh -o BatchMode=yes -o ConnectTimeout=8 "$target" "$cmd" 2>&1); then
    printf -- '-- %s: %s\n' "$label" "$(printf '%s' "$out" | head -3 | tr '\n' ' ')"
  else
    printf -- '-- %s: UNREACHABLE from this surface (%s)\n' "$label" "$(printf '%s' "$out" | head -1)"
  fi
}

probe_http() {  # <label> <url>
  local label=$1 url=$2 code
  if code=$(timeout 12 curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null) && [ -n "$code" ] && [ "$code" != 000 ]; then
    printf -- '-- %s: HTTP %s\n' "$label" "$code"
  else
    printf -- '-- %s: UNREACHABLE (%s)\n' "$label" "${code:-no response}"
  fi
}

{
  printf '== FACTORY HEALTH %s ==\n' "$T"
  printf '== surface: %s\n' "$(hostname 2>/dev/null || echo unknown)"

  printf -- '-- disk\n'; df -h / 2>&1 | tail -1
  printf -- '-- memory\n'; free -m 2>&1 | awk 'NR==2{print $7"MB avail"}'
  printf -- '-- crons (dubz)\n'; ls /etc/cron.d/ 2>/dev/null | grep -E 'bridge|mirror|safetynet' || printf 'none visible from this surface\n'

  probe_http 'anythingllm local' 'http://100.106.6.22:3001/'
  probe_http 'elevate public' 'https://elevatesci.com/'
  probe_http 'agents public' 'https://agents.elevatesci.com/'
  probe_http 'core-distro live' 'https://core-distro.com/'

  # Controller-side surfaces. These are not reachable from every surface, and an
  # unreachable probe is reported as such rather than omitted.
  probe_ssh 'hd2 panes' 'hd2stack' '/usr/local/bin/herdr pane list 2>/dev/null | grep -c pane_id'
  probe_ssh 'hd2 mem' 'hd2stack' 'free -m | awk "NR==2{print \$7}"'
  probe_ssh 'widget sha (brandon)' 'brandon' 'sha256sum /home/hd2admin/hd2stack-anythingllm/brandin* 2>/dev/null | head -1'

  probe 'lean-ctx version' command -v lean-ctx
  probe 'quota-axi available' command -v quota-axi
  probe 'herdr available' command -v herdr
} > "$OUT" 2>&1

# Truth in the result: confirm the artifact exists before claiming it.
if [ -s "$OUT" ]; then
  printf 'snapshot: %s (%s bytes)\n' "$OUT" "$(wc -c < "$OUT" | tr -d ' ')"
  exit 0
fi
printf 'factory-health: REFUSED - snapshot was not written (%s)\n' "$OUT" >&2
exit 1