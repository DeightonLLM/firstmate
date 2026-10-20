#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CHECK="$ROOT/bin/fm-scope-check.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
REGISTRY="$TMP/scopes.tsv"
cat > "$REGISTRY" <<'EOF'
owner\tsurface\tread_domains\twrite_domains\texclusions\tnotes
alpha\ttest\tapp.code,app.docs\tapp.code,app.docs\tapp.docs\tfixture
beta\ttest\tother.code\tother.code\t\tfixture
EOF
# Convert readable escaped delimiters into literal TSV tabs.
python3 - "$REGISTRY" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_text(p.read_text().replace(r"\t", "\t"))
PY

pass=0
fail=0
check() {
  local name=$1 expected=$2 owner=$3 domain=$4 registry=${5:-$REGISTRY}
  local output rc
  set +e
  output=$("$CHECK" --registry "$registry" "$owner" "$domain" 2>&1)
  rc=$?
  set -e
  if [[ $output == *"$expected"* ]]; then
    printf 'PASS %s\n' "$name"
    ((pass += 1))
  else
    printf 'FAIL %s (exit=%s output=%s)\n' "$name" "$rc" "$output"
    ((fail += 1))
  fi
}

check 'in-scope ALLOW' 'ALLOW' alpha app.code
check 'out-of-scope REFUSE' 'REFUSE' alpha out.of.scope
check 'cross-domain REFUSE though another owner has it' 'REFUSE' alpha other.code
check 'unknown owner REFUSE' 'REFUSE' nobody app.code
check 'exclusion overrides matching write_domain' 'REFUSE' alpha app.docs
chmod 000 "$REGISTRY"
output=$("$CHECK" --registry "$REGISTRY" alpha app.code 2>&1 || true)
if [[ $output == *'REFUSE:'* ]]; then
  printf 'PASS unreadable registry REFUSE\n'
  ((pass += 1))
else
  printf 'FAIL unreadable registry REFUSE (output=%s)\n' "$output"
  ((fail += 1))
fi
printf 'RESULT %d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
