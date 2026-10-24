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
#   4. a cross-home scope, labelled as such, never silently
#
# Step 4 exists because steps 2 and 3 are not the whole picture. The policy
# family genuinely lives in a root-owned scope that is READABLE from this host,
# and a manifest that reported those roles as unavailable discarded a real,
# reachable contract. Reporting a readable root-owned file as missing is its own
# class of wrong. So the root scope is a candidate too, and every path resolved
# from outside this home carries an explicit scope label so a fresh agent can
# see at a glance that it is reading another home's contract rather than its own.
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
# contract, so it is deliberately not a policy candidate. $HOME/AGENTS.md is not
# a policy candidate either: on the Hetz lane that file is the lean-ctx
# extension README, so accepting it would point the policy role at a document
# that is not a policy. The account scope can hold the canonical policy at
# $HOME/AGENT-POLICY.md or $HOME/agent-work/AGENT-POLICY.md, and both are
# policy candidates.

fm_baseline_role_override_var() {
  case "$1" in
    policy) printf 'FM_BASELINE_POLICY\n' ;;
    project-policy) printf 'FM_BASELINE_PROJECT_POLICY\n' ;;
    routing) printf 'FM_BASELINE_ROUTING\n' ;;
    bounded) printf 'FM_BASELINE_BOUNDED\n' ;;
    'lean-ctx') printf 'FM_BASELINE_LEAN_CTX\n' ;;
    watchers) printf 'FM_BASELINE_WATCHERS\n' ;;
    *) return 1 ;;
  esac
}

fm_baseline_role_candidates() {
  local root_scope="${FM_BASELINE_ROOT_SCOPE:-/root}"
  case "$1" in
    policy)
      printf '%s\n' "$FM_HOME/AGENT-POLICY.md"
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/AGENT-POLICY.md"
      # The account scope keeps the canonical policy under its own working
      # directory as well, which is where the Hetz lane holds it. Without this
      # candidate a home that is not a firstmate checkout has no account-scope
      # policy at all, falls through to the cross-home scope, and is handed the
      # Controller's policy for a role that does not own it.
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/agent-work/AGENT-POLICY.md"
      printf '%s\n' "$root_scope/AGENTS.md"
      ;;
    project-policy)
      printf '%s\n' "$FM_HOME/agent-work/AGENTS.md"
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/agent-work/AGENTS.md"
      printf '%s\n' "$root_scope/agent-work/AGENTS.md"
      ;;
    routing)
      printf '%s\n' "$FM_HOME/docs/agent-policy/HERDR_AGENT_ROUTING.md"
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/docs/agent-policy/HERDR_AGENT_ROUTING.md"
      printf '%s\n' "$root_scope/docs/agent-policy/HERDR_AGENT_ROUTING.md"
      ;;
    bounded)
      printf '%s\n' "$FM_HOME/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md"
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md"
      printf '%s\n' "$root_scope/docs/agent-policy/HERDR_BOUNDED_EXECUTION.md"
      ;;
    'lean-ctx')
      printf '%s\n' "$FM_HOME/.codex/LEAN-CTX.md"
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/.codex/LEAN-CTX.md"
      printf '%s\n' "$root_scope/.codex/LEAN-CTX.md"
      ;;
    watchers)
      # The watchers-and-polls contract. It is in the manifest because the
      # knowledge gap kept recurring: agents could not tell whether a watcher
      # should run, who owned it, or how to make it safe. On 2026-10-23 a
      # pile-up of 577 stuck sync processes took a 6-core host to load 340.
      printf '%s\n' "$FM_HOME/docs/agent-policy/WATCHERS_AND_POLLS.md"
      [ -n "${HOME:-}" ] && printf '%s\n' "$HOME/docs/agent-policy/WATCHERS_AND_POLLS.md"
      printf '%s\n' "$root_scope/docs/agent-policy/WATCHERS_AND_POLLS.md"
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
  printf '%s=unavailable (no readable file for this role in any known scope)\n' "$1"
}

# The scope label states which home a resolved path came from, so a fresh agent
# reading another scope's contract can see that it is not reading its own. A
# path resolved inside this firstmate home is "home"; anything else names the
# scope it was resolved from. This is a label, never a filter: a readable path
# outside the home is still a real contract and reporting it as missing would
# discard information the agent needs.
fm_baseline_scope_of() {  # <resolved-path>
  local path=$1 top
  case "$path" in
    "$FM_HOME"/*) printf 'home\n'; return 0 ;;
    "${HOME:-__none__}"/*) printf 'account\n'; return 0 ;;
  esac
  # A cross-home path is absolute and begins with its scope's leading slash, so
  # the scope name is the first segment AFTER that slash. Taking the first
  # segment before it yields an empty label for every absolute path, which is
  # exactly the case this branch exists to name.
  top="${path#/}"
  printf 'cross-home:%s\n' "${top%%/*}"
}