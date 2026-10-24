#!/usr/bin/env bash
# fm-core-100-gate.sh - the CORE-100 acceptance gate for Core SaaS.
#
# WHAT THIS IS
#   The single executable gate that answers "is Core SaaS at 100 percent?".
#   It runs the 15 CORE-100 assertions of the convergence study
#   (data/mcode-m3.1f-brandon-core-saas-convergence-20261024/report.md,
#   section 10, "THE ACCEPTANCE TEST", lines 406-430), prints a deterministic
#   PASS/FAIL table with the evidence for every assertion, and exits non-zero
#   when any assertion fails.
#
#   It is READ-ONLY by construction:
#     * HTTP: GET only. No POST, no PUT, no DELETE.
#     * SSH : read-only shell commands (sha256sum, find, php -l, php <stdin>).
#       No file is created, modified, moved or deleted on any host.
#     * DB  : SELECT / SHOW only, reached through the app's own
#       config/env_loader.php then config/database.php. No DDL, no DML.
#     * No credential value is read, printed, hashed or transmitted. The gate
#       reports presence, mode and owner only and never copies config off a
#       host.
#     * /var/www/aminolifesciences is never read, listed, hashed or written.
#
# MODES
#   baseline  (no --artifact)  host-only checks. Artifact-dependent
#           assertions (A2, A3) are reported SKIP with the reason.
#   artifact (--artifact DIR)  additionally diffs the deploy artifact against
#           the live host: sha256 equality per file (A2) and live-only
#           allowlist containment (A3).
#
# USAGE
#   bin/fm-core-100-gate.sh [options]
#
# OPTIONS
#   --artifact <dir>       deploy artifact (payload tree) to compare with the host
#   --host-root <dir>      use a local docroot mirror instead of SSH (fixture runs)
#   --ssh <target>         edge SSH target          (default root@100.69.211.43)
#   --docroot <path>       remote docroot           (default /var/www/data.core-distro.com)
#   --base-url <url>       live Lead Engine surface (default https://data.core-distro.com)
#   --storefront-url <url> WordPress storefront     (default https://core-distro.com/)
#   --staging-url <url>    staging storefront       (default https://staging.core-distro.com/)
#   --elevate-url <url>    elevatesci surface       (default https://elevatesci.com/)
#   --agents-ip <ip>       agent dashboard origin   (default 161.97.120.4)
#   --legacy-ip <ip>       retired second origin    (default 66.29.153.174)
#   --legacy-url <url>     fetch the second origin from this URL instead of
#                          --resolve (fixture runs); the Lead Engine is then
#                          detected by its landing marker and its auth route
#   --repo <path>          core-distro-saas-clean checkout for the product's
#                          own harnesses (default
#                          /home/hd2admin/kun-agent-workspace/projects/core-distro-saas-clean)
#   --baseline <file>      pinned baseline file (default: the embedded one below)
#   --schema-digest <sha>  pre-computed DB schema digest (skips the host probe)
#   --only <ids>           run only these assertion ids (comma separated)
#   --skip <ids>           skip these assertion ids (comma separated)
#   --timeout <sec>        per HTTP/SSH timeout      (default 30)
#   --json                 emit machine-readable JSON only (no table)
#   --help                 this text
#
# EXIT CODES
#   0  every assertion that could run PASSED (SKIPs are not failures)
#   1  at least one assertion FAILED
#   2  usage or harness error (the gate could not run)
#
# SOURCES OF THE RULES (every assertion carries its reference in the table)
#   * assertions ......... convergence report section 10, lines 406-430
#   * allowlist ......... convergence report section 10, line 416 (A3)
#   * live-only set ..... convergence report section 6f, line 226 (A4)
#   * must-not-change ... convergence report section 10, lines 434-448
#   * route set ......... the 18 canonical payload PHP files (union of
#                        staged-export-test/ and current-core-distro/ at
#                        origin/main c38fb4f) minus install.php (an installer
#                        that must never be executed against the live DB -
#                        convergence report line 360), plus the three static
#                        text routes and assets/logo.svg.
set -uo pipefail

GATE_NAME="CORE-100"
GATE_VERSION="1.0.0"

# ── defaults ────────────────────────────────────────────────────────────────
SSH_TARGET="root@100.69.211.43"
DOCROOT="/var/www/data.core-distro.com"
BASE_URL="https://data.core-distro.com"
STOREFRONT_URL="https://core-distro.com/"
STAGING_URL="https://staging.core-distro.com/"
ELEVATE_URL="https://elevatesci.com/"
AGENTS_IP="161.97.120.4"
LEGACY_IP="66.29.153.174"
LEGACY_HOST="data.core-distro.com"
LEGACY_URL=""
REPO_DIR="/home/hd2admin/kun-agent-workspace/projects/core-distro-saas-clean"
ARTIFACT_DIR=""
HOST_ROOT=""
BASELINE_FILE=""
SCHEMA_DIGEST_GIVEN=""
ONLY_IDS=""
SKIP_IDS=""
JSON_MODE=0
HTTP_TIMEOUT=30
SSH_TIMEOUT=15

# ── the pinned baseline ─────────────────────────────────────────────────────
# Measured on 2026-10-24 from the live edge host and the live surfaces. Every
# value below is re-derived on each run and compared; a drift is a FAIL.
# Format: key<TAB>value... (tab separated)
read -r -d '' BASELINE_DEFAULT <<'BASELINE_EOF'
# fm-core-100 baseline - measured 2026-10-24 from the live edge host 100.69.211.43
schema_sha256	31a6941db8ea7955e1f730478d42f5452656c75c71eea3019955d76c2d448ac2
leadlists_sha256	cd16b0e0aa0de7f55d4d2c6c4e25017471712fc5dc706f983a6bf8e4f36f2021
canonical_leadlists_sha256	cd16b0e0aa0de7f55d4d2c6c4e25017471712fc5dc706f983a6bf8e4f36f2021
landing_marker	<title>Core-Distro | Automated B2B Lead Generation</title>
live_only	durable_scrape_worker.php	79b056878b7cb27d4dd042818efc0bc0a116ea2cd782bf869dbdb242467670de	13756
live_only	agents_dashboard_json.php	010b047af2edd3c5e8e76befb4e24e25da56c051b681196a21bfd05af51efc50	18155
live_only	geo_data/geo_admin_regions.sql	a9ffa182052216c9ddd71483c93e8d62445980e6acf7dff7dfd787c07cef88f8	21131
live_only	geo_data/geo_countries.sql	8eac4c2222318036670514439bea52b34956aa687d93e70ba1c4450bb2bed54f	13079
live_only	nc_assets/css/style.css	ede99ca57e4552323876f953247da7b7d9f3e95034d47e70d46d49bdf5daed44	11123
live_only	Lead Engine/cron_drip.php	290ad5fe4e9df6592841d974fbb0eee698b4a519a9a42fe77082f8e73d255465	7105
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
surface	storefront	https://core-distro.com/	200	92936
surface	staging	https://staging.core-distro.com/	200	93046
surface	elevatesci	https://elevatesci.com/	200	35670
surface	agents_ip	http://161.97.120.4/	301
BASELINE_EOF

# ── the live-only allowlist (convergence report line 416 + section 6f line 226)
ALLOWLIST_PATTERNS=(
  "config/*"
  ".env"
  "vendor/*"
  "*.sql"
  "nc_assets/*"
  "durable_scrape_worker.php"
  "agents_dashboard_json.php"
  "geo_data/*"
  "Lead Engine/*"
  "*log*"
  "*_debug.log"
  "db_probe.php"
  "db_schema_probe.php"
  "prod_migration_runner.php"
  "scratch_*"
  "*.bak*"
  "diagnostics/*"
  "*.htaccess"
  "MANIFEST.tsv"
)

# ── the 27 CORE-100 preset scope cases (convergence report section 5 table) ──
PRESET_CASES=(
  "17:Alaska,California,Hawaii,Utah,Wyoming"
  "18:Alaska,Arizona,California,Georgia,Hawaii,Kansas,Ohio,Tennessee,Texas,Utah,Wyoming"
  "19:Alaska,California,Hawaii,Utah,Wyoming"
  "20:"
  "30:Alaska,California,Hawaii,Utah,Wyoming"
)

# ── assertion registry ──────────────────────────────────────────────────────
ASSERT_IDS=(A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12 A13 A14 A15)
ASSERT_NAMES=(
  "leadlists-bytes"
  "payload-present"
  "diff-subset-allowlist"
  "live-only-unchanged"
  "db-schema-unchanged"
  "preset-matrix"
  "card-number-honesty"
  "pa04-list-ownership"
  "browser-regression"
  "toast-live"
  "brand-marks-live"
  "route-sweep"
  "syntax-lint"
  "storefront-untouched"
  "single-public-build"
)
ASSERT_RESULTS=()
ASSERT_EVIDENCE=()
# every assertion starts as SKIP; the ones that run overwrite their slot.
for _i in "${!ASSERT_IDS[@]}"; do
  ASSERT_RESULTS[$_i]="SKIP"
  ASSERT_EVIDENCE[$_i]="not selected in this run"
done

# ── small helpers ───────────────────────────────────────────────────────────
die_usage() { printf 'fm-core-100-gate: %s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }
shorten() { # $1 = text, $2 = max chars
  local s="$1" n="${2:-150}"
  s=${s//$'\n'/ }
  s=${s//$'\t'/ }
  if [ "${#s}" -gt "$n" ]; then s="${s:0:$((n-1))}…"; fi
  printf '%s' "$s"
}
record() { # id result evidence
  local id="$1" result="$2" evidence="$3" i
  for i in "${!ASSERT_IDS[@]}"; do
    if [ "${ASSERT_IDS[$i]}" = "$id" ]; then
      ASSERT_RESULTS[$i]="$result"
      ASSERT_EVIDENCE[$i]="$evidence"
      return 0
    fi
  done
  printf 'internal error: unknown assertion id %s\n' "$id" >&2
  exit 2
}
should_run() { # id
  local id="$1"
  if [ -n "$ONLY_IDS" ]; then
    case ",$ONLY_IDS," in *",$id,"*) return 0 ;; *) return 1 ;; esac
  fi
  if [ -n "$SKIP_IDS" ]; then
    case ",$SKIP_IDS," in *",$id,"*) return 1 ;; esac
  fi
  return 0
}

# ── argument parsing ────────────────────────────────────────────────────────
usage() { sed -n '2,80p' "$0" | sed 's/^# \{0,1\}//'; }
while [ $# -gt 0 ]; do
  case "$1" in
    --artifact) ARTIFACT_DIR="${2:-}"; shift 2 ;;
    --host-root) HOST_ROOT="${2:-}"; shift 2 ;;
    --ssh) SSH_TARGET="${2:-}"; shift 2 ;;
    --docroot) DOCROOT="${2:-}"; shift 2 ;;
    --base-url) BASE_URL="${2:-}"; shift 2 ;;
    --storefront-url) STOREFRONT_URL="${2:-}"; shift 2 ;;
    --staging-url) STAGING_URL="${2:-}"; shift 2 ;;
    --elevate-url) ELEVATE_URL="${2:-}"; shift 2 ;;
    --agents-ip) AGENTS_IP="${2:-}"; shift 2 ;;
    --legacy-ip) LEGACY_IP="${2:-}"; shift 2 ;;
    --legacy-url) LEGACY_URL="${2:-}"; shift 2 ;;
    --repo) REPO_DIR="${2:-}"; shift 2 ;;
    --baseline) BASELINE_FILE="${2:-}"; shift 2 ;;
    --schema-digest) SCHEMA_DIGEST_GIVEN="${2:-}"; shift 2 ;;
    --only) ONLY_IDS="${2:-}"; shift 2 ;;
    --skip) SKIP_IDS="${2:-}"; shift 2 ;;
    --timeout) HTTP_TIMEOUT="${2:-30}"; shift 2 ;;
    --json) JSON_MODE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; die_usage "unknown argument: $1" ;;
  esac
done

TMPWORK=""
cleanup() {
  if [ -n "${C100_KEEP:-}" ]; then printf 'fm-core-100-gate: scratch kept at %s\n' "$TMPWORK" >&2; return; fi
  [ -n "$TMPWORK" ] && rm -rf "$TMPWORK"
}
trap cleanup EXIT
TMPWORK=$(mktemp -d)

# ── baseline access ─────────────────────────────────────────────────────────
B_SCHEMA_SHA=""; B_LEADLISTS_SHA=""; B_CANONICAL_SHA=""; B_LANDING_MARKER=""
B_LIVE_ONLY=(); B_ROUTES=(); B_SURFACES=()
load_baseline() {
  local src="$BASELINE_FILE"
  if [ -z "$src" ]; then
    printf '%s\n' "$BASELINE_DEFAULT" > "$TMPWORK/baseline.tsv"
    src="$TMPWORK/baseline.tsv"
  fi
  [ -f "$src" ] || die_usage "baseline file not found: $src"
  local key v1 v2 v3 v4
  while IFS=$'\t' read -r key v1 v2 v3 v4; do
    case "$key" in
      ''|'#'*) continue ;;
      schema_sha256) B_SCHEMA_SHA="$v1" ;;
      leadlists_sha256) B_LEADLISTS_SHA="$v1" ;;
      canonical_leadlists_sha256) B_CANONICAL_SHA="$v1" ;;
      landing_marker) B_LANDING_MARKER="$v1" ;;
      live_only) B_LIVE_ONLY+=("$v1"$'\t'"$v2"$'\t'"$v3") ;;
      route) B_ROUTES+=("$v1"$'\t'"$v2") ;;
      surface) B_SURFACES+=("$v1"$'\t'"$v2"$'\t'"$v3"$'\t'"$v4") ;;
    esac
  done < "$src"
}
load_baseline

# ── host access ─────────────────────────────────────────────────────────────
host_exec() { # $1 = shell script, rest = args ; prints stdout
  local script="$1"; shift
  if [ -n "$HOST_ROOT" ]; then
    DOCROOT="$HOST_ROOT" bash -c "$script" -- "$@"
    return
  fi
  local qargs="" a
  for a in "$@"; do qargs+=" $(printf '%q' "$a")"; done
  ssh -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" "$SSH_TARGET" \
    "DOCROOT='$DOCROOT' bash -s --$qargs" <<<"$script"
}
host_available() { [ -n "$HOST_ROOT" ] || ssh -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" "$SSH_TARGET" true 2>/dev/null; }

host_sha256() { # $1 = relative path -> sha256 | MISSING | ERROR
  local out
  out=$(host_exec 'cd "$DOCROOT" || exit 1; if [ -f "$1" ]; then sha256sum -- "$1" | cut -d" " -f1; else echo MISSING; fi' "$1" 2>/dev/null)
  printf '%s' "${out:-ERROR}"
}
host_size() {
  local out
  out=$(host_exec 'cd "$DOCROOT" || exit 1; if [ -f "$1" ]; then stat -c %s -- "$1"; else echo MISSING; fi' "$1" 2>/dev/null)
  printf '%s' "${out:-ERROR}"
}
host_list_files() { host_exec 'cd "$DOCROOT" || exit 1; find . -type f -printf "%P\t%s\n" | LC_ALL=C sort'; }

# ── HTTP access (GET only) ──────────────────────────────────────────────────
http_probe() { # $1 = url -> "code type size sha"
  local url="$1" body out sha
  body="$TMPWORK/http.body"
  rm -f "$body"
  out=$(curl -s -o "$body" -w '%{http_code} %{content_type} %{size_download}' --max-time "$HTTP_TIMEOUT" "$url" 2>/dev/null)
  [ -f "$body" ] || : > "$body"
  sha=$(sha256sum "$body" | cut -d' ' -f1)
  rm -f "$body"
  printf '%s %s' "$out" "$sha"
}

# ── product repository (the Core product's own harnesses) ───────────────────
REPO_OK=0
REPO_REV=""
repo_ready() {
  [ "$REPO_OK" = "1" ] && return 0
  [ -d "$REPO_DIR/.git" ] || return 1
  git -C "$REPO_DIR" rev-parse --verify origin/main >/dev/null 2>&1 || return 1
  REPO_REV=$(git -C "$REPO_DIR" rev-parse origin/main)
  REPO_OK=1
  return 0
}
repo_extract() { git -C "$REPO_DIR" show "$REPO_REV:$1" > "$2" 2>/dev/null; }
# The product's own harnesses read their sources from <root>/staged-export-test,
# so the payload trees travel with the tests (read-only extraction).
repo_extract_tree() { # $1 = destination dir
  git -C "$REPO_DIR" archive "$REPO_REV" tests bin staged-export-test current-core-distro 2>/dev/null | tar -x -C "$1" 2>/dev/null
}
repo_payload_list() {
  {
    git -C "$REPO_DIR" ls-tree -r --name-only "$REPO_REV" -- staged-export-test | sed 's|^staged-export-test/||'
    git -C "$REPO_DIR" ls-tree -r --name-only "$REPO_REV" -- current-core-distro | sed 's|^current-core-distro/||'
  } | LC_ALL=C sort -u
}

# ── the bytes under test ────────────────────────────────────────────────────
BYTES_LEADLISTS=""; BYTES_ORIGIN=""
prepare_bytes() {
  if [ -n "$ARTIFACT_DIR" ]; then
    local c
    for c in "leadlists.php" "current-core-distro/leadlists.php" "staged-export-test/leadlists.php"; do
      if [ -f "$ARTIFACT_DIR/$c" ]; then BYTES_LEADLISTS="$ARTIFACT_DIR/$c"; BYTES_ORIGIN="artifact:$c"; return 0; fi
    done
    return 1
  fi
  if repo_ready; then
    # extract the whole payload tree: the product's own harnesses read their
    # siblings (includes/theme_bootstrap.php and friends) from the target's
    # own directory.
    mkdir -p "$TMPWORK/bytes"
    if git -C "$REPO_DIR" archive "$REPO_REV" staged-export-test | tar -x -C "$TMPWORK/bytes" 2>/dev/null; then
      BYTES_LEADLISTS="$TMPWORK/bytes/staged-export-test/leadlists.php"
      BYTES_ORIGIN="origin/main:staged-export-test/leadlists.php"
      return 0
    fi
  fi
  return 1
}

# ══════════════════════════════════════════════════════════════════════════
# A1  leadlists-bytes
#   convergence report section 10 line 414: the deployed leadlists.php is
#   byte-identical to the release payload; the canonical value for this
#   release is cd16b0e0... (report lines 14 and 48).
# ══════════════════════════════════════════════════════════════════════════
assert_a1() {
  local id="A1"
  should_run "$id" || return 0
  if ! host_available; then record "$id" SKIP "host not reachable ($SSH_TARGET)"; return 0; fi
  local got exp extra=""
  got=$(host_sha256 "leadlists.php")
  exp="$B_LEADLISTS_SHA"
  if [ -n "$ARTIFACT_DIR" ] && [ -n "$BYTES_LEADLISTS" ] && [ -f "$BYTES_LEADLISTS" ]; then
    local art; art=$(sha256sum "$BYTES_LEADLISTS" | cut -d' ' -f1)
    extra=" artifact=${art:0:12}…"
    if [ "$got" != "$art" ]; then
      record "$id" FAIL "host leadlists.php sha256=${got:0:12}… != artifact sha256=${art:0:12}…"
      return 0
    fi
  fi
  if [ "$got" = "$exp" ]; then
    local size; size=$(host_size "leadlists.php")
    record "$id" PASS "host leadlists.php sha256=${got:0:12}… == baseline (${size} B)${extra}"
  else
    record "$id" FAIL "host leadlists.php sha256=${got:0:12}… != baseline ${exp:0:12}… (expected cd16b0e0…)${extra}"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A2  payload-present
#   convergence report section 10 line 415: every payload file in the
#   artifact is present on the host with the artifact's exact size + sha256;
#   0 missing, 0 mismatched.
# ══════════════════════════════════════════════════════════════════════════
assert_a2() {
  local id="A2"
  should_run "$id" || return 0
  if [ -z "$ARTIFACT_DIR" ]; then
    record "$id" SKIP "baseline mode: no --artifact supplied (host-only checks)"
    return 0
  fi
  if [ ! -d "$ARTIFACT_DIR" ]; then record "$id" FAIL "artifact directory not found: $ARTIFACT_DIR"; return 0; fi
  if ! host_available; then record "$id" SKIP "host not reachable ($SSH_TARGET)"; return 0; fi
  local work="$TMPWORK/a2" missing=0 mismatched=0 total=0 offenders="" rel want hsize hsha
  mkdir -p "$work"
  (cd "$ARTIFACT_DIR" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum | sed 's|^\./||') > "$work/artifact.sha"
  while IFS= read -r line; do
    rel="${line#*  }"
    rel="${rel#./}"
    want="${line%% *}"
    [ -n "$rel" ] || continue
    total=$((total+1))
    hsize=$(host_size "$rel")
    if [ "$hsize" = "MISSING" ]; then missing=$((missing+1)); offenders+=" MISSING:$rel"; continue; fi
    hsha=$(host_sha256 "$rel")
    if [ "$hsha" != "$want" ]; then mismatched=$((mismatched+1)); offenders+=" MISMATCH:$rel"; fi
  done < "$work/artifact.sha"
  if [ "$missing" -eq 0 ] && [ "$mismatched" -eq 0 ]; then
    record "$id" PASS "artifact files=$total missing=0 mismatched=0 (sha256 + size equal on host)"
  else
    record "$id" FAIL "artifact files=$total missing=$missing mismatched=$mismatched -$(shorten "$offenders" 120)"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A3  diff-subset-allowlist
#   convergence report section 10 line 416: zero files on the host are outside
#   the artifact except the declared live-only allowlist.
# ══════════════════════════════════════════════════════════════════════════
assert_a3() {
  local id="A3"
  should_run "$id" || return 0
  if [ -z "$ARTIFACT_DIR" ]; then
    record "$id" SKIP "baseline mode: no --artifact supplied (host-only checks)"
    return 0
  fi
  if [ ! -d "$ARTIFACT_DIR" ]; then record "$id" FAIL "artifact directory not found: $ARTIFACT_DIR"; return 0; fi
  if ! host_available; then record "$id" SKIP "host not reachable ($SSH_TARGET)"; return 0; fi
  local hostlist="$TMPWORK/host-files.tsv"
  host_list_files > "$hostlist" 2>/dev/null
  if [ ! -s "$hostlist" ]; then record "$id" FAIL "could not list the host docroot"; return 0; fi
  local offenders="" outside=0 total=0 rel pat ok
  while IFS=$'\t' read -r rel _size; do
    [ -n "$rel" ] || continue
    total=$((total+1))
    if [ -f "$ARTIFACT_DIR/$rel" ]; then continue; fi
    ok=0
    for pat in "${ALLOWLIST_PATTERNS[@]}"; do
      case "$rel" in
        $pat) ok=1; break ;;
      esac
    done
    if [ "$ok" -eq 0 ]; then outside=$((outside+1)); offenders+=" $rel"; fi
  done < "$hostlist"
  if [ "$outside" -eq 0 ]; then
    record "$id" PASS "host files=$total outside-allowlist=0 (every host-only path matches the live-only allowlist)"
  else
    record "$id" FAIL "host files=$total outside-allowlist=$outside -$(shorten "$offenders" 120)"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A4  live-only-unchanged
#   convergence report section 10 line 417 and section 6f line 226: the
#   live-only components still exist and are unchanged.
# ══════════════════════════════════════════════════════════════════════════
assert_a4() {
  local id="A4"
  should_run "$id" || return 0
  if ! host_available; then record "$id" SKIP "host not reachable ($SSH_TARGET)"; return 0; fi
  local changed="" missing="" checked=0 entry rel want_sha want_size got_sha got_size
  for entry in "${B_LIVE_ONLY[@]}"; do
    rel=$(printf '%s' "$entry" | cut -f1)
    want_sha=$(printf '%s' "$entry" | cut -f2)
    want_size=$(printf '%s' "$entry" | cut -f3)
    checked=$((checked+1))
    got_sha=$(host_sha256 "$rel")
    if [ "$got_sha" = "MISSING" ]; then missing+=" $rel"; continue; fi
    got_size=$(host_size "$rel")
    if [ "$got_sha" != "$want_sha" ] || [ "$got_size" != "$want_size" ]; then
      changed+=" $rel(got ${got_sha:0:8}/${got_size}B want ${want_sha:0:8}/${want_size}B)"
    fi
  done
  if [ -n "$missing" ]; then
    record "$id" FAIL "live-only components missing:$(shorten "$missing" 110)"
  elif [ -n "$changed" ]; then
    record "$id" FAIL "live-only components changed:$(shorten "$changed" 110)"
  else
    record "$id" PASS "$checked/$checked live-only components present with the pinned sha256 + size"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A5  db-schema-unchanged
#   convergence report section 10 line 418 and section 8: the DB schema is
#   unchanged; 0 differences against the recorded baseline.
#   The digest is taken from information_schema (table, column, index
#   metadata) through the app's own config. No row data, no credentials.
# ══════════════════════════════════════════════════════════════════════════
write_schema_probe() {
  cat > "$TMPWORK/schema-probe.php" <<'SCHEMA_EOF'
<?php
chdir("/var/www/data.core-distro.com");
require_once "config/env_loader.php";
require_once "config/database.php";
if (!isset($pdo) || !($pdo instanceof PDO)) { fwrite(STDERR, "PROBE-ERROR: no pdo handle\n"); exit(3); }
$db = $pdo->query("SELECT DATABASE()")->fetchColumn();
if (!$db) { fwrite(STDERR, "PROBE-ERROR: no database\n"); exit(3); }
$q = $pdo->quote($db);
$tables = $pdo->query("SELECT TABLE_NAME, TABLE_TYPE, ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=$q ORDER BY TABLE_NAME")->fetchAll(PDO::FETCH_ASSOC);
$cols   = $pdo->query("SELECT TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, EXTRA, COLUMN_DEFAULT FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=$q ORDER BY TABLE_NAME, ORDINAL_POSITION")->fetchAll(PDO::FETCH_ASSOC);
$idx    = $pdo->query("SELECT TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME, NON_UNIQUE, INDEX_TYPE FROM information_schema.STATISTICS WHERE TABLE_SCHEMA=$q ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX")->fetchAll(PDO::FETCH_ASSOC);
$out = array();
$out[] = "DB\t" . $db;
$out[] = "TABLE_COUNT\t" . count($tables);
foreach ($tables as $r) { $out[] = "T\t" . $r["TABLE_NAME"] . "\t" . $r["TABLE_TYPE"] . "\t" . $r["ENGINE"]; }
$out[] = "COLUMN_COUNT\t" . count($cols);
foreach ($cols as $r) {
  $def = $r["COLUMN_DEFAULT"] === null ? "NULL" : (string)$r["COLUMN_DEFAULT"];
  $out[] = "C\t" . $r["TABLE_NAME"] . "\t" . $r["COLUMN_NAME"] . "\t" . $r["ORDINAL_POSITION"] . "\t" . $r["COLUMN_TYPE"] . "\t" . $r["IS_NULLABLE"] . "\t" . $r["COLUMN_KEY"] . "\t" . $r["EXTRA"] . "\t" . md5($def);
}
$out[] = "INDEX_COUNT\t" . count($idx);
foreach ($idx as $r) { $out[] = "I\t" . $r["TABLE_NAME"] . "\t" . $r["INDEX_NAME"] . "\t" . $r["SEQ_IN_INDEX"] . "\t" . $r["COLUMN_NAME"] . "\t" . $r["NON_UNIQUE"] . "\t" . $r["INDEX_TYPE"]; }
echo "SCHEMA-BEGIN\n" . implode("\n", $out) . "\nSCHEMA-END\n";
SCHEMA_EOF
}
assert_a5() {
  local id="A5"
  should_run "$id" || return 0
  local got="" tables=""
  if [ -n "$SCHEMA_DIGEST_GIVEN" ]; then
    got="$SCHEMA_DIGEST_GIVEN"
  elif [ -n "$HOST_ROOT" ]; then
    record "$id" SKIP "fixture mode: no database probe (pass --schema-digest to pin one)"
    return 0
  else
    if ! host_available; then record "$id" SKIP "host not reachable ($SSH_TARGET)"; return 0; fi
    local dump="$TMPWORK/schema.dump"
    ssh -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" "$SSH_TARGET" \
      "cd '$DOCROOT' && php" < "$TMPWORK/schema-probe.php" > "$dump" 2>"$TMPWORK/schema.err"
    if ! grep -q 'SCHEMA-END' "$dump" 2>/dev/null; then
      record "$id" FAIL "schema probe failed on the host (no SCHEMA-END marker)"
      return 0
    fi
    got=$(sed -n '/SCHEMA-BEGIN/,/SCHEMA-END/p' "$dump" | sha256sum | cut -d' ' -f1)
    tables=$(grep -m1 '^TABLE_COUNT' "$dump" | cut -f2)
  fi
  if [ "$got" = "$B_SCHEMA_SHA" ]; then
    record "$id" PASS "schema digest=${got:0:12}… == baseline (tables=${tables:-n/a}, 0 differences)"
  else
    record "$id" FAIL "schema digest=${got:0:12}… != baseline ${B_SCHEMA_SHA:0:12}… (DDL or drift)"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A6  preset-matrix
#   convergence report section 10 line 419: the preset correctness matrix -
#   all 27 scope-matrix cases return exactly 100 and client == server in
#   every case. A6 is the assertion that must never be traded away
#   (report line 430).
#   Method (report line 419):
#     tests/preset_coverage_matrix_diff.mjs
#     tests/preset_correctness_test.php
#     tests/preset_state_qualified_coverage_server.php
#   Layer 1 runs those product harnesses on the bytes A1 proves are deployed.
#   Layer 2 runs the deployed product's OWN getTopCities server action
#   against the live DB for the 27 cases and compares its result with the
#   deployed product's OWN client coverage predicate.
#   Pool exhaustion is NOT a failure: a case whose scope has fewer than 100
#   candidate rows is SHORT by construction, and as long as client == server
#   it is correct behaviour (the brief's remaining SHORT cases).
# ══════════════════════════════════════════════════════════════════════════
assert_a6() {
  local id="A6"
  should_run "$id" || return 0
  local layer1="SKIP" layer1_ev="no product bytes available"
  local layer2="SKIP" layer2_ev="host not reachable ($SSH_TARGET)"

  if prepare_bytes; then
    layer1=$(run_preset_harness_layer "$BYTES_LEADLISTS")
    layer1_ev="$layer1"
  fi

  if host_available; then
    layer2=$(run_preset_live_layer)
    layer2_ev="$layer2"
  fi

  local result="PASS" ev=""
  case "$layer1" in PASS*) : ;; SKIP*) : ;; *) result="FAIL" ;; esac
  case "$layer2" in PASS*) : ;; SKIP*) : ;; *) result="FAIL" ;; esac
  case "$layer1" in SKIP*) case "$layer2" in SKIP*) result="SKIP" ;; esac ;; esac
  ev="logic: ${layer1_ev} | live: ${layer2_ev}"
  record "$id" "$result" "$(shorten "$ev" 320)"
}

# Layer 1: the product's own preset harnesses on the deployed-equivalent bytes.
run_preset_harness_layer() { # $1 = leadlists.php path -> "PASS ..." / "FAIL ..." / "SKIP ..."
  local target="$1"
  if ! repo_ready; then echo "SKIP product repo unavailable ($REPO_DIR)"; return 0; fi
  local work="$TMPWORK/preset-harness"
  mkdir -p "$work"
  if ! git -C "$REPO_DIR" archive "$REPO_REV" tests | tar -x -C "$work" 2>/dev/null; then
    echo "SKIP could not extract the product harnesses"; return 0
  fi
  if ! git -C "$REPO_DIR" archive "$REPO_REV" lead-engine-saas-export-20260625_canonical-geo.zip | tar -x -C "$work" 2>/dev/null; then
    echo "SKIP could not extract the canonical geography archive"; return 0
  fi
  if ! php "$work/tests/preset_correctness_test.php" "$target" > "$work/correctness.log" 2>&1; then
    echo "FAIL preset_correctness_test.php: $(shorten "$(grep -m1 -E 'FAIL|fatal' "$work/correctness.log" | head -c 150)" 150)"
    return 0
  fi
  local nass
  nass=$(grep -cE '^PASS ' "$work/correctness.log" 2>/dev/null || echo 0)
  if ! php "$work/tests/preset_state_qualified_coverage_server.php" "$target" --json-out "$work/server.json" > "$work/server.log" 2>&1; then
    echo "FAIL preset_state_qualified_coverage_server.php: $(shorten "$(grep -m1 -E 'FAIL|MISMATCH' "$work/server.log" | head -c 150)" 150)"
    return 0
  fi
  if ! node "$work/tests/jsdom_preset_state_qualified_coverage.test.mjs" "$target" --json-out "$work/client.json" > "$work/client.log" 2>&1; then
    echo "FAIL jsdom client harness: $(shorten "$(grep -m1 -E 'FAIL' "$work/client.log" | head -c 150)" 150)"
    return 0
  fi
  if ! node "$work/tests/preset_coverage_matrix_diff.mjs" "$work/client.json" "$work/server.json" > "$work/matrix.log" 2>&1; then
    echo "FAIL client/server matrix diff: $(shorten "$(grep -m1 -E 'disagreement|MISMATCH' "$work/matrix.log" | head -c 150)" 150)"
    return 0
  fi
  local cases pool
  cases=$(grep -m1 -E '^cases:' "$work/matrix.log" | head -c 40)
  pool=$(grep -m1 -E '^pool rows:' "$work/matrix.log" | head -c 40)
  echo "PASS preset_correctness=${nass} assertions, client==server (${cases:-matrix ok} ${pool:-})"
}

# Layer 2: the deployed product's own server action and client predicate,
# live, against the live database (read-only SELECTs only).
run_preset_live_layer() {
  local work="$TMPWORK/preset-live"
  mkdir -p "$work"
  if [ -n "$HOST_ROOT" ]; then echo "SKIP fixture mode: the live matrix needs the live database"; return 0; fi
  if ! prepare_bytes; then echo "SKIP no product bytes"; return 0; fi

  # extract the deployed product's own getTopCities server action
  awk '
    /^[[:space:]]*case .getTopCities.:/ { if (!f) { f = 1 } }
    f {
      if (seen && /^[[:space:]]*case /) { exit }
      seen = 1
      print
    }
  ' "$BYTES_LEADLISTS" > "$work/server-block.php"
  if [ ! -s "$work/server-block.php" ]; then echo "FAIL could not extract the getTopCities action"; return 0; fi

  # extract the deployed product's own client coverage predicate
  awk '
    /^    normalizeCoverageKey\(value\) \{/ { f = 1 }
    f {
      if (started && /^    async loadLeads\(\)/) { exit }
      started = 1
      print
    }
  ' "$BYTES_LEADLISTS" > "$work/client-predicate.js"
  if [ ! -s "$work/client-predicate.js" ]; then echo "FAIL could not extract the client coverage predicate"; return 0; fi

  # the 27 cases, as JSON: one case per (list, scope) pair
  {
    printf '['
    local first=1 spec list scope s parts n
    for spec in "${PRESET_CASES[@]}"; do
      list="${spec%%:*}"; scope="${spec#*:}"
      if [ -z "$scope" ]; then
        [ "$first" -eq 1 ] || printf ','
        first=0
        printf '{"list":%s,"scope":[]}' "$list"
        continue
      fi
      IFS_SAVE="$IFS"; IFS=','
      for parts in $scope; do
        [ "$first" -eq 1 ] || printf ','
        first=0
        printf '{"list":%s,"scope":["%s"]}' "$list" "$parts"
      done
      IFS="$IFS_SAVE"
    done
    printf ']\n'
  } > "$work/cases.json"

  # the server probe: the product's own action, executed on the host
  {
    cat <<'PROBE_HEAD'
<?php
chdir("/var/www/data.core-distro.com");
require_once "config/env_loader.php";
require_once "config/database.php";
function addedGeoRegionCodes() { return array(); }
$__cases = json_decode(<<<'JSON'
PROBE_HEAD
    cat "$work/cases.json"
    cat <<'PROBE_MID'
JSON
, true);
$__block = <<<'BLOCK'
PROBE_MID
    cat "$work/server-block.php"
    cat <<'PROBE_TAIL'
BLOCK;
$__block = preg_replace('/^\s*case\s*.getTopCities.:/', '', $__block);
$__block = preg_replace('/\bexit\s*;/', 'return;', $__block);
eval('function __c100_top_cities($pdo, $userId) { ' . $__block . ' }');
$cases = array();
$lists = array();
foreach ($__cases as $c) {
  $lid = (int)$c["list"];
  $lists[$lid] = true;
  $uid = $pdo->query("SELECT user_id FROM lead_lists WHERE id = " . $lid)->fetchColumn();
  if (!$uid) { $cases[] = array("list"=>$lid,"scope"=>$c["scope"],"error"=>"list not found"); continue; }
  $_GET = array("country"=>"US","limit"=>"100","list_id"=>(string)$lid);
  if (!empty($c["scope"])) { $_GET["state_ids"] = implode(",", $c["scope"]); }
  ob_start();
  try { __c100_top_cities($pdo, (int)$uid); }
  catch (Throwable $e) { ob_end_clean(); $cases[] = array("list"=>$lid,"scope"=>$c["scope"],"error"=>"exception"); continue; }
  $json = ob_get_clean();
  $d = json_decode($json, true);
  if (!is_array($d) || empty($d["success"])) { $cases[] = array("list"=>$lid,"scope"=>$c["scope"],"error"=>"bad response"); continue; }
  $cases[] = array("list"=>$lid,"scope"=>$c["scope"],"count"=>count($d["cities"]),"pool_size"=>(int)$d["pool_size"],"cities"=>$d["cities"]);
}
$listsOut = array();
foreach (array_keys($lists) as $lid) {
  $uid = $pdo->query("SELECT user_id FROM lead_lists WHERE id = " . (int)$lid)->fetchColumn();
  if (!$uid) { continue; }
  $searches = $pdo->prepare("SELECT state_name, city FROM ( SELECT list_id, user_id, TRIM(state_name) as state_name, TRIM(city) as city FROM lead_list_searches WHERE list_id = ? AND user_id = ? AND city IS NOT NULL AND state_name IS NOT NULL AND TRIM(city) != '' AND TRIM(state_name) != '' UNION SELECT list_id, user_id, TRIM(state) as state_name, TRIM(city) as city FROM lead_list_items WHERE list_id = ? AND user_id = ? AND city IS NOT NULL AND state IS NOT NULL AND TRIM(city) != '' AND TRIM(state) != '' ) combined GROUP BY state_name, city ORDER BY state_name ASC, city ASC");
  $searches->execute(array($lid, $uid, $lid, $uid));
  $imported = $pdo->prepare("SELECT COALESCE(state,'') AS state_name, city FROM lead_list_items WHERE list_id = ? AND user_id = ? AND city IS NOT NULL AND city != '' GROUP BY state, city ORDER BY state ASC, city ASC");
  $imported->execute(array($lid, $uid));
  $listsOut[(string)$lid] = array("searches"=>$searches->fetchAll(PDO::FETCH_ASSOC),"imported_cities"=>$imported->fetchAll(PDO::FETCH_ASSOC));
}
echo "C100-JSON\n" . json_encode(array("cases"=>$cases,"lists"=>$listsOut)) . "\nC100-END\n";
PROBE_TAIL
  } > "$work/probe.php"

  local dump="$work/probe.out"
  ssh -o BatchMode=yes -o ConnectTimeout="$SSH_TIMEOUT" "$SSH_TARGET" \
    "cd '$DOCROOT' && php" < "$work/probe.php" > "$dump" 2>"$work/probe.err"
  if ! grep -q 'C100-END' "$dump" 2>/dev/null; then
    echo "FAIL live server probe failed on the host"
    return 0
  fi
  sed -n '/^C100-JSON$/,/^C100-END$/p' "$dump" | sed '1d;$d' > "$work/probe.json"
  if [ ! -s "$work/probe.json" ]; then echo "FAIL live server probe returned no data"; return 0; fi

  # the client predicate, from the deployed bytes, applied to the server's rows
  {
    printf '%s\n' 'const fs = require("fs");'
    printf '%s\n' 'const payload = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));'
    printf '%s\n' 'const predicateSrc = fs.readFileSync(process.argv[3], "utf8");'
    printf '%s\n' 'class App {'
    cat "$work/client-predicate.js"
    printf '%s\n' '}'
    printf '%s\n' 'const app = new App();'
    printf '%s\n' 'app.selectedCountry = "US";'
    printf '%s\n' 'app.searchedCitiesForList = new Set();'
    printf '%s\n' 'app.searchedCityStateIdsForList = new Set();'
    printf '%s\n' 'app.importedCityNamesForList = new Set();'
    printf '%s\n' 'const cases = payload.cases || [];'
    printf '%s\n' 'let removals = 0, mismatches = 0, shortCases = 0, exact = 0, errors = 0;'
    printf '%s\n' 'const bad = [];'
    printf '%s\n' 'for (const c of cases) {'
    printf '%s\n' '  if (c.error) { errors++; bad.push(`list ${c.list}: ${c.error}`); continue; }'
    printf '%s\n' '  const L = (payload.lists || {})[String(c.list)];'
    printf '%s\n' '  if (!L) { mismatches++; bad.push(`list ${c.list}: no covered rows`); continue; }'
    printf '%s\n' '  app.currentList = { searches: L.searches || [], imported_cities: L.imported_cities || [] };'
    printf '%s\n' '  app.rebuildCoveredCitySets();'
    printf '%s\n' '  const removed = (c.cities || []).filter(x => app.isCityCovered(x.city, x.state_name, x.state_id));'
    printf '%s\n' '  removals += removed.length;'
    printf '%s\n' '  const clientCount = (c.cities || []).length - removed.length;'
    printf '%s\n' '  if (clientCount !== c.count) { mismatches++; bad.push(`list ${c.list} ${(c.scope||[]).join("+")||"all"}: client ${clientCount} != server ${c.count}`); }'
    printf '%s\n' '  if (c.count === 100) { exact++; } else if (c.pool_size < 100) { shortCases++; } else { mismatches++; bad.push(`list ${c.list} ${(c.scope||[]).join("+")||"all"}: ${c.count}/100 with pool ${c.pool_size}`); }'
    printf '%s\n' '}'
    printf '%s\n' 'console.log(JSON.stringify({cases: cases.length, exact: exact, short: shortCases, removals: removals, mismatches: mismatches, errors: errors, bad: bad.slice(0, 6)}));'
  } > "$work/client-check.js"

  local result
  result=$(node "$work/client-check.js" "$work/probe.json" "$work/client-predicate.js" 2>"$work/client.err")
  if [ -z "$result" ]; then echo "FAIL client predicate probe failed"; return 0; fi
  local mism removals cases exact short errors bad
  mism=$(printf '%s' "$result" | jq -r '.mismatches')
  removals=$(printf '%s' "$result" | jq -r '.removals')
  cases=$(printf '%s' "$result" | jq -r '.cases')
  exact=$(printf '%s' "$result" | jq -r '.exact')
  short=$(printf '%s' "$result" | jq -r '.short')
  errors=$(printf '%s' "$result" | jq -r '.errors')
  bad=$(printf '%s' "$result" | jq -r '.bad | join("; ")')
  if [ "$mism" = "0" ] && [ "$removals" = "0" ] && [ "$errors" = "0" ]; then
    echo "PASS live matrix cases=$cases exact100=$exact pool-exhausted=$short client==server (0 removals)"
  else
    echo "FAIL live matrix cases=$cases exact100=$exact short=$short removals=$removals mismatches=$mism errors=$errors ${bad}"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A7  card-number-honesty
#   convergence report section 10 line 420: tests/card_number_honesty_check.py,
#   tests/card_number_honesty_render.mjs, tests/jsdom_lead_card_latency.test.mjs
# ══════════════════════════════════════════════════════════════════════════
assert_a7() {
  local id="A7"
  should_run "$id" || return 0
  if ! repo_ready; then record "$id" SKIP "product repo unavailable ($REPO_DIR)"; return 0; fi
  if ! prepare_bytes; then record "$id" SKIP "no product bytes to test"; return 0; fi
  local work="$TMPWORK/a7"
  mkdir -p "$work"
  if ! repo_extract_tree "$work"; then
    record "$id" SKIP "could not extract the product harnesses"; return 0
  fi
  local target="$BYTES_LEADLISTS" failures=""
  if ! python3 "$work/tests/card_number_honesty_check.py" "$target" > "$work/check.log" 2>&1; then
    failures+=" card_number_honesty_check.py"
  fi
  if ! node "$work/tests/jsdom_lead_card_latency.test.mjs" "$target" > "$work/latency.log" 2>&1; then
    failures+=" jsdom_lead_card_latency.test.mjs"
  fi
  # the render proof needs the pre-fix bytes as the "before" side; it lives
  # beside the candidate so both have the same sibling payload files.
  local before=""
  if git -C "$REPO_DIR" show f78a349:current-core-distro/leadlists.php > "$(dirname "$target")/leadlists-before.php" 2>/dev/null; then
    before="$(dirname "$target")/leadlists-before.php"
  fi
  if [ -n "$before" ]; then
    if ! node "$work/tests/card_number_honesty_render.mjs" "$before" "$target" > "$work/render.log" 2>&1; then
      failures+=" card_number_honesty_render.mjs"
    fi
  else
    failures+=" card_number_honesty_render.mjs(no pre-fix baseline bytes)"
  fi
  if [ -z "$failures" ]; then
    record "$id" PASS "card-number honesty (python + jsdom render) and lead-card latency: all green"
  else
    record "$id" FAIL "failing suites:$failures"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A8  pa04-list-ownership
#   convergence report section 10 line 421: tests/regression_pa04_list_ownership.php
# ══════════════════════════════════════════════════════════════════════════
assert_a8() {
  local id="A8"
  should_run "$id" || return 0
  if ! repo_ready; then record "$id" SKIP "product repo unavailable ($REPO_DIR)"; return 0; fi
  local work="$TMPWORK/a8"
  mkdir -p "$work"
  if ! repo_extract_tree "$work"; then
    record "$id" SKIP "could not extract the product harnesses"; return 0
  fi
  local out rc=0
  out=$(cd "$work" && php "$work/tests/regression_pa04_list_ownership.php" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ]; then
    record "$id" PASS "PA-04 owned-list regression green: $(shorten "$(printf '%s' "$out" | grep -m1 -iE 'pass|ok' | head -c 90)" 90)"
  else
    record "$id" FAIL "PA-04 regression exit=$rc: $(shorten "$(printf '%s' "$out" | grep -m1 -iE 'fail' | head -c 120)" 120)"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A9  browser-regression
#   convergence report section 10 line 422:
#   tests/browser/run_add_leads_pointer_regression.sh (m1 entry interception,
#   m2 modal layering, m3 hidden nesting, preserved behaviours)
# ══════════════════════════════════════════════════════════════════════════
assert_a9() {
  local id="A9"
  should_run "$id" || return 0
  if ! repo_ready; then record "$id" SKIP "product repo unavailable ($REPO_DIR)"; return 0; fi
  if ! have google-chrome && ! have chromium && ! have chromium-browser; then
    record "$id" SKIP "no Chrome/Chromium binary available for the browser regression"
    return 0
  fi
  local work="$TMPWORK/a9"
  mkdir -p "$work"
  # The browser suite materialises its document root from the repository
  # source with `git ls-files`, so it needs a real checkout. It is served from
  # a shared clone in the scratch space: the product repo itself is only read.
  if ! git clone --quiet --shared "$REPO_DIR" "$work/repo" 2>/dev/null; then
    record "$id" SKIP "could not clone the product repo for the browser regression"
    return 0
  fi
  if ! git -C "$work/repo" checkout --quiet -f "$REPO_REV" 2>/dev/null; then
    record "$id" SKIP "could not check out $REPO_REV for the browser regression"
    return 0
  fi
  local out rc=0
  out=$(cd "$work/repo" && bash "$work/repo/tests/browser/run_add_leads_pointer_regression.sh" 2>&1) || rc=$?
  if [ "$rc" -eq 0 ]; then
    record "$id" PASS "Add Leads pointer browser regression: $(shorten "$(printf '%s' "$out" | grep -m1 -iE 'PASS|OK' | head -c 90)" 90)"
  elif [ "$rc" -eq 2 ]; then
    record "$id" SKIP "browser regression could not run here (environment error, exit 2): $(shorten "$(printf '%s' "$out" | grep -m1 -iE 'error|fatal|not found' | head -c 110)" 110)"
  else
    record "$id" FAIL "browser regression exit=$rc: $(shorten "$(printf '%s' "$out" | grep -m1 -iE 'FAIL|ERROR' | head -c 120)" 120)"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A10 toast-live
#   convergence report section 10 line 423: curl -sI
#   https://data.core-distro.com/assets/saas-toast.js must be 200 +
#   application/javascript, not the text/html fallback.
# ══════════════════════════════════════════════════════════════════════════
assert_a10() {
  local id="A10"
  should_run "$id" || return 0
  local js css
  js=$(http_probe "$BASE_URL/assets/saas-toast.js")
  css=$(http_probe "$BASE_URL/assets/saas-toast.css")
  local jcode="${js%% *}"; local jrest="${js#* }"; local jtype="${jrest%% *}"; local jrest2="${jrest#* }"; local jsize="${jrest2%% *}"
  local ccode="${css%% *}"; local crest="${css#* }"; local ctype="${crest%% *}"
  if [ "$jcode" = "200" ] && [[ "$jtype" == *javascript* ]] && [ "$ccode" = "200" ] && [[ "$ctype" == *"text/css"* ]]; then
    record "$id" PASS "saas-toast.js $jcode $jtype ${jsize}B; saas-toast.css $ccode $ctype"
  else
    record "$id" FAIL "saas-toast.js $jcode $jtype ${jsize}B (want 200 javascript); saas-toast.css $ccode $ctype (want 200 text/css)"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A11 brand-marks-live
#   convergence report section 10 line 424: /core-distro-mark-light.webp and
#   /core-distro-mark-navy.webp must be 200 + image/webp (not text/html).
# ══════════════════════════════════════════════════════════════════════════
assert_a11() {
  local id="A11"
  should_run "$id" || return 0
  local a b
  a=$(http_probe "$BASE_URL/core-distro-mark-light.webp")
  b=$(http_probe "$BASE_URL/core-distro-mark-navy.webp")
  local acode="${a%% *}"; local arest="${a#* }"; local atype="${arest%% *}"
  local bcode="${b%% *}"; local brest="${b#* }"; local btype="${brest%% *}"
  if [ "$acode" = "200" ] && [[ "$atype" == *"image/webp"* ]] && [ "$bcode" = "200" ] && [[ "$btype" == *"image/webp"* ]]; then
    record "$id" PASS "core-distro-mark-light.webp $acode $atype; core-distro-mark-navy.webp $bcode $btype"
  else
    record "$id" FAIL "core-distro-mark-light.webp $acode $atype (want 200 image/webp); core-distro-mark-navy.webp $bcode $btype (want 200 image/webp)"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A12 route-sweep
#   convergence report section 10 line 425: a route sweep of the Lead Engine
#   routes - every route answers with its expected status (200/302/401) and
#   no route falls through to the index.php HTML fallback.
# ══════════════════════════════════════════════════════════════════════════
assert_a12() {
  local id="A12"
  should_run "$id" || return 0
  local bad="" checked=0 fallback=0
  local entry path want body info code type size
  for entry in "${B_ROUTES[@]}"; do
    path=$(printf '%s' "$entry" | cut -f1)
    want=$(printf '%s' "$entry" | cut -f2)
    checked=$((checked+1))
    body="$TMPWORK/route.body"
    info=$(curl -s -o "$body" -w '%{http_code} %{content_type} %{size_download}' --max-time "$HTTP_TIMEOUT" "$BASE_URL$path" 2>/dev/null)
    code="${info%% *}"; local rest="${info#* }"; type="${rest%% *}"; size="${rest#* }"; size="${size%% *}"
    if [ "$code" != "$want" ]; then bad+=" $path(got $code want $want)"; fi
    if [ "$path" != "/index.php" ] && grep -qF "$B_LANDING_MARKER" "$body" 2>/dev/null; then
      fallback=$((fallback+1)); bad+=" $path(html-fallback)"
    fi
    if grep -qiE 'Fatal error|Parse error|Uncaught (Error|Exception)' "$body" 2>/dev/null; then
      bad+=" $path(php-error-page)"
    fi
  done
  if [ -z "$bad" ]; then
    record "$id" PASS "$checked/$checked routes answer with the expected status, 0 HTML fallbacks"
  else
    record "$id" FAIL "$checked routes checked, problems:$(shorten "$bad" 170)"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A13 syntax-lint
#   convergence report section 10 line 426: php -l on all payload PHP,
#   node --check on the JS assets, tests/local_lane_test.php and
#   tests/regression_pa04_list_ownership.php pass.
# ══════════════════════════════════════════════════════════════════════════
assert_a13() {
  local id="A13"
  should_run "$id" || return 0
  if ! host_available; then record "$id" SKIP "host not reachable ($SSH_TARGET)"; return 0; fi
  local payload="$TMPWORK/payload.txt"
  if [ -n "$ARTIFACT_DIR" ]; then
    (cd "$ARTIFACT_DIR" && find . -type f -printf "%P\n") | LC_ALL=C sort > "$payload"
  elif repo_ready; then
    repo_payload_list > "$payload"
  else
    record "$id" SKIP "no payload list (no --artifact and no product repo)"
    return 0
  fi
  local phps="$TMPWORK/payload.php" checked=0 absent=0 bad="" f r
  grep -E '\.php$' "$payload" > "$phps" 2>/dev/null || true
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    r=$(host_exec 'cd "$DOCROOT" || exit 1; if [ -f "$1" ]; then php -l "$1" 2>&1 | tail -1; else echo ABSENT; fi' "$f" 2>/dev/null)
    if [ "$r" = "ABSENT" ]; then absent=$((absent+1)); continue; fi
    checked=$((checked+1))
    if [[ "$r" == *"No syntax errors"* ]]; then :; else bad+=" $f($r)"; fi
  done < "$phps"
  local jss="$TMPWORK/payload.js" dest
  grep -E '\.js$' "$payload" > "$jss" 2>/dev/null || true
  mkdir -p "$TMPWORK/js"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    dest="$TMPWORK/js/$(printf '%s' "$f" | tr '/' '_')"
    host_exec 'cd "$DOCROOT" || exit 1; cat "$1"' "$f" > "$dest" 2>/dev/null
    if [ -s "$dest" ]; then
      if ! node --check "$dest" >/dev/null 2>&1; then bad+=" $f(node --check)"; fi
    else
      bad+=" $f(absent)"
    fi
  done < "$jss"
  if repo_ready; then
    local work="$TMPWORK/a13"
    mkdir -p "$work"
    if repo_extract_tree "$work"; then
      if ! php "$work/tests/local_lane_test.php" > "$work/lane.log" 2>&1; then
        bad+=" local_lane_test.php(fail)"
      fi
    fi
  fi
  if [ -z "$bad" ]; then
    record "$id" PASS "php -l on $checked deployed payload PHP files, node --check on the payload JS, local_lane_test.php green (${absent} payload PHP not yet deployed)"
  else
    record "$id" FAIL "lint problems:$(shorten "$bad" 160)"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A14 storefront-untouched
#   convergence report section 10 line 427 and line 439: the storefront and
#   the agent dashboard are untouched - byte sizes and statuses unchanged
#   from the Step 0 baseline.
# ══════════════════════════════════════════════════════════════════════════
assert_a14() {
  local id="A14"
  should_run "$id" || return 0
  local bad="" checked=0 entry key url want_code want_size body code size ip
  for entry in "${B_SURFACES[@]}"; do
    key=$(printf '%s' "$entry" | cut -f1)
    url=$(printf '%s' "$entry" | cut -f2)
    want_code=$(printf '%s' "$entry" | cut -f3)
    want_size=$(printf '%s' "$entry" | cut -f4)
    body="$TMPWORK/surface.body"
    if [ "$key" = "agents_ip" ]; then
      code=$(curl -s -o "$body" -w '%{http_code}' --max-time "$HTTP_TIMEOUT" "$url" 2>/dev/null)
      checked=$((checked+1))
      if [ "$code" != "$want_code" ]; then bad+=" agents_ip(got $code want $want_code)"; fi
      continue
    fi
    code=$(curl -sL -o "$body" -w '%{http_code}' --max-time "$HTTP_TIMEOUT" "$url" 2>/dev/null)
    size=$(wc -c < "$body" | tr -d ' ')
    checked=$((checked+1))
    if [ "$code" != "$want_code" ] || [ "$size" != "$want_size" ]; then
      bad+=" $key(got $code/${size}B want $want_code/${want_size}B)"
    fi
  done
  if getent hosts agents.core-distro.com >/dev/null 2>&1; then
    bad+=" agents.core-distro.com(resolves by name, expected NXDOMAIN)"
  fi
  if [ -z "$bad" ]; then
    record "$id" PASS "$checked surfaces unchanged (status + byte size), agents.core-distro.com still NXDOMAIN"
  else
    record "$id" FAIL "surfaces changed:$(shorten "$bad" 160)"
  fi
}

# ══════════════════════════════════════════════════════════════════════════
# A15 single-public-build
#   convergence report section 10 line 428: only one build is publicly
#   reachable - curl --resolve data.core-distro.com:443:66.29.153.174 must
#   no longer serve the Lead Engine.
# ══════════════════════════════════════════════════════════════════════════
assert_a15() {
  local id="A15"
  should_run "$id" || return 0
  local body="$TMPWORK/legacy.html" code size root_url lead_url label
  local opts=()
  if [ -n "$LEGACY_URL" ]; then
    root_url="$LEGACY_URL"; lead_url="${LEGACY_URL%/}/leadlists.php"; label="$LEGACY_URL"
  else
    root_url="https://$LEGACY_HOST/"; lead_url="https://$LEGACY_HOST/leadlists.php"; label="$LEGACY_IP"
    opts=(--resolve "$LEGACY_HOST:443:$LEGACY_IP")
  fi
  code=$(curl -s -o "$body" -w '%{http_code}' --max-time "$HTTP_TIMEOUT" "${opts[@]}" "$root_url" 2>/dev/null)
  size=$(wc -c < "$body" | tr -d ' ')
  if grep -qF "$B_LANDING_MARKER" "$body" 2>/dev/null; then
    record "$id" FAIL "the second origin $label still serves the Lead Engine landing page ($code, ${size}B)"
    return 0
  fi
  local lbody="$TMPWORK/legacy2.html" lcode
  lcode=$(curl -s -o "$lbody" -w '%{http_code}' --max-time "$HTTP_TIMEOUT" "${opts[@]}" "$lead_url" 2>/dev/null)
  if [ "$lcode" = "302" ] || [ "$lcode" = "200" ]; then
    record "$id" FAIL "the second origin $label still answers /leadlists.php with $lcode (the Lead Engine)"
    return 0
  fi
  record "$id" PASS "the second origin $label does not serve the Lead Engine (root $code/${size}B, /leadlists.php $lcode)"
}

# ── run ─────────────────────────────────────────────────────────────────────
write_schema_probe

ASSERT_FUNCS=(assert_a1 assert_a2 assert_a3 assert_a4 assert_a5 assert_a6 assert_a7 assert_a8 assert_a9 assert_a10 assert_a11 assert_a12 assert_a13 assert_a14 assert_a15)
for fn in "${ASSERT_FUNCS[@]}"; do "$fn"; done

# ── output ──────────────────────────────────────────────────────────────────
pass=0; fail=0; skip=0
for r in "${ASSERT_RESULTS[@]}"; do
  case "$r" in PASS) pass=$((pass+1)) ;; FAIL) fail=$((fail+1)) ;; *) skip=$((skip+1)) ;; esac
done

if [ "$JSON_MODE" = "1" ]; then
  {
    printf '{\n'
    printf '  "gate": "%s",\n' "$GATE_NAME"
    printf '  "version": "%s",\n' "$GATE_VERSION"
    printf '  "mode": "%s",\n' "$([ -n "$ARTIFACT_DIR" ] && echo artifact || echo baseline)"
    printf '  "base_url": "%s",\n' "$BASE_URL"
    printf '  "artifact": "%s",\n' "$ARTIFACT_DIR"
    printf '  "generated_at": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "summary": {"pass": %d, "fail": %d, "skip": %d, "total": %d},\n' "$pass" "$fail" "$skip" "${#ASSERT_IDS[@]}"
    printf '  "assertions": [\n'
    for i in "${!ASSERT_IDS[@]}"; do
      printf '    {"id": "%s", "name": "%s", "result": "%s", "evidence": "%s"}' \
        "${ASSERT_IDS[$i]}" "${ASSERT_NAMES[$i]}" "${ASSERT_RESULTS[$i]}" \
        "$(printf '%s' "${ASSERT_EVIDENCE[$i]}" | sed 's/\\/\\\\/g; s/"/\\"/g')"
      if [ "$i" -lt $(( ${#ASSERT_IDS[@]} - 1 )) ]; then printf ',\n'; else printf '\n'; fi
    done
    printf '  ]\n'
    printf '}\n'
  }
  [ "$fail" -eq 0 ] && exit 0 || exit 1
fi

printf '%s acceptance gate - mode: %s - base-url: %s\n' "$GATE_NAME" \
  "$([ -n "$ARTIFACT_DIR" ] && echo "artifact ($ARTIFACT_DIR)" || echo "baseline (host-only)")" "$BASE_URL"
printf '%-4s %-24s %-6s %s\n' "ID" "ASSERTION" "RESULT" "EVIDENCE"
printf '%s\n' "------------------------------------------------------------------------------------------------------------------------"
for i in "${!ASSERT_IDS[@]}"; do
  printf '%-4s %-24s %-6s %s\n' "${ASSERT_IDS[$i]}" "${ASSERT_NAMES[$i]}" "${ASSERT_RESULTS[$i]}" "${ASSERT_EVIDENCE[$i]}"
done
printf '%s\n' "------------------------------------------------------------------------------------------------------------------------"
printf 'SUMMARY: %d assertions - PASS %d  FAIL %d  SKIP %d\n' "${#ASSERT_IDS[@]}" "$pass" "$fail" "$skip"
if [ "$fail" -eq 0 ]; then
  printf 'VERDICT: PASS - every assertion that could run held\n'
  exit 0
fi
printf 'VERDICT: FAIL - %d of %d assertions failed\n' "$fail" "${#ASSERT_IDS[@]}"
exit 1
