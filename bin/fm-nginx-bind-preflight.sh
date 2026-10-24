#!/usr/bin/env bash
# fm-nginx-bind-preflight.sh - prove an nginx vhost can bind before it is deployed.
#
# The single owner of the web-tier bind-ability pre-flight.
#
# Why this exists: `nginx -t` parses the configuration and never binds a socket.
# A vhost that declares a listen port already held by another service passes
# `nginx -t` and then detonates at the next nginx restart, taking every other
# domain on the same shared nginx down with it. This pre-flight runs the cheap
# syntax parse first and then proves the rest of the bind contract, so the
# failure lands before the deployment instead of at an unattended restart.
#
# Checks, in order. Every check reports PASS, FAIL or UNVERIFIED together with
# the evidence it used:
#   1 syntax-parse   `nginx -t` over the effective configuration. Necessary but
#                     not sufficient, because it never binds a socket.
#   2 listen-bind    every declared listen address and port is bound for real.
#   3 tls-material   every referenced certificate and key path exists and is
#                     readable.
#   4 upstream       a declared proxy_pass upstream answers an HTTP GET.
#   5 document-root  the declared document root exists.
#
# A check that cannot be evaluated reports UNVERIFIED and never PASS. The
# verdict line is PASS only when every check PASSed.
#
# Usage:
#   fm-nginx-bind-preflight.sh [OPTIONS] <vhost-file> [<vhost-file>...]
#
# Options:
#   --nginx-bin <path>      nginx binary for the syntax parse (default: nginx from PATH)
#   --nginx-conf <path>     nginx configuration file to parse (default: /etc/nginx/nginx.conf)
#   --config-prefix <dir>   prefix for relative paths in the vhost (default: /etc/nginx)
#   --timeout <seconds>     upstream probe timeout (default: 5)
#   --help                  show this usage message
#
# Exit codes:
#   0 = every check PASSed
#   1 = at least one check FAILed
#   2 = usage error
#   3 = no check FAILed, but at least one check is UNVERIFIED
#
# Safety:
#   * Read-only. It never writes, reloads, restarts or otherwise mutates nginx
#     or any service it inspects.
#   * The listen probe binds a socket and releases it at once. It never serves
#     traffic.
#   * The upstream probe issues an HTTP GET only. It never issues a mutating
#     request.
#   * Certificate and key paths are reported by presence, mode and owner only.
#     Key material is never read, printed, hashed or transmitted.
#   * Run it on the host that will run nginx. A listen address this host does
#     not hold cannot be evaluated here.
set -uo pipefail

SCRIPT_NAME="fm-nginx-bind-preflight"
NGINX_BIN="nginx"
NGINX_CONF="/etc/nginx/nginx.conf"
CONFIG_PREFIX="/etc/nginx"
UPSTREAM_TIMEOUT=5
MAX_INCLUDE_DEPTH=4

TAB=$'\t'
SUMMARY=()
DETAILS=()
PASS_COUNT=0
FAIL_COUNT=0
UNVERIFIED_COUNT=0
INCOMPLETE=0
UNRESOLVED_INCLUDES=()
DIRECTIVES=()
SEEN_FILES=""

usage() {
  cat <<EOF
${SCRIPT_NAME} - prove an nginx vhost can bind before it is deployed.

Usage: ${SCRIPT_NAME} [OPTIONS] <vhost-file> [<vhost-file>...]

Options:
  --nginx-bin <path>      nginx binary for the syntax parse (default: nginx from PATH)
  --nginx-conf <path>     nginx configuration file to parse (default: ${NGINX_CONF})
  --config-prefix <dir>   prefix for relative paths in the vhost (default: ${CONFIG_PREFIX})
  --timeout <seconds>     upstream probe timeout (default: ${UPSTREAM_TIMEOUT})
  -h, --help              show this usage message

Checks: syntax-parse, listen-bind, tls-material, upstream, document-root.
Every check reports PASS, FAIL or UNVERIFIED with the evidence it used.
A check that cannot be evaluated reports UNVERIFIED and never PASS.

Exit codes:
  0 = every check PASSed
  1 = at least one check FAILed
  2 = usage error
  3 = no check FAILed, but at least one check is UNVERIFIED
EOF
}

detail() {
  DETAILS+=("$1")
}

report_check() {
  local label=$1 status=$2 note=""
  if [ "$status" = "PASS" ] && [ "$INCOMPLETE" -eq 1 ] && [ "$label" != "syntax-parse" ]; then
    status="UNVERIFIED"
    note="note: a referenced include could not be read, so this check is not exhaustive"
  fi
  printf 'CHECK %s: %s\n' "$label" "$status"
  for line in "${DETAILS[@]+"${DETAILS[@]}"}"; do
    printf '  %s\n' "$line"
  done
  [ -z "$note" ] || printf '  %s\n' "$note"
  DETAILS=()
  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    UNVERIFIED) UNVERIFIED_COUNT=$((UNVERIFIED_COUNT + 1)) ;;
  esac
  SUMMARY+=("$label=$status")
}

# --- directive extraction -----------------------------------------------------
#
# Tagged records, tab separated:
#   LISTEN <args>            a listen directive argument list
#   CERT <path>              an ssl_certificate path
#   KEY <path>               an ssl_certificate_key path
#   ROOT <path>              a root path
#   ALIAS <path>             an alias path
#   PROXY <url>              a proxy_pass target
#   UPSTREAM <name>          an upstream block name
#   UPSERVER <name> <addr>   a server inside an upstream block
#   INCLUDE <path>           an include path
#
# The parser is deliberately shallow: it reads directives, not nginx grammar.
# It reports what it found and leaves the interpretation to the checks.

extract_directives() {
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    {
      line = $0
      sub(/#[^"]*$/, "", line)
      sub(/^[ \t]+/, "", line)
      if (line == "") next
      if (line ~ /^}/) { in_upstream = 0; next }
      if (in_upstream) {
        if (line ~ /^server[ \t]/) {
          arg = line
          sub(/^server[ \t]+/, "", arg)
          sub(/;.*$/, "", arg)
          split(arg, parts, /[ \t]+/)
          print "UPSERVER\t" upstream "\t" trim(parts[1])
        }
        next
      }
      if (line ~ /^upstream[ \t]/) {
        name = line
        sub(/^upstream[ \t]+/, "", name)
        split(name, parts, /[ \t{]+/)
        upstream = parts[1]
        in_upstream = 1
        print "UPSTREAM\t" upstream
        next
      }
      if (line ~ /^listen[ \t]/) {
        arg = line; sub(/^listen[ \t]+/, "", arg); sub(/;.*$/, "", arg)
        print "LISTEN\t" trim(arg)
        next
      }
      if (line ~ /^ssl_certificate_key[ \t]/) {
        arg = line; sub(/^ssl_certificate_key[ \t]+/, "", arg); sub(/;.*$/, "", arg)
        print "KEY\t" trim(arg)
        next
      }
      if (line ~ /^ssl_certificate[ \t]/) {
        arg = line; sub(/^ssl_certificate[ \t]+/, "", arg); sub(/;.*$/, "", arg)
        print "CERT\t" trim(arg)
        next
      }
      if (line ~ /^proxy_pass[ \t]/) {
        arg = line; sub(/^proxy_pass[ \t]+/, "", arg); sub(/;.*$/, "", arg)
        print "PROXY\t" trim(arg)
        next
      }
      if (line ~ /^root[ \t]/) {
        arg = line; sub(/^root[ \t]+/, "", arg); sub(/;.*$/, "", arg)
        print "ROOT\t" trim(arg)
        next
      }
      if (line ~ /^alias[ \t]/) {
        arg = line; sub(/^alias[ \t]+/, "", arg); sub(/;.*$/, "", arg)
        print "ALIAS\t" trim(arg)
        next
      }
      if (line ~ /^include[ \t]/) {
        arg = line; sub(/^include[ \t]+/, "", arg); sub(/;.*$/, "", arg)
        print "INCLUDE\t" trim(arg)
        next
      }
    }
  ' "$1"
}

resolve_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "${CONFIG_PREFIX%/}/$1" ;;
  esac
}

# Walk a configuration file and every include it resolves, collecting the
# directives of all of them. An include that resolves to nothing is recorded:
# the effective configuration is then not fully visible here.
walk_config() {
  local file=$1 depth=$2 record payload
  [ "$depth" -le "$MAX_INCLUDE_DEPTH" ] || return 0
  case "$SEEN_FILES" in
    *"|$file|"*) return 0 ;;
  esac
  SEEN_FILES="$SEEN_FILES|$file|"
  [ -r "$file" ] || return 0
  while IFS= read -r record; do
    DIRECTIVES+=("$record")
    case "$record" in
      "INCLUDE${TAB}"*)
        payload=${record#INCLUDE}
        payload=${payload#"$TAB"}
        resolve_include "$payload" "$depth"
        ;;
    esac
  done < <(extract_directives "$file")
}

resolve_include() {
  local pattern=$1 depth=$2 candidate absolute match
  local -a matches=()
  if [ -f "$pattern" ]; then
    matches=("$pattern")
  else
    absolute=$(resolve_path "$pattern")
    if [ -f "$absolute" ]; then
      matches=("$absolute")
    else
      # shellcheck disable=SC2086 # deliberate glob expansion of the include pattern
      for candidate in $absolute; do
        [ -f "$candidate" ] && matches+=("$candidate")
      done
    fi
  fi
  if [ "${#matches[@]}" -eq 0 ]; then
    INCOMPLETE=1
    UNRESOLVED_INCLUDES+=("$pattern")
    return 0
  fi
  for match in "${matches[@]}"; do
    walk_config "$match" $((depth + 1))
  done
}

# --- bind probe ---------------------------------------------------------------
#
# The probe binds the exact address and port the vhost declares, which is the
# only way to prove bind-ability. Reading a socket table is not enough: a
# wildcard holder blocks a specific bind and a specific holder blocks a
# wildcard bind, and only a real bind sees that.
#
# The probe prints one line:
#   BIND_OK
#   BIND_ERR errno=<n> msg=<text>

probe_bind() {
  local address=$1 port=$2
  python3 - "$address" "$port" <<'PY'
import socket
import sys

address = sys.argv[1]
port = int(sys.argv[2])

if address.startswith("[") and address.endswith("]"):
    host = address[1:-1]
    family = socket.AF_INET6
elif ":" in address:
    host = address
    family = socket.AF_INET6
else:
    host = address
    family = socket.AF_INET

sock = socket.socket(family, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    sock.bind((host, port))
    print("BIND_OK")
except OSError as exc:
    print("BIND_ERR errno=%d msg=%s" % (exc.errno, exc.strerror))
finally:
    sock.close()
PY
}

listen_holders() {
  local port=$1
  if command -v ss >/dev/null 2>&1; then
    ss -ltnpH 2>/dev/null | awk -v want="$port" '{ n = split($4, part, ":"); if (part[n] == want) print }' | head -n 3
  fi
}

# --- checks -------------------------------------------------------------------

run_syntax_parse() {
  local label="syntax-parse" resolved output rc status
  if ! resolved=$(command -v "$NGINX_BIN" 2>/dev/null); then
    detail "command: $NGINX_BIN -t -c $NGINX_CONF"
    detail "evidence: the nginx binary was not found: $NGINX_BIN"
    report_check "$label" "UNVERIFIED"
    return 0
  fi
  output=$("$resolved" -t -c "$NGINX_CONF" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    status="PASS"
  else
    status="FAIL"
  fi
  detail "command: $resolved -t -c $NGINX_CONF"
  detail "evidence: $(printf '%s' "$output" | tr '\n' ' ' | cut -c1-400)"
  report_check "$label" "$status"
}

listen_targets() {
  local record args first address port payload
  for record in "${DIRECTIVES[@]+"${DIRECTIVES[@]}"}"; do
    case "$record" in
      "LISTEN${TAB}"*)
        payload=${record#LISTEN}
        args=${payload#"$TAB"}
        read -r first _ <<<"$args"
        [ -n "$first" ] || continue
        case "$first" in
          unix:*) continue ;;
        esac
        case "$first" in
          \[*\]:*)
            address=${first%%]:*}
            address="$address]"
            port=${first##*]:}
            ;;
          *:*)
            address=${first%:*}
            port=${first##*:}
            ;;
          *)
            address="0.0.0.0"
            port="$first"
            ;;
        esac
        case "$port" in
          ''|*[!0-9]*) continue ;;
        esac
        printf '%s:%s\n' "$address" "$port"
        ;;
    esac
  done | LC_ALL=C sort -u
}

run_listen_bind() {
  local label="listen-bind" target address port result status="PASS" probe_rc holder
  local -a targets=()
  while IFS= read -r target; do
    [ -n "$target" ] && targets+=("$target")
  done < <(listen_targets)

  if [ "${#targets[@]}" -eq 0 ]; then
    detail "evidence: no listen address was found in the vhost"
    report_check "$label" "UNVERIFIED"
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    detail "evidence: python3 is not available to run the bind probe"
    report_check "$label" "UNVERIFIED"
    return 0
  fi

  for target in "${targets[@]}"; do
    address=${target%:*}
    port=${target##*:}
    result=$(probe_bind "$address" "$port" 2>&1)
    probe_rc=$?
    detail "target: $target"
    detail "command: bind probe $address:$port"
    case "$result" in
      BIND_OK)
        detail "evidence: the address and port bound successfully and the socket was released"
        ;;
      *"errno=98"*)
        status="FAIL"
        detail "evidence: $result"
        holder=$(listen_holders "$port")
        if [ -n "$holder" ]; then
          detail "holder: $(printf '%s' "$holder" | tr '\n' '|')"
        else
          detail "holder: no listening socket was reported for port $port"
        fi
        ;;
      *)
        if [ "$status" != "FAIL" ]; then
          status="UNVERIFIED"
        fi
        if [ "$probe_rc" -ne 0 ] && [ -z "$result" ]; then
          detail "evidence: the bind probe did not run"
        else
          detail "evidence: $result"
        fi
        ;;
    esac
  done
  report_check "$label" "$status"
}

path_metadata() {
  local path=$1
  if command -v stat >/dev/null 2>&1; then
    stat -c '%a %U:%G' "$path" 2>/dev/null
  fi
}

run_tls_material() {
  local label="tls-material" record path resolved status="PASS" found=0 metadata payload
  for record in "${DIRECTIVES[@]+"${DIRECTIVES[@]}"}"; do
    case "$record" in
      "CERT${TAB}"*|"KEY${TAB}"*)
        path=${record#*"$TAB"}
        found=1
        resolved=$(resolve_path "$path")
        if [ ! -e "$resolved" ]; then
          status="FAIL"
          detail "target: $resolved"
          detail "command: test -e $resolved"
          detail "evidence: the referenced file does not exist"
        elif [ ! -r "$resolved" ]; then
          status="FAIL"
          detail "target: $resolved"
          detail "command: test -r $resolved"
          detail "evidence: the referenced file is not readable"
        else
          metadata=$(path_metadata "$resolved")
          detail "target: $resolved"
          detail "command: test -r $resolved"
          detail "evidence: present mode ${metadata:-unknown}"
        fi
        ;;
    esac
  done
  if [ "$found" -eq 0 ]; then
    detail "evidence: no ssl_certificate or ssl_certificate_key directive was found"
    report_check "$label" "UNVERIFIED"
    return 0
  fi
  report_check "$label" "$status"
}

upstream_endpoints() {
  local url=$1 scheme authority host path endpoint name record server payload matched=0
  case "$url" in
    http://*|https://*) ;;
    *) return 1 ;;
  esac
  scheme="${url%%://*}"
  authority="${url#*://}"
  case "$authority" in
    */*)
      path="/${authority#*/}"
      authority="${authority%%/*}"
      ;;
    *)
      path="/"
      ;;
  esac
  case "$authority" in
    *@*) authority="${authority#*@}" ;;
  esac
  host="$authority"
  case "$authority" in
    \[*\]:*) host="${authority%%]:*}]" ;;
    *:*) host="${authority%:*}" ;;
  esac
  for record in "${DIRECTIVES[@]+"${DIRECTIVES[@]}"}"; do
    case "$record" in
      "UPSERVER${TAB}"*)
        payload=${record#UPSERVER}
        payload=${payload#"$TAB"}
        name=${payload%%"$TAB"*}
        server=${payload#*"$TAB"}
        if [ "$name" = "$host" ]; then
          matched=1
          endpoint="$server"
          case "$endpoint" in
            *:*) ;;
            *) endpoint="$endpoint:80" ;;
          esac
          printf '%s://%s%s\n' "$scheme" "$endpoint" "$path"
        fi
        ;;
    esac
  done
  if [ "$matched" -eq 0 ]; then
    # The proxy_pass target is not an upstream block name, so the declared
    # target itself is the endpoint to probe.
    printf '%s://%s%s\n' "$scheme" "$authority" "$path"
  fi
  return 0
}

run_upstream() {
  local label="upstream" record url status="PASS" found=0 endpoint combined code message rc payload
  local -a endpoints=()
  for record in "${DIRECTIVES[@]+"${DIRECTIVES[@]}"}"; do
    case "$record" in
      "PROXY${TAB}"*)
        payload=${record#PROXY}
        url=${payload#"$TAB"}
        found=1
        if ! command -v curl >/dev/null 2>&1; then
          status="UNVERIFIED"
          detail "target: $url"
          detail "evidence: curl is not available to probe the upstream"
          continue
        fi
        case "$url" in
          *'$'*)
            status="UNVERIFIED"
            detail "target: $url"
            detail "evidence: the upstream target holds a variable and cannot be probed here"
            continue
            ;;
        esac
        endpoints=()
        while IFS= read -r endpoint; do
          [ -n "$endpoint" ] && endpoints+=("$endpoint")
        done < <(upstream_endpoints "$url")
        if [ "${#endpoints[@]}" -eq 0 ]; then
          status="UNVERIFIED"
          detail "target: $url"
          detail "evidence: the upstream target is not an http endpoint this probe can read"
          continue
        fi
        for endpoint in "${endpoints[@]}"; do
          combined=$(curl -sS -o /dev/null -w '%{http_code}' \
            --max-time "$UPSTREAM_TIMEOUT" "$endpoint" 2>&1)
          rc=$?
          code="${combined##*$'\n'}"
          message="${combined%$'\n'*}"
          detail "target: $endpoint"
          detail "command: curl -sS -o /dev/null -w %{http_code} --max-time $UPSTREAM_TIMEOUT $endpoint"
          if [ "$rc" -eq 0 ] && [ "$code" != "000" ]; then
            detail "evidence: the upstream answered with http_code $code"
          else
            status="FAIL"
            detail "evidence: the upstream did not answer (curl exit $rc, http_code $code) $message"
          fi
        done
        ;;
    esac
  done
  if [ "$found" -eq 0 ]; then
    detail "evidence: no proxy_pass directive was found in the vhost"
    report_check "$label" "UNVERIFIED"
    return 0
  fi
  report_check "$label" "$status"
}

run_document_root() {
  local label="document-root" record path resolved status="PASS" found=0
  for record in "${DIRECTIVES[@]+"${DIRECTIVES[@]}"}"; do
    case "$record" in
      "ROOT${TAB}"*|"ALIAS${TAB}"*)
        path=${record#*"$TAB"}
        found=1
        resolved=$(resolve_path "$path")
        if [ -d "$resolved" ]; then
          detail "target: $resolved"
          detail "command: test -d $resolved"
          detail "evidence: the document root exists mode $(path_metadata "$resolved")"
        else
          status="FAIL"
          detail "target: $resolved"
          detail "command: test -d $resolved"
          detail "evidence: the document root does not exist"
        fi
        ;;
    esac
  done
  if [ "$found" -eq 0 ]; then
    detail "evidence: no root or alias directive was found in the vhost"
    report_check "$label" "UNVERIFIED"
    return 0
  fi
  report_check "$label" "$status"
}

# --- entry point --------------------------------------------------------------

FILES=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --nginx-bin)
      [ "$#" -ge 2 ] || { printf 'error: --nginx-bin requires an argument\n' >&2; exit 2; }
      NGINX_BIN=$2
      shift 2
      ;;
    --nginx-conf)
      [ "$#" -ge 2 ] || { printf 'error: --nginx-conf requires an argument\n' >&2; exit 2; }
      NGINX_CONF=$2
      shift 2
      ;;
    --config-prefix)
      [ "$#" -ge 2 ] || { printf 'error: --config-prefix requires an argument\n' >&2; exit 2; }
      CONFIG_PREFIX=$2
      shift 2
      ;;
    --timeout)
      [ "$#" -ge 2 ] || { printf 'error: --timeout requires an argument\n' >&2; exit 2; }
      UPSTREAM_TIMEOUT=$2
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        FILES+=("$1")
        shift
      done
      ;;
    -*)
      printf 'error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      FILES+=("$1")
      shift
      ;;
  esac
done

if [ "${#FILES[@]}" -eq 0 ]; then
  printf 'error: at least one vhost file is required\n' >&2
  usage >&2
  exit 2
fi

for file in "${FILES[@]}"; do
  if [ ! -r "$file" ]; then
    printf 'error: vhost file is not readable: %s\n' "$file" >&2
    exit 2
  fi
done

printf '%s: web-tier bind-ability pre-flight\n' "$SCRIPT_NAME"
printf 'nginx-bin: %s\n' "$NGINX_BIN"
printf 'nginx-conf: %s\n' "$NGINX_CONF"
printf 'config-prefix: %s\n' "$CONFIG_PREFIX"

run_syntax_parse

MULTIPLE=0
[ "${#FILES[@]}" -gt 1 ] && MULTIPLE=1

for file in "${FILES[@]}"; do
  printf '\nvhost: %s\n' "$file"
  DIRECTIVES=()
  SEEN_FILES=""
  INCOMPLETE=0
  UNRESOLVED_INCLUDES=()
  walk_config "$file" 1
  for include in "${UNRESOLVED_INCLUDES[@]+"${UNRESOLVED_INCLUDES[@]}"}"; do
    printf 'NOTE: include could not be resolved: %s\n' "$include"
  done
  if [ "$MULTIPLE" -eq 1 ]; then
    suffix="[$(basename "$file")]"
  else
    suffix=""
  fi
  run_listen_bind "listen-bind$suffix"
  run_tls_material "tls-material$suffix"
  run_upstream "upstream$suffix"
  run_document_root "document-root$suffix"
done

printf '\nSUMMARY:'
for entry in "${SUMMARY[@]+"${SUMMARY[@]}"}"; do
  printf ' %s' "$entry"
done
printf '\n'

if [ "$FAIL_COUNT" -gt 0 ]; then
  printf 'VERDICT: FAIL\n'
  exit 1
fi
if [ "$UNVERIFIED_COUNT" -gt 0 ]; then
  printf 'VERDICT: UNVERIFIED\n'
  exit 3
fi
printf 'VERDICT: PASS\n'
exit 0
