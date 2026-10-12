#!/usr/bin/env bash
# fm-coord-drift-check.sh - verify documented production host coordinates against live DNS/HTTP
#
# Single owner of production host coordinate verification and drift detection.
# Runs without Firstmate in the loop.
# Resolves coordinates via external DNS resolver (default 1.1.1.1) to bypass local /etc/hosts
# entries, preventing false localhost reporting on the Controller.
#
# Verdicts:
#   COORD OK: host <host> -> <live_ip>
#   COORD DRIFT: host <host>: recorded <recorded_ip>, live <live_ip>
#   COORD UNKNOWN: host <host> (unresolvable via @<resolver>)
#
# Usage:
#   fm-coord-drift-check.sh                         # verify all canonical core-distro coordinates
#   fm-coord-drift-check.sh <host> <recorded_ip>    # verify one specific coordinate pair
#   fm-coord-drift-check.sh --file <path>           # verify hosts from a TSV file (<host>\t<recorded_ip>)
#   fm-coord-drift-check.sh --probe-http            # verify coordinates and also perform read-only HTTPS HEAD
#   fm-coord-drift-check.sh --help                  # show this usage message
#
# Exit codes:
#   0 = all checked coordinates match live (COORD OK)
#   1 = drift or unresolvable host detected (COORD DRIFT or COORD UNKNOWN)
#   2 = usage error or missing dependencies
set -uo pipefail

DNS_RESOLVER="${FM_DNS_RESOLVER:-1.1.1.1}"
PROBE_HTTP=0

usage() {
  printf 'usage: %s [OPTIONS] [host recorded_ip]\n' "${0##*/}"
  printf 'Verify documented production host coordinates against live DNS resolution.\n\n'
  printf 'Options:\n'
  printf '  --file <path>       Read <host> <recorded_ip> pairs from file\n'
  printf '  --resolver <ip>     Override DNS resolver IP (default: 1.1.1.1)\n'
  printf '  --probe-http        Also probe HTTPS HEAD via --resolve (read-only)\n'
  printf '  -h, --help          Show this help message\n'
}

# Canonical documented core-distro inventory
# Format: <host> <recorded_ip>
CANONICAL_COORDS=(
  "core-distro.com 66.29.153.174"
  "data.core-distro.com 66.29.153.174"
  "agents.core-distro.com 161.97.120.4"
)

FILE_PATH=""
EXPLICIT_HOST=""
EXPLICIT_IP=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file)
      [ "$#" -ge 2 ] || { echo "error: --file requires an argument" >&2; exit 2; }
      FILE_PATH="$2"
      shift 2
      ;;
    --resolver)
      [ "$#" -ge 2 ] || { echo "error: --resolver requires an argument" >&2; exit 2; }
      DNS_RESOLVER="$2"
      shift 2
      ;;
    --probe-http)
      PROBE_HTTP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      printf 'error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [ -z "$EXPLICIT_HOST" ]; then
        EXPLICIT_HOST="$1"
        shift
      elif [ -z "$EXPLICIT_IP" ]; then
        EXPLICIT_IP="$1"
        shift
      else
        printf 'error: unexpected extra argument: %s\n' "$1" >&2
        exit 2
      fi
      ;;
  esac
done

if [ -n "$EXPLICIT_HOST" ] && [ -z "$EXPLICIT_IP" ]; then
  echo "error: specifying a host requires specifying the recorded IP" >&2
  exit 2
fi

command -v dig >/dev/null 2>&1 || { echo "error: 'dig' command not found" >&2; exit 2; }
if [ "$PROBE_HTTP" -eq 1 ]; then
  command -v curl >/dev/null 2>&1 || { echo "error: 'curl' command not found" >&2; exit 2; }
fi

resolve_live_ip() {
  local host="$1"
  local raw_output
  raw_output=$(dig +short +time=5 +tries=2 "@$DNS_RESOLVER" "$host" 2>/dev/null || true)
  printf '%s\n' "$raw_output" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1
}

probe_https_head() {
  local host="$1"
  local ip="$2"
  local status_line
  status_line=$(curl -s -I -k --connect-timeout 5 --max-time 10 \
    --resolve "${host}:443:${ip}" \
    "https://${host}" 2>/dev/null | head -n 1 | tr -d '\r')
  printf '%s' "${status_line:-HTTP_PROBE_FAILED}"
}

check_coordinate() {
  local host="$1"
  local recorded_ip="$2"
  local live_ip
  live_ip="$(resolve_live_ip "$host")"

  if [ -z "$live_ip" ]; then
    printf 'COORD UNKNOWN: host %s (recorded %s, live unresolvable via @%s)\n' \
      "$host" "$recorded_ip" "$DNS_RESOLVER" >&2
    return 1
  fi

  if [ "$live_ip" != "$recorded_ip" ]; then
    printf 'COORD DRIFT: recorded %s, live %s (host %s)\n' \
      "$recorded_ip" "$live_ip" "$host" >&2
    return 1
  fi

  if [ "$PROBE_HTTP" -eq 1 ]; then
    local http_status
    http_status="$(probe_https_head "$host" "$live_ip")"
    printf 'COORD OK: %s -> %s [HTTPS: %s]\n' "$host" "$live_ip" "$http_status"
  else
    printf 'COORD OK: %s -> %s\n' "$host" "$live_ip"
  fi
  return 0
}

failures=0

if [ -n "$EXPLICIT_HOST" ]; then
  check_coordinate "$EXPLICIT_HOST" "$EXPLICIT_IP" || failures=$((failures + 1))
elif [ -n "$FILE_PATH" ]; then
  [ -f "$FILE_PATH" ] || { echo "error: file not found: $FILE_PATH" >&2; exit 2; }
  while IFS=$' \t' read -r host recorded_ip || [ -n "${host:-}" ]; do
    [ -n "${host:-}" ] || continue
    [[ "$host" =~ ^# ]] && continue
    [ -n "${recorded_ip:-}" ] || continue
    check_coordinate "$host" "$recorded_ip" || failures=$((failures + 1))
  done < "$FILE_PATH"
else
  for item in "${CANONICAL_COORDS[@]}"; do
    host="${item%% *}"
    recorded_ip="${item##* }"
    check_coordinate "$host" "$recorded_ip" || failures=$((failures + 1))
  done
fi

if [ "$failures" -gt 0 ]; then
  printf 'FAIL: %d coordinate(s) drifted or unresolvable\n' "$failures" >&2
  exit 1
fi

printf 'PASS: all checked coordinates verified\n'
exit 0
