#!/usr/bin/env bash
# N08: Negative control — dedup broken: message NOT in handled ledger
# Expectation: poll REPORTS the message; fixture must exit 1 (proving fail-path works)
set -u
PATCHED="${PATCHED:-$1}"

TD=$(mktemp -d)
trap 'rm -rf "$TD"' EXIT

mkdir -p "$TD/inbox" "$TD/state"
echo "dedup v1" > "$TD/inbox/d1.md"
MT=$(stat -c '%Y' "$TD/inbox/d1.md")
echo "entered_epoch: $((MT - 10))" > "$TD/state/.afk-contract"
echo "1790000000" > "$TD/state/.afk"
# Deliberately NO handled ledger entry — message will be reported

cp "$PATCHED" "$TD/check.sh"
python3 -c "
c = open('$TD/check.sh').read()
c = c.replace('INBOX=/home/hd2admin/controller-replies', 'INBOX=$TD/inbox')
open('$TD/check.sh','w').write(c)
"

export FM_HOME="$TD" FM_STATE_OVERRIDE="$TD/state"
OUTPUT=$(bash "$TD/check.sh" 2>&1)

if [ -n "$OUTPUT" ]; then
  echo "EXPECTED FAIL (exit 1): message reported because not in handled ledger"
  echo "Output: $OUTPUT"
  exit 1
else
  echo "UNEXPECTED PASS: message was suppressed without handled ledger entry"
  exit 1
fi
