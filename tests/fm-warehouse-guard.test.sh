#!/usr/bin/env bash
# fm-warehouse-guard.test.sh — proves the warehouse guard refuses writes into the
# Controller-owned warehouse and allows everything else, including reads.
#
# Run: /bin/bash tests/fm-warehouse-guard.test.sh
set -u

GUARD="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/fm-warehouse-guard.sh"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAREHOUSE="${FM_WAREHOUSE_ROOT:-$ROOT/warehouse}"
PASS=0
FAIL=0

ok() { printf 'ok - %s\n' "$1"; PASS=$((PASS + 1)); }
not_ok() { printf 'not ok - %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

refuses() {
  local p=$1 label=$2 out code
  out=$(bash "$GUARD" "$p" 2>&1); code=$?
  if [ "$code" = 77 ]; then
    ok "$label refused with the sanctioned-route reason"
  else
    not_ok "$label was allowed (exit $code): $out"
  fi
}

allows() {
  local p=$1 label=$2 out code
  out=$(bash "$GUARD" "$p" 2>&1); code=$?
  if [ "$code" = 0 ]; then
    ok "$label allowed"
  else
    not_ok "$label was refused (exit $code): $out"
  fi
}

[ -x "$GUARD" ] || { printf 'not ok - guard is not executable\n' >&2; printf 'PASS=0 FAIL=1\n'; exit 1; }

refuses "$WAREHOUSE"                                  'the warehouse root itself'
refuses "$WAREHOUSE/lessons/x.md"                     'a file inside the warehouse'
refuses "$WAREHOUSE/a/b/c/d.md"                       'a deeply nested warehouse file'
refuses "$WAREHOUSE/../warehouse/x.md"                'a traversal that lands back inside'
refuses "$WAREHOUSE/./x.md"                           'a dot-segment inside the warehouse'

allows "$ROOT/data/x.md"                              'a normal home data file'
allows "$ROOT/bin/x.sh"                               'a normal home script'
allows "/home/hd2admin/controller-replies/x.md"       'the exchange directory'
allows "$ROOT/warehouse-backup/x.md"                  'a sibling whose name merely starts with warehouse'
allows "$ROOT/WAREHOUSE/x.md"                         'a path matching the name case-sensitively elsewhere'

# Classification is by PATH. The guard cannot tell a read from a write, and must
# not pretend to: a gate that inferred intent from a path would be the same
# prose-inference failure Controller refused to build elsewhere. Reads of the
# mirror never pass through this guard at all — they use ordinary file reads, which
# are unrestricted. What must hold is that the guard NEVER allows a warehouse path.
out=$(bash "$GUARD" "$WAREHOUSE/reports/example.md" 2>&1)
if printf '%s' "$out" | grep -q 'REFUSED'; then
  ok 'a warehouse path is refused unconditionally, reads excluded by being a different route'
else
  not_ok "warehouse path was not refused: $out"
fi

# Refusal must name the sanctioned route, or the guard is a wall with no door.
out=$(bash "$GUARD" "$WAREHOUSE/x.md" 2>&1)
if printf '%s' "$out" | grep -q 'fm-outbound.sh'; then
  ok 'refusal points at the sanctioned outbox route'
else
  not_ok 'refusal does not name the outbox route'
fi

# Empty argument is a usage error, not a silent allow.
bash "$GUARD" >/dev/null 2>&1
if [ $? = 2 ]; then
  ok 'empty path is a usage error rather than a silent allow'
else
  not_ok 'empty path did not produce a usage error'
fi

printf 'PASS=%d FAIL=%d\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ] || exit 1