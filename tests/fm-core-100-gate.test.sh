#!/usr/bin/env bash
# fm-core-100-gate.test.sh - behaviour test for the CORE-100 acceptance gate.
#
# WHAT THIS PROVES
#   1. the gate exits 0 when every assertion that can run passes against a
#      controlled fixture (never against production),
#   2. the gate exits non-zero when exactly one assertion is deliberately
#      broken in the fixture,
#   3. the artifact mode (--artifact) runs and passes against the fixture,
#   4. --json emits machine-readable results for all 15 assertions,
#   5. --help documents the flags,
#   6. the gate is idempotent and read-only: two consecutive runs over the
#      same fixture leave the fixture byte-identical.
#
# The fixture is a throwaway tree in a temp directory. It is never production,
# and the gate is pointed at it with --host-root / --base-url / --legacy-url,
# so nothing outside this machine is contacted.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GATE="$ROOT/bin/fm-core-100-gate.sh"
SERVER="$ROOT/tests/fixtures/core-100-fixture-server.py"
TMP=$(mktemp -d)
PIDS=()
passed=0
failed=0

cleanup() {
  local p
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done
  rm -rf "$TMP"
}
trap cleanup EXIT

ok()   { printf 'PASS %s: %s\n' "$1" "$2"; passed=$((passed+1)); }
bad()  { printf 'FAIL %s: %s\n' "$1" "$2"; failed=$((failed+1)); }

sha() { sha256sum "$1" | cut -d' ' -f1; }
size() { wc -c < "$1" | tr -d ' '; }

free_port() {
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
}

# ── the fixture docroot ─────────────────────────────────────────────────────
DOCROOT="$TMP/docroot"
mkdir -p "$DOCROOT/assets" "$DOCROOT/geo_data" "$DOCROOT/nc_assets/css" "$DOCROOT/config" \
         "$DOCROOT/vendor" "$DOCROOT/Lead Engine"

cat > "$DOCROOT/index.php" <<'EOF'
<!DOCTYPE html><html><head><title>Core-Distro | Automated B2B Lead Generation</title></head>
<body><h1>fixture landing page</h1></body></html>
EOF
for f in login.php register.php forgot_password.php reset_password.php logout.php; do
  printf '<?php\n// fixture route: %s\necho "fixture %s";\n' "$f" "$f" > "$DOCROOT/$f"
done
for f in pricing.php leadlists.php admin.php dashboard.php subscription.php api_keys.php api_dashboard.php; do
  printf '<?php\n// fixture route: %s (auth gated)\nheader("Location: login.php");\n' "$f" > "$DOCROOT/$f"
done
for f in public_list.php api_wrapper.php; do
  printf '<?php\n// fixture route: %s (not found)\nhttp_response_code(404);\n' "$f" > "$DOCROOT/$f"
done
for f in maps_proxy.php log_api_call.php; do
  printf '<?php\n// fixture route: %s (api gated)\nhttp_response_code(401);\n' "$f" > "$DOCROOT/$f"
done
printf '<?php\n// fixture route: webhook_scrape.php (guard)\nhttp_response_code(400);\n' > "$DOCROOT/webhook_scrape.php"
printf 'fixture llms\n' > "$DOCROOT/llms.txt"
printf 'fixture robots\n' > "$DOCROOT/robots.txt"
printf '<urlset><url><loc>https://data.core-distro.com/</loc></url></urlset>\n' > "$DOCROOT/sitemap.xml"
printf '<svg xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1"/></svg>\n' > "$DOCROOT/assets/logo.svg"
printf '// fixture toast\nwindow.SaaSToast = { show: function () {} };\n' > "$DOCROOT/assets/saas-toast.js"
printf '.fixture-toast { color: red; }\n' > "$DOCROOT/assets/saas-toast.css"
printf 'RIFFfixture-webp-light\n' > "$DOCROOT/core-distro-mark-light.webp"
printf 'RIFFfixture-webp-navy\n' > "$DOCROOT/core-distro-mark-navy.webp"
printf 'fixture storefront body\n' > "$DOCROOT/storefront"
printf 'fixture staging body\n' > "$DOCROOT/staging"
printf 'fixture elevatesci body\n' > "$DOCROOT/elevatesci"

# live-only components (A4) and allowlisted extras (A3)
printf '<?php\n// fixture live-only worker\n' > "$DOCROOT/durable_scrape_worker.php"
printf '<?php\n// fixture live-only dashboard json\n' > "$DOCROOT/agents_dashboard_json.php"
printf 'fixture geo admin regions\n' > "$DOCROOT/geo_data/geo_admin_regions.sql"
printf 'fixture geo countries\n' > "$DOCROOT/geo_data/geo_countries.sql"
printf '.fixture-nc { color: blue; }\n' > "$DOCROOT/nc_assets/css/style.css"
printf '<?php\n// fixture live-only drip cron\n' > "$DOCROOT/Lead Engine/cron_drip.php"
printf '<?php\n// fixture config (never read by the gate)\n' > "$DOCROOT/config/app.php"
printf 'FIXTURE_SECRET_PLACEHOLDER\n' > "$DOCROOT/.env"
printf '<?php\n// fixture vendor\n' > "$DOCROOT/vendor/autoload.php"

# ── the fixture baseline (the gate reads the same file the fixture serves) ──
BASE="$TMP/baseline.tsv"
cat > "$BASE" <<EOF
# fixture baseline for the CORE-100 gate test
schema_sha256	$(printf 'fixture-schema-dump' | sha256sum | cut -d' ' -f1)
leadlists_sha256	$(sha "$DOCROOT/leadlists.php")
canonical_leadlists_sha256	$(sha "$DOCROOT/leadlists.php")
landing_marker	<title>Core-Distro | Automated B2B Lead Generation</title>
live_only	durable_scrape_worker.php	$(sha "$DOCROOT/durable_scrape_worker.php")	$(size "$DOCROOT/durable_scrape_worker.php")
live_only	agents_dashboard_json.php	$(sha "$DOCROOT/agents_dashboard_json.php")	$(size "$DOCROOT/agents_dashboard_json.php")
live_only	geo_data/geo_admin_regions.sql	$(sha "$DOCROOT/geo_data/geo_admin_regions.sql")	$(size "$DOCROOT/geo_data/geo_admin_regions.sql")
live_only	geo_data/geo_countries.sql	$(sha "$DOCROOT/geo_data/geo_countries.sql")	$(size "$DOCROOT/geo_data/geo_countries.sql")
live_only	nc_assets/css/style.css	$(sha "$DOCROOT/nc_assets/css/style.css")	$(size "$DOCROOT/nc_assets/css/style.css")
live_only	Lead Engine/cron_drip.php	$(sha "$DOCROOT/Lead Engine/cron_drip.php")	$(size "$DOCROOT/Lead Engine/cron_drip.php")
route	/index.php	200
route	/login.php	200
route	/pricing.php	302
route	/register.php	200
route	/forgot_password.php	200
route	/reset_password.php	200
route	/public_list.php	404
route	/leadlists.php	302
route	/admin.php	302
route	/dashboard.php	302
route	/subscription.php	302
route	/api_keys.php	302
route	/api_dashboard.php	302
route	/logout.php	200
route	/maps_proxy.php	401
route	/log_api_call.php	401
route	/api_wrapper.php	404
route	/webhook_scrape.php	400
route	/llms.txt	200
route	/robots.txt	200
route	/sitemap.xml	200
route	/assets/logo.svg	200
surface	storefront	http://127.0.0.1:MAINPORT/storefront	200	$(size "$DOCROOT/storefront")
surface	staging	http://127.0.0.1:MAINPORT/staging	200	$(size "$DOCROOT/staging")
surface	elevatesci	http://127.0.0.1:MAINPORT/elevatesci	200	$(size "$DOCROOT/elevatesci")
surface	agents_ip	http://127.0.0.1:AGENTSPORT/	301
EOF

# ── the fixture servers ─────────────────────────────────────────────────────
MAIN_PORT=$(free_port)
AGENT_PORT=$(free_port)
RETIRED_PORT=$(free_port)
sed -i "s|MAINPORT|$MAIN_PORT|g; s|AGENTSPORT|$AGENT_PORT|g" "$BASE"
python3 "$SERVER" "$DOCROOT" "$BASE" main "$MAIN_PORT" >"$TMP/main.log" 2>&1 & PIDS+=("$!")
python3 "$SERVER" "$DOCROOT" "$BASE" agents "$AGENT_PORT" >"$TMP/agents.log" 2>&1 & PIDS+=("$!")
python3 "$SERVER" "$DOCROOT" "$BASE" retired "$RETIRED_PORT" >"$TMP/retired.log" 2>&1 & PIDS+=("$!")

wait_for_port() {
  local port="$1" i
  for i in $(seq 1 50); do
    if python3 - "$port" <<'PY' 2>/dev/null
import socket, sys
s = socket.socket()
s.settimeout(0.2)
sys.exit(0 if s.connect_ex(("127.0.0.1", int(sys.argv[1]))) == 0 else 1)
PY
    then return 0; fi
    sleep 0.1
  done
  return 1
}
for p in "$MAIN_PORT" "$AGENT_PORT" "$RETIRED_PORT"; do
  if ! wait_for_port "$p"; then
    printf 'FATAL: fixture server on port %s did not start\n' "$p"
    exit 2
  fi
done

GATE_ARGS=(
  --host-root "$DOCROOT"
  --base-url "http://127.0.0.1:$MAIN_PORT"
  --legacy-url "http://127.0.0.1:$RETIRED_PORT/"
  --baseline "$BASE"
  --schema-digest "$(printf 'fixture-schema-dump' | sha256sum | cut -d' ' -f1)"
  --repo "$TMP/no-such-product-repo"
  --timeout 15
)

# ── 1. the good fixture passes ──────────────────────────────────────────────
out=$(bash "$GATE" "${GATE_ARGS[@]}" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  ok "good fixture" "the gate exits 0 ($(printf '%s' "$out" | grep -m1 '^SUMMARY'))"
else
  bad "good fixture" "the gate exited $rc: $(printf '%s' "$out" | grep -E '^(A[0-9]+|SUMMARY|VERDICT)' | head -20)"
fi

# ── 2. the good fixture is idempotent and read-only ────────────────────────
before=$(cd "$DOCROOT" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum)
out2=$(bash "$GATE" "${GATE_ARGS[@]}" 2>&1); rc2=$?
after=$(cd "$DOCROOT" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum)
if [ "$rc2" -eq 0 ] && [ "$before" = "$after" ]; then
  ok "idempotent and read-only" "two runs, same verdict, fixture tree byte-identical"
else
  bad "idempotent and read-only" "exit=$rc2, fixture digest before=${before:0:12} after=${after:0:12}"
fi

# ── 3. artifact mode passes against the fixture ─────────────────────────────
ART="$TMP/artifact"
mkdir -p "$ART/assets"
# the artifact is the payload: everything the host serves except the
# live-only components and the allowlisted extras
for f in index.php login.php register.php forgot_password.php reset_password.php logout.php \
         pricing.php leadlists.php admin.php dashboard.php subscription.php api_keys.php \
         api_dashboard.php public_list.php api_wrapper.php maps_proxy.php log_api_call.php \
         webhook_scrape.php llms.txt robots.txt sitemap.xml storefront staging elevatesci \
         core-distro-mark-light.webp core-distro-mark-navy.webp; do
  cp "$DOCROOT/$f" "$ART/$f"
done
for f in saas-toast.js saas-toast.css logo.svg; do
  cp "$DOCROOT/assets/$f" "$ART/assets/$f"
done
out=$(bash "$GATE" "${GATE_ARGS[@]}" --artifact "$ART" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  ok "artifact mode" "the gate exits 0 with --artifact ($(printf '%s' "$out" | grep -m1 -E '^A2'))"
else
  bad "artifact mode" "the gate exited $rc: $(printf '%s' "$out" | grep -E '^(A[23]|SUMMARY|VERDICT)' | head -10)"
fi

# ── 4. one deliberately broken assertion is detected ───────────────────────
mv "$DOCROOT/assets/saas-toast.js" "$TMP/saas-toast.js.hidden"
out=$(bash "$GATE" "${GATE_ARGS[@]}" 2>&1); rc=$?
mv "$TMP/saas-toast.js.hidden" "$DOCROOT/assets/saas-toast.js"
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qE '^A10 +toast-live +FAIL'; then
  ok "broken assertion detected" "removing assets/saas-toast.js makes A10 FAIL and the gate exits $rc"
else
  bad "broken assertion detected" "expected a non-zero exit and an A10 FAIL, got exit=$rc: $(printf '%s' "$out" | grep -E '^A10' | head -3)"
fi

# ── 5. the JSON mode is machine readable ───────────────────────────────────
out=$(bash "$GATE" "${GATE_ARGS[@]}" --json 2>/dev/null); rc=$?
if printf '%s' "$out" | jq -e '.gate == "CORE-100" and (.assertions | length) == 15 and (.summary.total == 15)' >/dev/null 2>&1; then
  ok "json mode" "jq accepts the output: 15 assertions, summary total 15"
else
  bad "json mode" "the JSON output did not validate: $(printf '%s' "$out" | head -5)"
fi

# ── 6. the help documents the flags ─────────────────────────────────────────
out=$(bash "$GATE" --help 2>&1); rc=$?
missing=""
for flag in --artifact --host-root --json --baseline --only --skip --timeout; do
  printf '%s' "$out" | grep -q -- "$flag" || missing+=" $flag"
done
if [ "$rc" -eq 0 ] && [ -z "$missing" ]; then
  ok "help" "--help exits 0 and documents every flag"
else
  bad "help" "exit=$rc, undocumented:$missing"
fi

printf 'SUMMARY total=%d failed=%d\n' "$((passed+failed))" "$failed"
[ "$failed" -eq 0 ] || exit 1
exit 0
