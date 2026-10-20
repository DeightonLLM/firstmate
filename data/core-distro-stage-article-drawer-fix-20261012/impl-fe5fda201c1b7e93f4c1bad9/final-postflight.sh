#!/usr/bin/env bash
# Final postflight: run every offline suite once more and emit the final manifest.
set -u
WS=/home/hd2admin/kun-agent-workspace/data/core-distro-stage-article-drawer-fix-20261012/impl-fe5fda201c1b7e93f4c1bad9
cd "$WS"
LOG=logs/10-final.log

{
  echo "=== FINAL POSTFLIGHT: all offline suites, post-change ==="
  echo
  echo "--- 1. targeted PHP suite: php tests/lighthouse-content-fixes.php ---"
} > "$LOG"

php tests/lighthouse-content-fixes.php >> "$LOG" 2>&1; F1=$?
echo "EXIT=$F1" >> "$LOG"

echo "" >> "$LOG"; echo "--- 2. node: node tests/lighthouse-remediation.mjs ---" >> "$LOG"
node tests/lighthouse-remediation.mjs >> "$LOG" 2>&1; F2=$?
echo "EXIT=$F2" >> "$LOG"

echo "" >> "$LOG"; echo "--- 3. python: python3 -m unittest discover -s tests -p test_extract_lighthouse_fixes.py ---" >> "$LOG"
python3 -m unittest discover -s tests -p 'test_extract_lighthouse_fixes.py' -v >> "$LOG" 2>&1; F3=$?
echo "EXIT=$F3" >> "$LOG"

echo "" >> "$LOG"; echo "--- 4. php -l syntax check, both changed files ---" >> "$LOG"
php -l theme/stage-content-fixes.php >> "$LOG" 2>&1; L1=$?
echo "EXIT=$L1" >> "$LOG"
php -l tests/lighthouse-content-fixes.php >> "$LOG" 2>&1; L2=$?
echo "EXIT=$L2" >> "$LOG"

{
  echo ""
  echo "FINAL_RESULTS php=$F1 node=$F2 python=$F3 lint=$L1,$L2"
  if [ "$F1" -eq 0 ] && [ "$F2" -eq 0 ] && [ "$F3" -eq 0 ] && [ "$L1" -eq 0 ] && [ "$L2" -eq 0 ]; then
    echo "ALL_OFFLINE_SUITES_GREEN"
  else
    echo "NOT_ALL_GREEN"
  fi
} >> "$LOG"

grep -E '^(SUMMARY|OK|Ran |EXIT=|FINAL_RESULTS|ALL_OFFLINE|NOT_ALL|No syntax)' "$LOG"

# Final manifest: every enumerated file, before vs after.
{
  printf 'file\tstate\tbefore_sha256\tafter_sha256\n'
  tail -n +2 manifest.tsv | while IFS=$'\t' read -r rel b h; do
    a=$(sha256sum "$rel" | cut -d' ' -f1)
    if [ "$a" = "$h" ]; then st=UNCHANGED; else st=CHANGED; fi
    printf '%s\t%s\t%s\t%s\n' "$rel" "$st" "$h" "$a"
  done
} > manifest-final.tsv
cp manifest-final.tsv evidence/final-manifest.tsv

echo ""
echo "=== FINAL MANIFEST ==="
cat manifest-final.tsv
echo ""
echo "=== EVIDENCE INVENTORY ==="
ls -1 logs/ | sed 's/^/  logs\//'
ls -1 evidence/ | grep -v '\.html$' | sed 's/^/  evidence\//'
echo "  evidence/rendered-output-*.html : $(ls -1 evidence/*.html 2>/dev/null | wc -l) rendered comparison artifacts"
echo ""
echo "diff_lines=$(wc -l < evidence/unified-two-file.diff)"
echo "changed_file_count=$(grep -c 'CHANGED' manifest-final.tsv)"