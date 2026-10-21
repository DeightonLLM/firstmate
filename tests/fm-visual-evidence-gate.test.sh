#!/usr/bin/env bash
set -euo pipefail
GATE="${FM_VISUAL_EVIDENCE_GATE:-/root/bin/fm-visual-evidence-gate}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pass=0
fail=0
check() {
  local label="$1" expected="$2" report="$3" out rc
  set +e; out=$("$GATE" "$report" 2>&1); rc=$?; set -e
  if [[ "$expected" == pass && $rc -eq 0 ]] && grep -q '^PASS:' <<< "$out"; then
    printf 'PASS %s: %s\n' "$label" "$out"; pass=$((pass+1))
  elif [[ "$expected" == fail && $rc -ne 0 && -n "$out" ]]; then
    printf 'PASS %s: rejected (%s)\n' "$label" "$out"; pass=$((pass+1))
  else
    printf 'FAIL %s: exit=%s output=%s\n' "$label" "$rc" "$out"; fail=$((fail+1))
  fi
}
printf '%-1300s\nVERDICT: PASS\nVISIBLE-CHANGE: yes\nVISUAL-ARTIFACT: shot.png\nVIEWPORT: 1280x720\n' body > "$tmp/base.md"
check missing-report fail "$tmp/absent.md"
printf '%-1300s\nVERDICT: PASS\n' body > "$tmp/no-scope.md"; check missing-scope fail "$tmp/no-scope.md"
printf '%-1300s\nVERDICT: PASS\nVISIBLE-CHANGE: maybe\n' body > "$tmp/bad-scope.md"; check invalid-scope fail "$tmp/bad-scope.md"
printf '%-1300s\nVERDICT: PASS\nVISIBLE-CHANGE: no\n' body > "$tmp/invisible.md"; check no-visible-change pass "$tmp/invisible.md"
printf '%-1300s\nVERDICT: PASS\nVISIBLE-CHANGE: yes\nVIEWPORT: 1280x720\n' body > "$tmp/no-image.md"; check missing-image-reference fail "$tmp/no-image.md"
printf '%-1300s\nVERDICT: PASS\nVISIBLE-CHANGE: yes\nVISUAL-ARTIFACT: absent.png\nVIEWPORT: 1280x720\n' body > "$tmp/absent-image.md"; check missing-image-file fail "$tmp/absent-image.md"
printf '%-1300s\nVERDICT: PASS\nVISIBLE-CHANGE: yes\nVISUAL-ARTIFACT: shot.png\n' body > "$tmp/no-viewport.md"; touch "$tmp/shot.png"; check missing-viewport fail "$tmp/no-viewport.md"
printf '%-1300s\nVERDICT: PASS\nVISIBLE-CHANGE: yes\nVISUAL-ARTIFACT: shot.png\nRENDER-SIZE: 1280x720\n' body > "$tmp/valid.md"; check image-with-render-size pass "$tmp/valid.md"
printf '%-1300s\nVERDICT: PASS\nVISIBLE-CHANGE: no\nENDPOINT-STATUS: done\nENDPOINT-URL: https://example.com\n' body > "$tmp/endpoint-pass.md"; check endpoint-done-passing-url pass "$tmp/endpoint-pass.md"
printf '%-1300s\nVERDICT: PASS\nVISIBLE-CHANGE: no\nENDPOINT-STATUS: done\nENDPOINT-URL: https://endpoint-check-does-not-exist.invalid\n' body > "$tmp/endpoint-fail.md"; check endpoint-done-failing-url fail "$tmp/endpoint-fail.md"
printf '%-1300s\nVERDICT: PASS\nVISIBLE-CHANGE: no\nENDPOINT-STATUS: done\n' body > "$tmp/endpoint-missing-url.md"; check endpoint-done-missing-url fail "$tmp/endpoint-missing-url.md"
printf 'SUMMARY: %s passed, %s failed\n' "$pass" "$fail"
(( fail == 0 ))
