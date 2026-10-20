#!/usr/bin/env bash
# N11: Negative control — INBOX is real dir (not symlink); no safe-error produced
# Expectation: poll succeeds normally; fixture must exit 1 (proving error-check works)
set -u
PATCHED="${PATCHED:-$1}"

TD=$(mktemp -d)
trap 'rm -rf "$TD"' EXIT

mkdir -p "$TD/inbox"
echo "good" > "$TD/inbox/g.md"
mkdir -p "$TD/state"
echo "entered_epoch: 1790000000" > "$TD/state/.afk-contract"
echo "1790000000" > "$TD/state/.afk"

cp "$PATCHED" "$TD/check.sh"
python3 -c "
c = open('$TD/check.sh').read()
c = c.replace('INBOX=/home/hd2admin/controller-replies', 'INBOX=$TD/inbox')
open('$TD/check.sh','w').write(c)
"

export FM_HOME="$TD" FM_STATE_OVERRIDE="$TD/state"
OUTPUT=$(bash "$TD/check.sh" 2>&1)

if ! echo "$OUTPUT" | grep -q 'directory is unavailable'; then
  echo "EXPECTED FAIL (exit 1): real INBOX produced no symlink error"
  echo "Output: $OUTPUT"
  exit 1
else
  echo "UNEXPECTED PASS: symlink error appeared for real directory"
  echo "Output: $OUTPUT"
  exit 1
fi
