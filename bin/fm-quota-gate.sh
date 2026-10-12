#!/usr/bin/env bash
# fm-quota-gate.sh - fail-closed provider-quota admission for crew dispatch.
#
# Captain ruling 2026-10-13: quota-axi is ENFORCED at spawn time, in code, not
# advisory. A dispatch may not proceed on a provider whose window is known to
# be exhausted or projected to exhaust within the minimum runway, and it may
# not proceed at all when the provider's quota cannot be measured by a working
# quota-axi - an unmeasurable spend surface is not a verified-eligible surface.
#
# Usage:
#   fm-quota-gate.sh check --harness <name> [--model <name>]
#                          [--min-percent <N>] [--min-runway-sec <N>]
#
# Exit codes:
#   0  pass (measured and healthy, or unmeasured-but-live with disclosure)
#   3  refuse - measured exhaustion evidence (percent floor or runway floor)
#   4  refuse - cannot measure: quota-axi missing, failed, or no provider block
#
# Overrides for tests only:
#   FM_QUOTA_AXI_BIN - absolute path to the quota-axi binary (or a stub).
#   FM_QUOTA_TIMEOUT_SEC - read timeout, default 20.
#
# Data source contract: quota-axi remains data-only (AGENTS.md section 4). This
# gate never refreshes credentials, never logs in, never selects a different
# account, and never edits provider state. It reads and refuses or passes.
set -u

die() { printf 'error: %s\n' "$1" >&2; exit "${2:-4}"; }

usage() {
  sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

provider_for() {
  local harness=${1:-} model=${2:-}
  case "$harness" in
    minimax-code|minimax) echo minimax; return ;;
    agy|agy-*) echo agy; return ;;
    codex) echo codex; return ;;
    zai) echo zai; return ;;
    pi|pi-signed)
      case "$model" in
        minimax/*|*iniMax*) echo minimax; return ;;
        zai/*|*glm*) echo zai; return ;;
        openai-codex/*|*gpt-6*) echo codex; return ;;
      esac
      ;;
  esac
  case "$model" in
    minimax/*|*iniMax*) echo minimax; return ;;
    gemini*) echo agy; return ;;
    gpt-6*|openai-codex/*) echo codex; return ;;
    glm*|zai/*) echo zai; return ;;
  esac
  echo ""
}

json_field() {
  # json_field <json-string> <python-expression over d>
  python3 - "$1" "$2" <<'PY'
import json, sys
raw, expr = sys.argv[1], sys.argv[2]
try:
    d = json.loads(raw)
except Exception:
    print("__PARSE_ERROR__"); raise SystemExit
try:
    v = eval(expr, {"d": d})
    print("__NONE__" if v is None else v)
except Exception:
    print("__EXPR_ERROR__")
PY
}

cmd_check() {
  local harness="" model="" min_percent="${FM_QUOTA_MIN_PERCENT:-10}" min_runway="${FM_QUOTA_MIN_RUNWAY_SEC:-3600}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --harness) harness=${2:-}; shift 2 ;;
      --model) model=${2:-}; shift 2 ;;
      --min-percent) min_percent=${2:-}; shift 2 ;;
      --min-runway-sec) min_runway=${2:-}; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$harness" ] || die "check requires --harness"

  local provider
  provider=$(provider_for "$harness" "$model")
  [ -n "$provider" ] || die "quota gate: no provider mapping for harness=$harness model=${model:-default}; refusing rather than dispatching unmeasured" 4

  local bin="${FM_QUOTA_AXI_BIN:-quota-axi}"
  command -v "$bin" >/dev/null 2>&1 || [ -x "$bin" ] || die "quota gate: quota-axi binary not available ($bin); refusing to dispatch without a measurable spend surface" 4

  local raw
  raw=$("$bin" --json 2>/dev/null) || die "quota gate: quota-axi --json failed; refusing to dispatch without a measurable spend surface" 4
  [ -n "$raw" ] || die "quota gate: quota-axi produced no output; refusing" 4

  local state sem eff
  state=$(json_field "$raw" "next((p['state']['status'] for p in d['providers'] if p['provider']=='$provider'), None)")
  [ "$state" = "__PARSE_ERROR__" ] || [ "$state" = "__EXPR_ERROR__" ] || [ "$state" = "__NONE__" ] && \
    die "quota gate: no provider block for '$provider' in quota-axi output; refusing" 4

  case "$state" in
    fresh) ;;
    auth_required|notSetUp)
      die "quota gate: provider '$provider' is not authenticated (state=$state); refusing - a dispatch on an unauthenticated provider is an unmeasurable spend" 4 ;;
    *)
      die "quota gate: provider '$provider' state=$state is not fresh; refusing stale spend evidence" 4 ;;
  esac

  sem=$(json_field "$raw" "next((p['quotaSemantics']['status'] for p in d['providers'] if p['provider']=='$provider'), None)")
  if [ "$sem" != "known" ]; then
    printf 'quota-gate: UNMEASURED provider=%s semantics=%s - proceeding with disclosed uncertainty (AGENTS.md section 4); no exhaustion evidence, no credential action\n' "$provider" "$sem" >&2
    exit 0
  fi

  # The binding number is the WORST known scope, not the first entry: a
  # provider with a healthy claude_gpt scope and a 33% gemini scope is a 33%
  # provider for admission purposes.
  eff=$(json_field "$raw" "(lambda vals: min(vals) if vals else None)([ea['effectivePercentRemaining'] for p in d['providers'] if p['provider']=='$provider' for ea in p['quotaSemantics']['effectiveAvailability'] if ea.get('status')=='known' and isinstance(ea.get('effectivePercentRemaining'),(int,float))])")
  local runway_status runway_secs
  runway_status=$(json_field "$raw" "(lambda sts: 'projected_exhaustion' if 'projected_exhaustion' in sts else (sts[0] if sts else None))([ea['runway']['status'] for p in d['providers'] if p['provider']=='$provider' for ea in p['quotaSemantics']['effectiveAvailability'] if isinstance(ea.get('runway'),dict) and ea['runway'].get('status')])")
  runway_secs=$(json_field "$raw" "(lambda secs: min(secs) if secs else None)([ea['runway']['usableRunwaySeconds'] for p in d['providers'] if p['provider']=='$provider' for ea in p['quotaSemantics']['effectiveAvailability'] if isinstance(ea.get('runway'),dict) and ea['runway'].get('status')=='projected_exhaustion' and isinstance(ea['runway'].get('usableRunwaySeconds'),(int,float))])")

  if [ "$eff" != "__NONE__" ] && [ -n "$eff" ] && [ "$eff" != "__EXPR_ERROR__" ]; then
    if [ "$eff" -le "$min_percent" ] 2>/dev/null; then
      printf 'quota gate: REFUSE provider=%s effective=%s%% <= floor %s%%; dispatch refused in code (captain ruling 2026-10-13)\n' "$provider" "$eff" "$min_percent" >&2
      exit 3
    fi
  fi

  if [ "$runway_status" = "projected_exhaustion" ] && [ "$runway_secs" != "__NONE__" ] && [ -n "$runway_secs" ] && [ "$runway_secs" != "__EXPR_ERROR__" ]; then
    if [ "$runway_secs" -le "$min_runway" ] 2>/dev/null; then
      printf 'quota gate: REFUSE provider=%s runway=%ss <= floor %ss (projected_exhaustion); dispatch refused in code\n' "$provider" "$runway_secs" "$min_runway" >&2
      exit 3
    fi
  fi

  printf 'quota-gate: PASS provider=%s effective=%s runway=%s\n' "$provider" "${eff:-unknown}" "${runway_status:-unknown}"
  exit 0
}

# Library-safe: only dispatch when executed directly, so tests can source this
# file and call provider_for() without triggering the command dispatcher.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-}" in
    check) shift; cmd_check "$@" ;;
    --help|help|"" ) usage ;;
    *) usage ;;
  esac
fi
