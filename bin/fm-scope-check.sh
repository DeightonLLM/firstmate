#!/usr/bin/env bash
# Read-only advisory check: this script can refuse a proposed write scope, never authorize execution.
set -euo pipefail

usage() {
  printf 'Usage: %s [--registry PATH] OWNER ACTION_DOMAIN\n' "${0##*/}" >&2
  exit 2
}

registry=${FM_AGENT_SCOPES_REGISTRY:-/home/hd2admin/agent-work/deightonllm-firstmate/data/agent-scopes.tsv}
while (($#)); do
  case $1 in
    --registry)
      (($# >= 2)) || usage
      registry=$2
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    --*)
      usage
      ;;
    *)
      break
      ;;
  esac
done
(($# == 2)) || usage
owner=$1
action_domain=$2

if [[ ! -r $registry || ! -f $registry ]]; then
  printf 'REFUSE: registry is missing, unreadable, or not a regular file: %s\n' "$registry"
  exit 1
fi

# Exact comma-delimited identifiers only. No wildcard, prefix, prose, or hierarchy inference.
result=$(awk -F '\t' -v wanted_owner="$owner" -v wanted_domain="$action_domain" '
  NR == 1 {
    if (NF != 6 || $1 != "owner" || $2 != "surface" || $3 != "read_domains" ||
        $4 != "write_domains" || $5 != "exclusions" || $6 != "notes") {
      err = "REFUSE: invalid registry header/schema"
      err_code = 10
      exit
    }
    next
  }
  {
    if (NF != 6 || $1 == "") {
      err = "REFUSE: malformed registry row at line " NR
      err_code = 11
      exit
    }
    if ($1 == wanted_owner) {
      found = 1
      writes = $4
      excludes = $5
    }
  }
  END {
    if (err != "") {
      print err
      exit err_code
    }
    if (!found) {
      print "REFUSE: owner is absent from registry"
      exit 12
    }
    n = split(writes, w, ",")
    for (i = 1; i <= n; i++) if (w[i] == wanted_domain) in_write = 1
    n = split(excludes, e, ",")
    for (i = 1; i <= n; i++) if (e[i] == wanted_domain) excluded = 1
    if (excluded) {
      print "REFUSE: action domain is explicitly excluded for owner"
      exit 13
    }
    if (!in_write) {
      print "REFUSE: action domain is not in owner write_domains"
      exit 14
    }
    print "ALLOW: exact action domain appears in owner write_domains and is not excluded"
  }
' "$registry" 2>&1) || {
  rc=$?
  # awk may emit a precise REFUSE reason; preserve it and normalize malformed input to refusal.
  if [[ -n $result && $result == REFUSE:* ]]; then printf '%s\n' "$result"; else printf 'REFUSE: registry could not be read or parsed\n'; fi
  exit "$rc"
}
printf '%s\n' "$result"
