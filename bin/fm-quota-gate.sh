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
#                          [--launch-command <cmd>] [--binding-only]
#                          [--min-percent <N>] [--min-runway-sec <N>]
#
#   --launch-command <cmd> hands the gate the WHOLE command the dispatch will
#   run, not only the harness name derived from it. A raw launch derives that
#   name from the FIRST word of the command, so a refused harness hidden
#   behind another word ("env opencode ...", "sh -c 'grok ...'") otherwise
#   reached the gate under a name the gate did not recognise, was measured
#   against a bound provider's quota, and passed.
#
#   --binding-only runs the leave-refused binding check and nothing else: no
#   provider mapping is resolved and no quota is measured. It is how a
#   dispatch path that carries no quota measurement (a --secondmate launch)
#   still routes through the leave-refused refusal.
#
# Exit codes:
#   0  pass (measured and healthy, or unmeasured-but-live with disclosure)
#   3  refuse - measured exhaustion evidence (percent floor or runway floor)
#   4  refuse - cannot measure: quota-axi missing/failed/no provider block, or unbound harness
#
# Overrides for tests only:
#   FM_QUOTA_AXI_BIN - absolute path to the quota-axi binary (or a stub).
#   FM_QUOTA_TIMEOUT_SEC - read timeout, default 20.
#
# Data source contract: quota-axi remains data-only (AGENTS.md section 4). This
# gate never refreshes credentials, never logs in, never selects a different
# account, and never edits provider state. It reads and refuses or passes.
set -u

# Captain ruling 2026-10-21, question "quota-provider-binding", answer
# "leave-refused", provider "": the claude, grok, kimi and opencode harness
# FAMILIES are NOT to be bound to any provider. They have no provider account
# binding on this fleet, so quota-axi cannot measure their spend surface, and
# an unmeasurable spend surface is not a verified-eligible surface (captain
# ruling 2026-10-13, header above). The gate therefore refuses them BY NAME
# with exit 4 - deliberately and visibly - instead of letting them fall
# through to the generic "no provider mapping" refusal, and instead of
# letting a model prefix route them onto a bound provider's quota.
#
# The refusal is a property of the FAMILY, not of one spelling of it. This
# fleet spells the opencode harness "opencode" but its own quota provider -
# the identifier its quota board, its quota-axi output and its dispatch
# config use - is "opencode-go". A refusal that matched only the literal
# string "opencode" was side-stepped by that alias: the harness fell through
# to the model branch, a model prefix re-routed it onto a bound provider's
# quota, and the gate passed while the dispatch spent an unmeasured surface.
# An alias of a refused family is still a refused family.
LEAVE_REFUSED_HARNESSES="claude grok kimi opencode"

# fm_quota_normalize_harness_name <name>
# Print the canonical spelling of a harness name: its basename (a path names
# the same harness as its basename), without quoting, lowercased.
fm_quota_normalize_harness_name() {
  local raw=${1:-} name
  [ -n "$raw" ] || return 1
  name=${raw##*/}
  name=${name//\"/}
  name=${name//\'/}
  printf '%s' "$name" | tr '[:upper:]' '[:lower:]'
}

# fm_quota_leave_refused_family <name>
# Print the leave-refused harness FAMILY <name> belongs to and return 0, or
# print nothing and return 1 when it belongs to none.
#
# The match is deliberately conservative so it can never refuse a DIFFERENT
# harness by accident: the family name itself, or that name followed by a
# separator ("opencode", "opencode-go"). "opencoder" is not the opencode
# family and is not refused.
fm_quota_leave_refused_family() {
  local raw=${1:-} name family
  [ -n "$raw" ] || return 1
  name=$(fm_quota_normalize_harness_name "$raw")
  for family in $LEAVE_REFUSED_HARNESSES; do
    if [ "$name" = "$family" ] \
       || [ "${name#"$family-"}" != "$name" ] \
       || [ "${name#"${family}_"}" != "$name" ]; then
      printf '%s' "$family"
      return 0
    fi
  done
  return 1
}

leave_refused_reason() {
  # leave_refused_reason <harness> - print the refusal reason when the harness
  # names a family the captain left unbound on this fleet and return 0;
  # otherwise print nothing and return 1.
  local harness=${1:-} family
  family=$(fm_quota_leave_refused_family "$harness") || return 1
  printf '%s' 'deliberately unbound on this fleet (Captain ruling 2026-10-21, quota-provider-binding=leave-refused): no provider account binding exists for this harness, so quota-axi cannot measure its spend surface, and an unmeasurable spend surface is not a verified-eligible surface'
  return 0
}

# fm_quota_leave_refused_launch_token <launch-command>
# Print the first token of <launch-command> that names a leave-refused harness
# family, or print nothing and return 1 when it names none.
#
# The harness name fm-spawn derives from a raw launch command is the FIRST
# word of that command, so a refused harness hidden behind another word
# ("env opencode ...", "sh -c 'grok ...'") reached the gate under a name the
# gate did not recognise. The gate therefore reads the WHOLE command. An
# environment assignment (NAME=value) is not a binary and is skipped.
fm_quota_leave_refused_launch_token() {
  local command=${1:-} word family
  [ -n "$command" ] || return 1
  for word in $command; do
    case "$word" in
      *=*) continue ;;
    esac
    family=$(fm_quota_leave_refused_family "$word") || continue
    fm_quota_normalize_harness_name "$word"
    return 0
  done
  return 1
}

die() { printf 'error: %s\n' "$1" >&2; exit "${2:-4}"; }

usage() {
  sed -n '2,/^set -u$/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'
  exit 2
}

provider_for() {
  local harness=${1:-} model=${2:-}
  if leave_refused_reason "$harness" >/dev/null; then
    # Deliberately unbound: there is no provider mapping for this harness and
    # none may be inferred from a model prefix - it would be measured against
    # a provider this harness does not even spend on.
    echo ""; return
  fi
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
  local harness="" model="" launch_command="" binding_only=0
  local min_percent="${FM_QUOTA_MIN_PERCENT:-10}" min_runway="${FM_QUOTA_MIN_RUNWAY_SEC:-3600}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --harness) harness=${2:-}; shift 2 ;;
      --model) model=${2:-}; shift 2 ;;
      --launch-command) launch_command=${2:-}; shift 2 ;;
      --binding-only) binding_only=1; shift ;;
      --min-percent) min_percent=${2:-}; shift 2 ;;
      --min-runway-sec) min_runway=${2:-}; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$harness" ] || die "check requires --harness"

  # Named refusal for the harnesses the captain left unbound. This runs
  # BEFORE provider_for(), so it cannot be side-stepped by naming a model
  # that maps to a bound provider (e.g. --harness opencode --model gpt-6-*).
  # The match is on the harness FAMILY, so an alias of a refused family
  # (e.g. --harness opencode-go) is refused the same way.
  local refusal
  if refusal=$(leave_refused_reason "$harness"); then
    die "quota gate: REFUSE harness=$harness - $refusal" 4
  fi

  # The WHOLE launch command is read too, not only the harness name derived
  # from it: a raw launch can hide a refused harness behind another word.
  local launch_token launch_refusal
  if launch_token=$(fm_quota_leave_refused_launch_token "$launch_command"); then
    launch_refusal=$(leave_refused_reason "$launch_token")
    die "quota gate: REFUSE launch command names refused harness '$launch_token' - $launch_refusal" 4
  fi

  # Binding-only dispatch paths (a --secondmate launch) carry no quota
  # measurement, but the leave-refused refusal above is unconditional.
  if [ "$binding_only" -eq 1 ]; then
    printf 'quota-gate: BINDING-OK harness=%s\n' "$harness"
    exit 0
  fi

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
