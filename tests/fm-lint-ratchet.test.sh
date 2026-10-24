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
#   5. a same-code replacement at another location FAILS
#   6. the update refuses to record a new diagnostic and only ratchets down
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

# Turn the committed baseline into a synthetic ShellCheck report with exactly
# the recorded findings, so the comparison can be exercised without a lint run.
synthetic_report() {  # <baseline> <out-file>
  awk -F'\t' '
    /^#/ { next }
    NF >= 6 {
      for (i = 0; i < $6; i++) {
        printf "In %s line %s:\n", $1, $3
        printf "%*s synthetic source line\n", $4, ""
        printf "%*s^-- %s (info): %s\n", $4 - 1, "", $2, $5
        printf "\n"
      }
    }
  ' "$1" > "$2"
}

# The files the baseline describes are the files the comparison considers
# linted, so a baselined diagnostic that is gone is reported as missing.
linted_list() {  # <baseline> <out-file>
  awk -F'\t' '/^#/ { next } NF >= 6 { print $1 }' "$1" | LC_ALL=C sort -u > "$2"
}

test_the_committed_baseline_is_well_formed() {
  [ -f "$BASELINE" ] || fail "the committed baseline is missing: $BASELINE"
  [ -x "$RATCHET" ] || fail "the ratchet is missing or not executable: $RATCHET"
  local tmp listed total
  tmp=$(fm_test_tmproot fm-lint-ratchet-baseline)
  mkdir -p "$tmp"
  listed="$tmp/listed"
  awk -F'\t' '/^#/ { next } NF >= 6 { print $1 }' "$BASELINE" | LC_ALL=C sort -u > "$listed"
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

test_same_code_replacement_fails() {
  local tmp out rc
  tmp=$(fm_test_tmproot fm-lint-ratchet-replacement)
  mkdir -p "$tmp"
  printf '# synthetic baseline\nfixture.sh\tSC2086\t10\t1\told diagnostic\t1\n' > "$tmp/baseline.tsv"
  printf 'fixture.sh\n' > "$tmp/linted.txt"
  printf 'In fixture.sh line 11:\nsource\n^-- SC2086 (warning): new diagnostic\n' > "$tmp/report.txt"
  rc=0
  out=$("$RATCHET" --compare "$tmp/report.txt" "$tmp/baseline.tsv" "$tmp/linted.txt" 2>&1) || rc=$?
  [ "$rc" -eq 1 ] || fail "the ratchet accepted a same-code replacement at a new location (exit $rc)"$'\n'"$out"
  assert_contains "$out" "NEW diagnostic not in the baseline" \
    "the ratchet did not report the replacement diagnostic"
  assert_contains "$out" "no longer present" \
    "the ratchet did not report the replaced diagnostic"
  pass "a same-code diagnostic replacement fails the ratchet"
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

test_the_lint_owner_exposes_the_update_interface() {
  local out version
  out=$("$LINT_OWNER" --help 2>&1)
  assert_contains "$out" "--update-baseline" "the lint owner does not document the baseline update"
  version=$("$LINT_OWNER" --required-version 2>&1)
  [ -n "$version" ] || fail "the lint owner must expose its required ShellCheck version"
  pass "the lint owner exposes executable baseline and version interfaces"
}

test_update_baseline_requires_the_complete_file_set() {
  local tmp before after out rc
  tmp=$(fm_test_tmproot fm-lint-partial-update)
  mkdir -p "$tmp"
  cp "$BASELINE" "$tmp/baseline.tsv"
  before=$(sha256sum "$tmp/baseline.tsv")
  rc=0
  out=$(cd "$ROOT" && "$LINT_OWNER" --jobs 1 --update-baseline \
    --baseline "$tmp/baseline.tsv" bin/fm-lint.sh 2>&1) || rc=$?
  [ "$rc" -eq 2 ] || fail "a partial baseline update must fail before linting (exit $rc): $out"
  after=$(sha256sum "$tmp/baseline.tsv")
  [ "$before" = "$after" ] || fail "a rejected partial baseline update modified the baseline"
  pass "partial baseline updates are rejected without changing the baseline"
}

test_the_committed_baseline_is_well_formed
test_matching_diagnostics_pass
test_same_code_replacement_fails
test_one_new_diagnostic_fails
test_one_missing_diagnostic_fails
test_a_deleted_baseline_entry_fails
test_the_update_only_ratchets_down
test_the_lint_owner_exposes_the_update_interface
test_update_baseline_requires_the_complete_file_set
