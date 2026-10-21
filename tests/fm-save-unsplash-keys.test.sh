#!/usr/bin/env bash
# Bounded test for fm-save-unsplash-keys.sh using dummy keys only.
# Proves: save creates dir 700 / file 600, empty input refuses, overwrite refuses
# without --force, --check never prints a value, --path redirects the target.
set -uo pipefail

script="${1:-/root/bin/fm-save-unsplash-keys.sh}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0

ok() { echo "PASS: $1"; }
bad() { echo "FAIL: $1"; fail=1; }

mode_of() { stat --printf='%a' "$1" 2>/dev/null; }

# 1. save with piped input writes both keys, correct modes
out=$(printf 'DUMMY-A\nDUMMY-B\n' | bash "$script" --path "$tmp/one" 2>&1)
if [[ $? -eq 0 && -f "$tmp/one/credentials" ]]; then ok "save writes file"; else bad "save failed: $out"; fi
[[ $(mode_of "$tmp/one") == 700 ]] && ok "dir mode 700" || bad "dir mode $(mode_of "$tmp/one")"
[[ $(mode_of "$tmp/one/credentials") == 600 ]] && ok "file mode 600" || bad "file mode $(mode_of "$tmp/one/credentials")"
[[ $(grep -c '^UNSPLASH_[A-Z_]*=' "$tmp/one/credentials") -eq 2 ]] && ok "two keys" || bad "key count"

# 2. values are present exactly once, no duplication or truncation
grep -qx 'UNSPLASH_ACCESS_KEY=DUMMY-A' "$tmp/one/credentials" && ok "access key intact" || bad "access key wrong"
grep -qx 'UNSPLASH_SECRET_KEY=DUMMY-B' "$tmp/one/credentials" && ok "secret key intact" || bad "secret key wrong"

# 3. empty input refuses and writes nothing
out=$(printf '\n\n' | bash "$script" --path "$tmp/two" 2>&1)
[[ $? -ne 0 && ! -f "$tmp/two/credentials" ]] && ok "empty input refuses" || bad "empty input did not refuse: $out"

# 4. existing file is not silently overwritten
out=$(printf 'X\nY\n' | bash "$script" --path "$tmp/one" 2>&1)
[[ $? -ne 0 ]] && grep -qx 'UNSPLASH_ACCESS_KEY=DUMMY-A' "$tmp/one/credentials" \
  && ok "overwrite refused, original intact" || bad "overwrite guard failed: $out"

# 5. --force replaces
printf 'X\nY\n' | bash "$script" --path "$tmp/one" --force >/dev/null 2>&1
grep -qx 'UNSPLASH_ACCESS_KEY=X' "$tmp/one/credentials" && ok "--force replaces" || bad "--force did not replace"

# 6. --check reports without leaking any value
out=$(bash "$script" --path "$tmp/one" --check 2>&1)
if grep -q 'DUMMY-A\|DUMMY-B\|^X$\|UNSPLASH_ACCESS_KEY=X' <<<"$out"; then bad "--check leaked a value: $out"; else ok "--check leaks no value"; fi
grep -q 'keys: 2' <<<"$out" && ok "--check counts keys" || bad "--check count missing: $out"

# 7. --check on a missing file fails
bash "$script" --path "$tmp/none" --check >/dev/null 2>&1 && bad "--check passed on missing file" || ok "--check fails on missing"

# 8. default location is the user's own config dir (no --path)
out=$(printf 'D1\nD2\n' | HOME="$tmp/home" bash "$script" 2>&1)
[[ -f "$tmp/home/.config/unsplash/credentials" ]] && ok "default path under HOME" || bad "default path failed: $out"

# 9. secret must not appear in the script's own stdout
out=$(printf 'LEAKME\nLEAKME2\n' | bash "$script" --path "$tmp/three" 2>&1)
grep -q 'LEAKME' <<<"$out" && bad "value echoed to stdout: $out" || ok "no value echoed to stdout"

[[ $fail -eq 0 ]] && echo "ALL PASS" || echo "FAILURES PRESENT"
exit $fail