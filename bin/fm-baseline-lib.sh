# shellcheck shell=bash
# fm-baseline-lib.sh - one owner of fresh-agent baseline role resolution.
#
# The policy-family roles in the fresh-agent-baseline/v1 manifest were once
# hardcoded to the Controller's account home (/root/...). Every fresh agent on
# any other host was therefore handed pointers into a filesystem it did not
# have. No absolute path is baked in here: each role is resolved against the
# homes that can actually own it, in order, so the manifest follows the home.
#
# Resolution order per role:
#   1. that role's explicit override variable (FM_BASELINE_<ROLE>)
#   2. this firstmate home ($FM_HOME)
#   3. the operator's account home ($HOME), the mirror of the original layout
#
# A candidate must be a readable regular file; a missing or unreadable one is
# skipped so resolution falls through to the next home.
#
# A role with no readable candidate is reported as unavailable. It is never
# pointed at another role's document, never silently dropped, and never
# resolved to an invented substitute, because a fresh agent must be able to see
# that a contract it depends on is missing instead of trusting a pointer that
# either dangles or quietly names the wrong file.
#
# Candidate lists are per role because one relative location can hold different
# documents on different homes. $FM_HOME/AGENTS.md is firstmate's own operating
# contract, so it is deliberately not a policy candidate; and on a home whose
# account-level agent-work/AGENTS.md holds the canonical agent policy, that file
# is not a project-policy candidate either.

fm_baseline_role_override_var() {
  case "$1" in
    policy) printf 'FM_BASELINE_POLICY\n' ;;
    project-policy) printf 'FM_BASELINE_PROJECT_POLICY\n' ;;
    routing) printf 'FM_BASELINE_ROUTING\n' ;;
    bounded) printf 'FM_BASELINE_BOUNDED\n' ;;
    'lean-ctx') printf 'FM_BASELINE_LEAN_CTX\n' ;;
    *) return 1 ;;
  esac
}

fm_baseline_role_candidates() {
  case "$1" in
    policy)
      printf '%s\n' "$FM_HOME/AGENT-POLICY.md"
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/AGENT-POLICY.md"
      ;;
    project-policy)
      printf '%s\n' "$FM_HOME/agent-work/AGENTS.md"
      ;;
    routing)
      printf '%s\n' "$FM_HOME/docs/agent-policy/HERDR_AGENT_ROUTING.md"
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/docs/agent-policy/HERDR_AGENT_ROUTING.md"
      ;;
    bounded)
      printf '%s\n' "$FM_HOME/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md"
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md"
      ;;
    'lean-ctx')
      printf '%s\n' "$FM_HOME/.codex/LEAN-CTX.md"
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/.codex/LEAN-CTX.md"
      ;;
    *) return 1 ;;
  esac
}

fm_baseline_readable() {
  [ -f "$1" ] && [ -r "$1" ]
}

# Print the resolved path for a role, or fail when no candidate is readable.
fm_baseline_resolve_role() {
  local role=$1 override_var override candidate
  override_var=$(fm_baseline_role_override_var "$role") || return 1
  override="${!override_var-}"
  if [ -n "$override" ]; then
    if fm_baseline_readable "$override"; then
      printf '%s\n' "$override"
      return 0
    fi
    return 1
  fi
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    if fm_baseline_readable "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done <<FM_BASELINE_CANDIDATES
$(fm_baseline_role_candidates "$role")
FM_BASELINE_CANDIDATES
  return 1
}

# The unavailable marker names the role and states the gap. It carries no path
# and no digest, so it can never be mistaken for a content-pinned pointer.
fm_baseline_unavailable_line() {
  printf '%s=unavailable (no home-local file on this host)\n' "$1"
}