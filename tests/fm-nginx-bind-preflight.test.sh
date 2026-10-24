#!/usr/bin/env bash
# Focused tests for the web-tier bind-ability pre-flight.
#
# Covers the contract of bin/fm-nginx-bind-preflight.sh:
#   - a listen port already held by another process is reported as a FAIL
#   - the pre-flight never reports success for a vhost that cannot bind
#   - a free listen port is reported as a PASS
#   - a vhost that can bind and serve is reported as a PASS overall
#   - every check that cannot be evaluated reports UNVERIFIED, never PASS
#   - certificate and key material is never printed
#
# Every fixture binds a scratch port handed out by the kernel and proven free
# first. No production port and no production host is involved.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/bin/fm-nginx-bind-preflight.sh"

command -v python3 >/dev/null 2>&1 \
  || fail "python3 is required: the bind probe and the fixture listener need it"

TMP_ROOT=$(fm_test_tmproot fm-nginx-bind-preflight)
mkdir -p "$TMP_ROOT/www" "$TMP_ROOT/certs"

LISTENER_PIDS=()

cleanup() {
  local pid
  for pid in "${LISTENER_PIDS[@]+"${LISTENER_PIDS[@]}"}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  fm_test_cleanup
}
trap cleanup EXIT

# A stand-in for nginx so the syntax parse is deterministic on a host that has
# no nginx binary at all. The real binary is never invoked by this test.
FAKE_NGINX="$TMP_ROOT/fake-nginx"
cat > "$FAKE_NGINX" <<'SH'
#!/usr/bin/env bash
printf 'nginx: the configuration file %s syntax is ok\n' "${3:-/etc/nginx/nginx.conf}"
printf 'nginx: configuration file %s test is successful\n' "${3:-/etc/nginx/nginx.conf}"
exit 0
SH
chmod +x "$FAKE_NGINX"

# Ask the kernel for an unused high port and prove it is free before use.
free_scratch_port() {
  python3 - <<'PY'
import socket

sock = socket.socket()
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(("127.0.0.1", 0))
print(sock.getsockname()[1])
sock.close()
PY
}

# Hold a scratch port so a vhost that declares it cannot bind.
start_listener() {
  local port=$1
  python3 - "$port" >/dev/null 2>&1 <<'PY' &
import socket
import sys
import time

sock = socket.socket()
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(("127.0.0.1", int(sys.argv[1])))
sock.listen(5)
time.sleep(300)
PY
  LISTENER_PIDS+=("$!")
}

port_is_bound() {
  python3 - "$1" <<'PY'
import socket
import sys

sock = socket.socket()
sock.settimeout(0.2)
try:
    sock.connect(("127.0.0.1", int(sys.argv[1])))
    print("BOUND")
except OSError:
    print("FREE")
finally:
    sock.close()
PY
}

wait_for_listener() {
  local port=$1 tries=0
  while [ "$tries" -lt 100 ]; do
    if [ "$(port_is_bound "$port")" = "BOUND" ]; then
      return 0
    fi
    tries=$((tries + 1))
    sleep 0.1
  done
  return 1
}

# A scratch port must never be a privileged service port.
CONFLICT_PORT=$(free_scratch_port)
[ "${CONFLICT_PORT:-0}" -gt 1024 ] \
  || fail "the scratch port must be a high unprivileged port, got '$CONFLICT_PORT'"

# --- a held listen port is caught ---------------------------------------------

start_listener "$CONFLICT_PORT"
wait_for_listener "$CONFLICT_PORT" \
  || fail "the fixture listener never took the scratch port $CONFLICT_PORT"

cat > "$TMP_ROOT/conflict.conf" <<EOF
server {
    listen 127.0.0.1:${CONFLICT_PORT};
    server_name staging.example.test;
    root $TMP_ROOT/www;
}
EOF

out=$(bash "$SCRIPT" \
  --nginx-bin "$FAKE_NGINX" \
  --nginx-conf "$TMP_ROOT/nginx.conf" \
  "$TMP_ROOT/conflict.conf" 2>&1)
rc=$?

expect_code 1 "$rc" "a vhost whose listen port is already held must exit 1"
assert_contains "$out" "CHECK listen-bind: FAIL" \
  "the held listen port must be reported as a FAIL"
assert_contains "$out" "errno=98" \
  "the bind failure must carry the EADDRINUSE evidence"
assert_not_contains "$out" "CHECK listen-bind: PASS" \
  "a held listen port must never be reported as a PASS"
assert_not_contains "$out" "VERDICT: PASS" \
  "the pre-flight must never report success for a vhost that cannot bind"
assert_contains "$out" "VERDICT: FAIL" \
  "the verdict must be FAIL for a vhost that cannot bind"
pass "fm-nginx-bind-preflight.sh: a vhost that cannot bind is caught and never reported as a success"

# --- a free listen port is a PASS ---------------------------------------------

FREE_PORT=$(free_scratch_port)
cat > "$TMP_ROOT/free.conf" <<EOF
server {
    listen 127.0.0.1:${FREE_PORT};
    server_name free.example.test;
    root $TMP_ROOT/www;
}
EOF

out=$(bash "$SCRIPT" \
  --nginx-bin "$FAKE_NGINX" \
  --nginx-conf "$TMP_ROOT/nginx.conf" \
  "$TMP_ROOT/free.conf" 2>&1)
rc=$?

assert_contains "$out" "CHECK listen-bind: PASS" \
  "a free listen port must be reported as a PASS"
assert_not_contains "$out" "VERDICT: FAIL" \
  "a vhost that can bind must not be reported as a FAIL"
expect_code 3 "$rc" \
  "a vhost with checks that cannot be evaluated must exit 3, never 0"
assert_contains "$out" "CHECK upstream: UNVERIFIED" \
  "a vhost without an upstream must report UNVERIFIED, never PASS"
assert_not_contains "$out" "CHECK upstream: PASS" \
  "a vhost without an upstream must never report a PASS"
pass "fm-nginx-bind-preflight.sh: a free listen port is a PASS and an unevaluable check is UNVERIFIED"

# --- a vhost that can bind and serve is a PASS overall ------------------------

UPSTREAM_PORT=$(free_scratch_port)
python3 -m http.server "$UPSTREAM_PORT" --bind 127.0.0.1 --directory "$TMP_ROOT/www" \
  >/dev/null 2>&1 &
LISTENER_PIDS+=("$!")
wait_for_listener "$UPSTREAM_PORT" \
  || fail "the fixture upstream never took the scratch port $UPSTREAM_PORT"

printf 'fixture certificate\n' > "$TMP_ROOT/certs/fullchain.pem"
printf 'FIXTURE-PRIVATE-KEY-MATERIAL\n' > "$TMP_ROOT/certs/privkey.pem"
chmod 600 "$TMP_ROOT/certs/privkey.pem"

SERVE_PORT=$(free_scratch_port)
cat > "$TMP_ROOT/serve.conf" <<EOF
server {
    listen 127.0.0.1:${SERVE_PORT};
    server_name serve.example.test;
    root $TMP_ROOT/www;
    ssl_certificate $TMP_ROOT/certs/fullchain.pem;
    ssl_certificate_key $TMP_ROOT/certs/privkey.pem;
    location / {
        proxy_pass http://127.0.0.1:${UPSTREAM_PORT}/;
    }
}
EOF

out=$(bash "$SCRIPT" \
  --nginx-bin "$FAKE_NGINX" \
  --nginx-conf "$TMP_ROOT/nginx.conf" \
  "$TMP_ROOT/serve.conf" 2>&1)
rc=$?

expect_code 0 "$rc" "a vhost that can bind and serve must exit 0"
assert_contains "$out" "VERDICT: PASS" \
  "a vhost that can bind and serve must report the PASS verdict"
assert_contains "$out" "CHECK tls-material: PASS" \
  "readable certificate and key paths must be reported as a PASS"
assert_contains "$out" "CHECK upstream: PASS" \
  "an upstream that answers must be reported as a PASS"
assert_not_contains "$out" "FIXTURE-PRIVATE-KEY-MATERIAL" \
  "the pre-flight must never print key material"
pass "fm-nginx-bind-preflight.sh: a fully satisfiable vhost passes and no key material is printed"

# --- a missing certificate path is a FAIL ------------------------------------

MISSING_PORT=$(free_scratch_port)
cat > "$TMP_ROOT/badcert.conf" <<EOF
server {
    listen 127.0.0.1:${MISSING_PORT};
    ssl_certificate $TMP_ROOT/certs/absent.pem;
}
EOF

out=$(bash "$SCRIPT" \
  --nginx-bin "$FAKE_NGINX" \
  --nginx-conf "$TMP_ROOT/nginx.conf" \
  "$TMP_ROOT/badcert.conf" 2>&1)
rc=$?

expect_code 1 "$rc" "a missing certificate path must exit 1"
assert_contains "$out" "CHECK tls-material: FAIL" \
  "a missing certificate path must be reported as a FAIL"
assert_not_contains "$out" "CHECK tls-material: PASS" \
  "a missing certificate path must never be reported as a PASS"
pass "fm-nginx-bind-preflight.sh: a missing certificate path is a FAIL"

# --- a missing nginx binary is UNVERIFIED, never PASS ------------------------

out=$(bash "$SCRIPT" \
  --nginx-bin "$TMP_ROOT/absent-nginx" \
  --nginx-conf "$TMP_ROOT/nginx.conf" \
  "$TMP_ROOT/free.conf" 2>&1)
rc=$?

assert_contains "$out" "CHECK syntax-parse: UNVERIFIED" \
  "a missing nginx binary must report the syntax parse as UNVERIFIED"
assert_not_contains "$out" "CHECK syntax-parse: PASS" \
  "a missing nginx binary must never report the syntax parse as a PASS"
expect_code 3 "$rc" "an unevaluable syntax parse must exit 3, never 0"
pass "fm-nginx-bind-preflight.sh: a missing nginx binary is UNVERIFIED, never PASS"

# --- a missing document root is a FAIL ---------------------------------------

NOROOT_PORT=$(free_scratch_port)
cat > "$TMP_ROOT/badroot.conf" <<EOF
server {
    listen 127.0.0.1:${NOROOT_PORT};
    root $TMP_ROOT/absent-root;
}
EOF

out=$(bash "$SCRIPT" \
  --nginx-bin "$FAKE_NGINX" \
  --nginx-conf "$TMP_ROOT/nginx.conf" \
  "$TMP_ROOT/badroot.conf" 2>&1)
rc=$?

expect_code 1 "$rc" "a missing document root must exit 1"
assert_contains "$out" "CHECK document-root: FAIL" \
  "a missing document root must be reported as a FAIL"
pass "fm-nginx-bind-preflight.sh: a missing document root is a FAIL"

# --- usage errors -------------------------------------------------------------

out=$(bash "$SCRIPT" 2>&1)
rc=$?
expect_code 2 "$rc" "no vhost file must be a usage error"

out=$(bash "$SCRIPT" "$TMP_ROOT/absent-vhost.conf" 2>&1)
rc=$?
expect_code 2 "$rc" "an unreadable vhost file must be a usage error"
pass "fm-nginx-bind-preflight.sh: a bad invocation is a usage error"

pass "fm-nginx-bind-preflight: the web-tier bind-ability pre-flight holds"
