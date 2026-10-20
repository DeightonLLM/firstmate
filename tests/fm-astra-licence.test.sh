#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/fm-astra-licence.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
THEME="$TMP/theme"
mkdir -p "$THEME"
printf 'Theme Name: Astra\nVersion: 1.0\n' > "$THEME/style.css"
PASS=0
FAIL=0

check() {
  local name="$1"
  shift
  if "$@"; then
    printf 'PASS: %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf 'FAIL: %s\n' "$name" >&2
    FAIL=$((FAIL + 1))
  fi
}

has_rows() {
  local registry="$1" expected="$2"
  [ "$(awk 'END { print NR - 1 }' "$registry")" -eq "$expected" ]
}

run_ingest_twice() {
  local registry="$TMP/ingest.tsv" input="$TMP/input.tsv" before after
  printf 'site\tastra_version\tedition\ttheme_sha256\tlicence_fp\tlicence_last4\tregistered\tstatus\tnotes\nalpha\t1.0\tpro\thash\tfp\t1234\t2026-10-19\tregistered\t\n' > "$registry"
  printf 'site\tastra_version\tedition\ttheme_sha256\tlicence_fp\tlicence_last4\tregistered\tstatus\tnotes\nalpha\t1.0\tpro\thash\tfp\t1234\t2026-10-19\tregistered\t\n' > "$input"
  FM_ASTRA_REGISTRY="$registry" "$SCRIPT" ingest "$input" >/dev/null || return 1
  before="$(awk 'END { print NR }' "$registry")"
  FM_ASTRA_REGISTRY="$registry" "$SCRIPT" ingest "$input" >/dev/null || return 1
  after="$(awk 'END { print NR }' "$registry")"
  [ "$before" -eq 2 ] && [ "$after" -eq "$before" ]
}

verify_registered() {
  local registry="$TMP/registered.tsv"
  printf 'site\tastra_version\tedition\ttheme_sha256\tlicence_fp\tlicence_last4\tregistered\tstatus\tnotes\nregistered-site\t1.0\tpro\thash\tfp\t1234\t2026-10-19\tregistered\t\n' > "$registry"
  FM_ASTRA_REGISTRY="$registry" "$SCRIPT" verify registered-site >/dev/null 2>&1
}

verify_unlicensed_fails() {
  local registry="$TMP/unlicensed.tsv"
  printf 'site\tastra_version\tedition\ttheme_sha256\tlicence_fp\tlicence_last4\tregistered\tstatus\tnotes\nlocked-site\t1.0\tpro\thash\t-\t-\t2026-10-19\tUNLICENSED-no-key-on-file\t\n' > "$registry"
  if FM_ASTRA_REGISTRY="$registry" "$SCRIPT" verify locked-site >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

verify_missing_fails() {
  local registry="$TMP/missing.tsv"
  printf 'site\tastra_version\tedition\ttheme_sha256\tlicence_fp\tlicence_last4\tregistered\tstatus\tnotes\n' > "$registry"
  if FM_ASTRA_REGISTRY="$registry" "$SCRIPT" verify absent-site >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

register_does_not_store_key() {
  local registry="$TMP/secret.tsv" key='ASTRA-SECRET-KEY-9876543210'
  FM_ASTRA_REGISTRY="$registry" "$SCRIPT" register secret-site "$THEME" pro "$key" >/dev/null || return 1
  ! grep -Fq "$key" "$registry" || return 1
  [ "$(awk -F '\t' 'NR==2 {print $5}' "$registry")" = "$(printf '%s' "$key" | sha256sum | cut -d' ' -f1)" ] || return 1
  [ "$(awk -F '\t' 'NR==2 {print $6}' "$registry")" = "3210" ]
}

check 'ingest same existing row twice leaves row count unchanged' run_ingest_twice
check 'verify accepts registered row' verify_registered
check 'verify rejects UNLICENSED row (negative control)' verify_unlicensed_fails
check 'verify rejects MISSING site (negative control)' verify_missing_fails
check 'register stores fingerprint and last four, not raw key (negative control)' register_does_not_store_key
printf 'RESULT: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
