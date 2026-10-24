#!/usr/bin/env bash
# fm-lint-ratchet.test.sh - the non-vacuity proof for the ShellCheck ratchet.
#
# bin/fm-lint.sh owns the lint definition (the file set, the config, the
# pinned ShellCheck version). bin/fm-lint-ratchet.sh owns the committed
# baseline (bin/fm-lint-baseline.tsv), the comparison against it, and the
# update. The gate is only worth anything if the baseline is load-bearing, so
# this test proves all three properties:
#
#   1. diagnostics that match the baseline exactly PASS
#   2. ONE new diagnostic FAILS and is named
#   3. ONE baselined diagnostic that disappeared FAILS and is named
#   4. a baseline entry that is deleted FAILS (the baseline decides, not the
#      code alone)
#   5. the update refuses to record a new diagnostic and only ratchets down
#
# The test drives the ratchet directly with synthetic ShellCheck reports, so
# it stays fast. The end-to-end proof over the real tree is the lint job
# itself: bin/fm-lint.sh runs this same comparison over the canonical file set
# and is the single owner both CI and the no-mistakes gate invoke.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

RATCHET="$ROOT/bin/fm-lint-ratchet.sh"
BASELINE="$ROOT/bin/fm-lint-baseline.tsv"
LINT_OWNER="$ROOT/bin/fm-lint.sh"
CI_WORKFLOW="$ROOT/.github/workflows/ci.yml"

# Turn the committed baseline into a synthetic ShellCheck report with exactly
# the recorded findings, so the comparison can be exercised without a lint run.
synthetic_report() {  # <baseline> <out-file>
  awk -F'\t' '
    /^#/ { next }
    NF >= 3 {
      for (i = 0; i < $3; i++) {
        printf "In %s line %d:\n", $1, i + 1
        printf "a synthetic source line\n"
        printf "^-- %s (info): a synthetic reproduction of a baselined finding\n", $2
        printf "\n"
      }
    }
  ' "$1" > "$2"
}

# The files the baseline describes are the files the comparison considers
# linted, so a baselined diagnostic that is gone is reported as missing.
linted_list() {  # <baseline> <out-file>
  awk -F'\t' '/^#/ { next } NF >= 3 { print $1 }' "$1" | LC_ALL=C sort -u > "$2"
}

test_the_committed_baseline_is_well_formed() {
  [ -f "$BASELINE" ] || fail "the committed baseline is missing: $BASELINE"
  [ -x "$RATCHET" ] || fail "the ratchet is missing or not executable: $RATCHET"
  local tmp listed total
  tmp=$(fm_test_tmproot fm-lint-ratchet-baseline)
  mkdir -p "$tmp"
  listed="$tmp/listed"
  awk -F'\t' '/^#/ { next } NF >= 3 { print $1 }' "$BASELINE" | LC_ALL=C sort -u > "$listed"
  total=$(wc -l < "$listed" | tr -d ' ')
  [ "$total" -gt 0 ] || fail "the committed baseline records no diagnostic at all"
  # Every baseline file must be a tracked canonical shell file, or the clean
  # CI checkout could never reproduce the recorded findings.
  local untracked
  untracked=$(while IFS= read -r file; do
    [ -n "$file" ] || continue
    if ! git -C "$ROOT" ls-files --error-unmatch -- "$file" >/dev/null 2>&1; then
      printf '%s\n' "$file"
    fi
  done < "$listed")
  [ -z "$untracked" ] || fail "the baseline describes files git does not track:"$'\n'"$untracked"
  pass "the committed baseline describes only tracked files ($total files)"
}

test_matching_diagnostics_pass() {
  local tmp out rc
  tmp=$(fm_test_tmproot fm-lint-ratchet-match)
  mkdir -p "$tmp"
  synthetic_report "$BASELINE" "$tmp/report.txt"
  linted_list "$BASELINE" "$tmp/linted.txt"
  rc=0
  out=$("$RATCHET" --compare "$tmp/report.txt" "$BASELINE" "$tmp/linted.txt" 2>&1) || rc=$?
  [ "$rc" -eq 0 ] || fail "the ratchet rejected diagnostics that match the baseline"$'\n'"$out"
  assert_contains "$out" "ratchet OK" "the ratchet did not report a passing verdict"
  pass "diagnostics that match the committed baseline pass the ratchet"
}

test_one_new_diagnostic_fails() {
  local tmp out rc
  tmp=$(fm_test_tmproot fm-lint-ratchet-new)
  mkdir -p "$tmp"
  synthetic_report "$BASELINE" "$tmp/report.txt"
  linted_list "$BASELINE" "$tmp/linted.txt"
  printf '\nIn tests/fm-lint-ratchet.test.sh line 1:\na_synthetic_new_finding() {\n^-- SC2329 (info): This function is never invoked. Check usage (or ignored if invoked indirectly).\n' \
    >> "$tmp/report.txt"
  rc=0
  out=$("$RATCHET" --compare "$tmp/report.txt" "$BASELINE" "$tmp/linted.txt" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "the ratchet accepted one new diagnostic (exit $rc)"$'\n'"$out"
  assert_contains "$out" "NEW diagnostic not in the baseline" "the ratchet did not name the new diagnostic"
  assert_contains "$out" "SC2329" "the ratchet did not name the new diagnostic's code"
  pass "one new diagnostic fails the ratchet and is named"
}

test_one_missing_diagnostic_fails() {
  local tmp out rc
  tmp=$(fm_test_tmproot fm-lint-ratchet-missing)
  mkdir -p "$tmp"
  synthetic_report "$BASELINE" "$tmp/full.txt"
  linted_list "$BASELINE" "$tmp/linted.txt"
  # Drop the last recorded finding: the baseline still expects it.
  awk '/^In / { keep = 1 } { lines[NR] = $0 } END { for (i = 1; i <= NR; i++) { if (i >= NR - 4) continue; print lines[i] } }' \
    "$tmp/full.txt" > "$tmp/report.txt"
  rc=0
  out=$("$RATCHET" --compare "$tmp/report.txt" "$BASELINE" "$tmp/linted.txt" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "the ratchet accepted a baselined diagnostic that disappeared (exit $rc)"$'\n'"$out"
  assert_contains "$out" "no longer present" "the ratchet did not name the missing diagnostic"
  pass "a baselined diagnostic that disappeared fails the ratchet and is named"
}

test_a_deleted_baseline_entry_fails() {
  local tmp out rc
  tmp=$(fm_test_tmproot fm-lint-ratchet-weakened)
  mkdir -p "$tmp"
  synthetic_report "$BASELINE" "$tmp/report.txt"
  linted_list "$BASELINE" "$tmp/linted.txt"
  # Weaken the baseline by hand: drop its first record. The diagnostic is
  # still in the code, so the weakened baseline must reject it.
  awk 'BEGIN { dropped = 0 } /^#/ { print; next } { if (dropped == 0) { dropped = 1; next } print }' \
    "$BASELINE" > "$tmp/weakened.tsv"
  rc=0
  out=$("$RATCHET" --compare "$tmp/report.txt" "$tmp/weakened.tsv" "$tmp/linted.txt" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "the ratchet accepted a weakened baseline (exit $rc)"$'\n'"$out"
  assert_contains "$out" "NEW diagnostic not in the baseline" "the weakened baseline did not reject the unbaselined diagnostic"
  pass "a deleted baseline entry fails the ratchet, so the baseline is load-bearing"
}

test_the_update_only_ratchets_down() {
  local tmp out rc new_total
  tmp=$(fm_test_tmproot fm-lint-ratchet-update)
  mkdir -p "$tmp"
  synthetic_report "$BASELINE" "$tmp/base.txt"
  linted_list "$BASELINE" "$tmp/linted.txt"
  cp "$BASELINE" "$tmp/next.tsv"
  # A report with one diagnostic fewer than the baseline must be accepted and
  # must lower the recorded total.
  awk '/^In / { keep = 1 } { lines[NR] = $0 } END { for (i = 1; i <= NR; i++) { if (i >= NR - 4) continue; print lines[i] } }' \
    "$tmp/base.txt" > "$tmp/smaller.txt"
  rc=0
  out=$("$RATCHET" --update "$tmp/smaller.txt" "$tmp/next.tsv" "$tmp/linted.txt" 2>&1) || rc=$?
  [ "$rc" -eq 0 ] || fail "the update refused a smaller report (exit $rc)"$'\n'"$out"
  new_total=$("$RATCHET" --count "$tmp/next.tsv")
  local old_total
  old_total=$("$RATCHET" --count "$BASELINE")
  [ "$new_total" -lt "$old_total" ] || fail "the update did not lower the recorded total ($new_total vs $old_total)"
  # A report with one diagnostic more than the baseline must be refused.
  cp "$tmp/base.txt" "$tmp/report.txt"
  printf '\nIn tests/fm-lint-ratchet.test.sh line 1:\na_synthetic_new_finding() {\n^-- SC2329 (info): This function is never invoked. Check usage (or ignored if invoked indirectly).\n' \
    >> "$tmp/report.txt"
  rc=0
  out=$("$RATCHET" --update "$tmp/report.txt" "$tmp/next.tsv" "$tmp/linted.txt" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "the update accepted a new diagnostic (exit $rc)"$'\n'"$out"
  assert_contains "$out" "refusing to record" "the update did not state the refusal"
  pass "the update refuses a new diagnostic and only ratchets the total down"
}

test_the_lint_owner_and_ci_use_the_ratchet() {
  local out ci_semantics parser rc
  out=$("$LINT_OWNER" --help 2>&1)
  assert_contains "$out" "--update-baseline" "the lint owner does not document the baseline update"
  parser=$(mktemp)
  cat > "$parser" <<'PY'
import sys

path = sys.argv[1]
lines = open(path, encoding="utf-8").read().splitlines()
runs = []
in_lint = False
in_steps = False
index = 0
while index < len(lines):
    raw = lines[index]
    stripped = raw.strip()
    indent = len(raw) - len(raw.lstrip(" "))
    if indent == 2 and stripped == "lint:":
        in_lint = True
        in_steps = False
    elif in_lint and indent == 2 and stripped.endswith(":") and stripped != "lint:":
        in_lint = False
        in_steps = False
    elif in_lint and indent == 4 and stripped == "steps:":
        in_steps = True
    elif in_steps and indent == 4 and stripped.endswith(":"):
        in_steps = False
    elif in_steps and indent == 8 and stripped == "run: |":
        block = []
        index += 1
        while index < len(lines):
            candidate = lines[index]
            candidate_indent = len(candidate) - len(candidate.lstrip(" "))
            if candidate.strip() and candidate_indent < 10:
                index -= 1
                break
            block.append(candidate[10:] if candidate_indent >= 10 else "")
            index += 1
        runs.append("\n".join(block))
    index += 1

if not any(any(line.strip().startswith("bin/fm-lint.sh ") for line in run.splitlines()) for run in runs):
    raise SystemExit("lint workflow has no executable lint owner step")
if not any("$GITHUB_STEP_SUMMARY" in run for run in runs):
    raise SystemExit("lint workflow has no step summary output")
print("lint workflow semantic contract OK")
PY
  ci_semantics=$(python3 "$parser" "$CI_WORKFLOW" 2>&1)
  rc=$?
  rm -f "$parser"
  [ "$rc" -eq 0 ] || fail "the CI lint workflow semantic contract is invalid:$'\n'$ci_semantics"
  assert_contains "$ci_semantics" "lint workflow semantic contract OK" \
    "the CI lint job must execute the lint owner and publish its summary"
  pass "the lint owner and the CI workflow both run the ratchet and report the count"
}

test_the_committed_baseline_is_well_formed
test_matching_diagnostics_pass
test_one_new_diagnostic_fails
test_one_missing_diagnostic_fails
test_a_deleted_baseline_entry_fails
test_the_update_only_ratchets_down
test_the_lint_owner_and_ci_use_the_ratchet
