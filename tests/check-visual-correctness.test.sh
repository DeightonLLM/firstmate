#!/usr/bin/env bash
# tests/check-visual-correctness.test.sh - the enforcement point for the Visual
# Correctness Standard (docs/VISUAL-CORRECTNESS-STANDARD.md, Ticket 0036).
#
# The gate lives at /root/bin/check-visual-correctness on the worker surface.
# The suite drives it through its published interface, so it asserts the
# published contract and never the gate's source bytes.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

GATE="${FM_VISUAL_GATE:-}"
if [ -z "$GATE" ]; then
  for candidate in /root/bin/check-visual-correctness "$ROOT/bin/check-visual-correctness"; do
    if [ -x "$candidate" ]; then
      GATE="$candidate"
      break
    fi
  done
fi
if [ -z "$GATE" ]; then
  printf 'SKIP - no visual-correctness gate on this host (looked in /root/bin and %s/bin); set FM_VISUAL_GATE to run it\n' "$ROOT"
  exit 0
fi

TMP_ROOT=$(fm_test_tmproot check-visual-correctness-tests)

# A real 16x16 PNG (852 bytes). It is written from base64 so the fixture is a
# genuine image on disk, not a file that merely claims to be one.
REAL_PNG_B64='iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAADG0lEQVR42gEQA+/8ANwEZaofrR1a2uWsGx5fE3B5bP0Q/xmvYB0ErLQdAitGeHM68t9frrcIWdHuORDLSACVtcyJKRH/BrZiLt88+TX9S5Qoygl8RLMCXpZfs+ptrNQtgW5pr+Dmh0ycBOfSNl0ALGDJ6vR59oag65Mm5GIS1Q3Ls3cVamo6aLqO23QIRp7zzrMK+NDdaLv4X/ok8tL8ABiH+1yHurQ4MqWbGz0QfPd41n/ibfgRkSl+k5XLEsVXzlrx1BYY1xm8BFt+mWXxogCUccQqrGqpOMR1x60yOAIfBTssmRr86xXez2i64Hy81h6XG5oLnb6XY9OS/K/foowAlyNFYuvdB2Vw/1iJas/3yu4/HOnkCmjl3pONOJx9vddbCdTn4jNEP0qMxKGQ1ri4ANxhX9GOKL5ZDqpQG1CKajYp5nDfVXe63ERtQ7upCBfWwPZ7CGFw2S3JEnJbJH7C4gDasbIEniCAdDeab5AM3S5ecvUJSLZY0Zfpw4yxbtPdEkRiMgwUp68/+gze1hPOE4YAy1egR+RbvtFFtDbViP7SAEHyh7EPg190ZbooRhZS34iiE9m/Qu+3EbXeB3/JebrjAKhYSqnoLahNUJ3mmGviqZrPIUxmKozVkBE3mGeJu63zUY0TrfUcoQGUrLCEbPWK9QAqepH186svhjK6gUUgPcNnFIh6dZDIY8cH4B7CcAOa0YsWPyT2w94r711a0eZ2E3kAykIWuRCqBdmDMMcKz4XwZsvs76yJTPq3Hxi6wzTftmBKsoAyzTmhbt+URBTh86bsAMH0OUMGwJtineM602Hvw1Nr0E+WH+5NvfMFLZf+xNGbRSe0osSU2GQ+uHG5xB9TiwAIlRyeX0Ah/5d6Gk1/cIyrL3z6gBtCyvXbjPksuOZ+Qfb5fwHkqDZtpOyi7bpw7VQAV+ugl2NBiU1NWWjmkrxcqw7zEHkGnaU98VJdLgk7Dc6WbUGe9QospGsWVp2sGgQCACl7Zr0dl4OoVqXlysNJBFDC+nNNKBTMMQ28XQtceI9+HooahYEP6+ar3NB3QRTpFD82h15JXLVyAAAAAElFTkSuQmCC'

write_real_png() {
  printf '%s' "$REAL_PNG_B64" | base64 -d > "$1"
}

run_gate() {
  local out rc=0
  out=$(bash "$GATE" "$1" 2>&1) || rc=$?
  printf '%s' "$rc"
  printf '%s' "$out" > "$TMP_ROOT/last-out.txt"
}

# A report that claims a screenshot it never captured: the referenced file does
# not exist. The gate must refuse it.
test_dangling_reference_is_refused() {
  local dir rc
  dir="$TMP_ROOT/dangling"
  mkdir -p "$dir/evidence"
  cat > "$dir/report.md" <<'REPORT'
# Lane Report - Dashboard UI
Area: Frontend

Implemented the operations dashboard.

![dashboard](./evidence/never-captured.png)

VERDICT: PASS - dashboard shipped
REPORT
  rc=$(run_gate "$dir/report.md")
  expect_code 1 "$rc" "a markdown reference to a file that does not exist must fail the gate"
  assert_grep "VISUAL_CHECK: FAILED_VERIFICATION" "$TMP_ROOT/last-out.txt" "the failure must be reported"
  assert_grep "never-captured.png" "$TMP_ROOT/last-out.txt" "the unverified reference must be named"
  pass "a dangling markdown image reference is refused"
}

# The same dangling reference must still be refused when an unrelated image
# happens to sit in the same tree. The artifact the report claims is the one
# that has to exist.
test_dangling_reference_is_refused_despite_a_nearby_image() {
  local dir rc
  dir="$TMP_ROOT/dangling-with-stray"
  mkdir -p "$dir/evidence"
  write_real_png "$dir/evidence/unrelated-logo.png"
  cat > "$dir/report.md" <<'REPORT'
# Lane Report - Dashboard UI
Area: Frontend

Implemented the operations dashboard.

![dashboard](./evidence/never-captured.png)

VERDICT: PASS - dashboard shipped
REPORT
  rc=$(run_gate "$dir/report.md")
  expect_code 1 "$rc" "an unrelated nearby image must not rescue a dangling reference"
  pass "a dangling reference is refused even when an unrelated image is nearby"
}

# The honest case: the referenced artifact really exists and is a real image.
test_real_artifact_passes() {
  local dir rc
  dir="$TMP_ROOT/real"
  mkdir -p "$dir/evidence"
  write_real_png "$dir/evidence/dashboard.png"
  cat > "$dir/report.md" <<'REPORT'
# Lane Report - Dashboard UI
Area: Frontend

Implemented the operations dashboard.

![dashboard](./evidence/dashboard.png)

VERDICT: PASS - dashboard shipped
REPORT
  rc=$(run_gate "$dir/report.md")
  expect_code 0 "$rc" "a report whose referenced artifact exists must pass the gate"
  assert_grep "VISUAL_CHECK: PASS" "$TMP_ROOT/last-out.txt" "the pass must be reported"
  pass "a real on-disk artifact is accepted"
}

# A file that only claims to be an image is not a screenshot.
test_truncated_image_is_refused() {
  local dir rc
  dir="$TMP_ROOT/truncated"
  mkdir -p "$dir/evidence"
  printf '\211PNG\r\n\032\n' > "$dir/evidence/tiny.png"
  cat > "$dir/report.md" <<'REPORT'
# Lane Report - Dashboard UI
Area: Frontend

![dashboard](./evidence/tiny.png)
REPORT
  rc=$(run_gate "$dir/report.md")
  expect_code 1 "$rc" "a truncated file must not satisfy the visual gate"
  pass "a truncated image file is refused"
}

# A remote URL is not an on-disk artifact and cannot satisfy the gate.
test_remote_reference_is_refused() {
  local dir rc
  dir="$TMP_ROOT/remote"
  mkdir -p "$dir"
  cat > "$dir/report.md" <<'REPORT'
# Lane Report - Dashboard UI
Area: Frontend

![dashboard](https://example.invalid/dashboard.png)
REPORT
  rc=$(run_gate "$dir/report.md")
  expect_code 1 "$rc" "a remote reference is not an on-disk artifact"
  pass "a remote image reference is refused"
}

# Work that is not visual/UI scoped stays exempt: the gate must never block a
# backend lane.
test_non_visual_report_is_exempt() {
  local dir rc
  dir="$TMP_ROOT/backend"
  mkdir -p "$dir"
  cat > "$dir/report.md" <<'REPORT'
# Lane Report - API
Area: Backend

Shipped the JSON endpoint and its migration.
REPORT
  rc=$(run_gate "$dir/report.md")
  expect_code 0 "$rc" "a non-visual report must stay exempt"
  assert_grep "VISUAL_CHECK: EXEMPT" "$TMP_ROOT/last-out.txt" "the exemption must be reported"
  pass "a non-visual report stays exempt"
}

test_dangling_reference_is_refused
test_dangling_reference_is_refused_despite_a_nearby_image
test_real_artifact_passes
test_truncated_image_is_refused
test_remote_reference_is_refused
test_non_visual_report_is_exempt
