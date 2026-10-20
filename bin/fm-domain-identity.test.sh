#!/usr/bin/env bash
# bin/fm-domain-identity.test.sh - the behavior suite for the domain identity report.
#
# The suite drives bin/fm-domain-identity.sh through its executable interface
# against purpose-built fixture homes under a temp dir, so it asserts the
# published contract and never the tool's source bytes. It never touches a real
# home, a project, or the primary checkout.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/../tests/lib.sh"

TOOL="$ROOT/bin/fm-domain-identity.sh"
TMP_ROOT=$(fm_test_tmproot fm-domain-identity-tests)

FIXTURE_ROOT=""
PRIMARY=""
HOSTS=""
POOL=""
OUT=""
ERRTXT=""
RC=0

GIT_IDENTITY=(-c user.name='Firstmate Tests' -c user.email='tests@example.invalid')

# make_fixture <name>: a throwaway primary checkout plus the parent directory
# that holds a plain tool note, so every fixture home inherits one.
make_fixture() {
  local name=$1
  FIXTURE_ROOT="$TMP_ROOT/$name"
  PRIMARY="$FIXTURE_ROOT/primary"
  HOSTS="$FIXTURE_ROOT/hosts"
  POOL="$FIXTURE_ROOT/treehouse/primary-fixture"
  mkdir -p "$PRIMARY/data" "$PRIMARY/state" "$PRIMARY/bin" "$HOSTS" "$POOL"
  git -C "$PRIMARY" init -q -b main
  printf '# fixture primary AGENTS.md\n' > "$PRIMARY/AGENTS.md"
  printf '# fixture charter\n' > "$PRIMARY/data/charter.md"
  printf '#!/usr/bin/env bash\n' > "$PRIMARY/bin/placeholder.sh"
  printf 'data/\nstate/\n' > "$PRIMARY/.gitignore"
  git -C "$PRIMARY" add -A
  git -C "$PRIMARY" "${GIT_IDENTITY[@]}" commit -qm initial
  printf '# lean-ctx tool note\n' > "$HOSTS/AGENTS.md"
}

# advance_primary: a second primary commit, so a home left at the first commit
# is stale rather than current.
advance_primary() {
  printf '# fixture primary AGENTS.md v2\n' > "$PRIMARY/AGENTS.md"
  git -C "$PRIMARY" add -A
  git -C "$PRIMARY" "${GIT_IDENTITY[@]}" commit -qm second
}

# add_home <id> <kind>: a clone of the primary under the fixture parent dir.
# kind is one of healthy, stale, diverged, dirty, scoped, bare.
add_home() {
  local id=$1 kind=$2 home="$HOSTS/$1"
  git clone -q "$PRIMARY" "$home"
  case "$kind" in
    stale)
      git -C "$home" reset -q --hard HEAD~1
      ;;
    diverged)
      git -C "$home" reset -q --hard HEAD~1
      printf '# %s local work\n' "$id" > "$home/LOCAL.md"
      git -C "$home" add -A
      git -C "$home" "${GIT_IDENTITY[@]}" commit -qm "local $id commit"
      ;;
    dirty)
      printf '# %s uncommitted\n' "$id" > "$home/DIRTY.md"
      ;;
    scoped)
      write_override "$id" "$home" "$id"
      ;;
    bare) : ;;
    healthy) : ;;
    *) fail "unknown fixture home kind: $kind" ;;
  esac
  printf '%s\n' "$home"
}

# write_override <id> <home> <marker-id>: a domain identity file with a marker.
write_override() {
  local id=$1 home=$2 marker=${3:-$1}
  printf '# Domain identity for the %s secondmate home.\nDOMAIN-IDENTITY: %s\n' "$id" "$marker" \
    > "$home/AGENTS.override.md"
}

# register_home <id> <home>: a registry entry in the fixture secondmates file.
register_home() {
  printf -- '- %s - Fixture home %s. (home: %s; scope: The %s domain scope of the fixture.; projects: ; added 2026-01-01)\n' \
    "$1" "$1" "$2" "$1" >> "$PRIMARY/data/secondmates.md"
}

# run_tool <args...>: run the tool against the current fixture.
run_tool() {
  OUT="$TMP_ROOT/out.txt"
  ERRTXT="$TMP_ROOT/err.txt"
  FM_HOME="$PRIMARY" \
    FM_TREEHOUSE_ROOTS="$FIXTURE_ROOT/treehouse" \
    PI_CODING_AGENT_DIR="$FIXTURE_ROOT/pi-agent" \
    bash "$TOOL" "$@" > "$OUT" 2> "$ERRTXT"
  RC=$?
}

test_empty_fleet_attests_nothing() {
  make_fixture empty
  run_tool
  expect_code 0 "$RC" "an empty fleet must not fail the report"
  assert_grep "no registered secondmate home was found" "$OUT" "an empty fleet must say that it found no home"
  assert_grep "FLEET VERDICT: PASS - 0 registered homes found, nothing to attest" "$OUT" \
    "an empty fleet must not claim that a fleet is in sync"
  assert_no_grep "FLEET VERDICT: PASS - all" "$OUT" "an empty fleet must not claim that homes are in sync"
  pass "an empty fleet reports that it attests nothing"
}

test_healthy_home_passes() {
  local home
  make_fixture healthy
  advance_primary
  home=$(add_home healthy scoped)
  git -C "$home" pull -q --ff-only origin main
  register_home healthy "$home"
  run_tool
  expect_code 0 "$RC" "a domain-scoped home in sync with the primary must pass"
  assert_grep "FLEET VERDICT: PASS - all 1 registered home(s) are domain-scoped and in sync" "$OUT" \
    "the fleet verdict must name the passing home"
  assert_grep "verdict: PASS - domain-scoped and in sync with primary main" "$OUT" \
    "the home verdict must be a pass"
  pass "a domain-scoped home in sync with the primary passes"
}

test_stale_home_is_reported_as_stale() {
  local home
  make_fixture stale
  advance_primary
  home=$(add_home stale stale)
  register_home stale "$home"
  run_tool
  expect_code 1 "$RC" "a stale home must fail the report"
  assert_grep "sync: stale - 1 commit(s) behind primary main" "$OUT" "the stale sync state must be reported"
  assert_grep "commits-behind-primary-main: 1" "$OUT" "the behind count must be reported"
  assert_grep "stale against primary main" "$OUT" "the per-home verdict must name the staleness"
  assert_grep "FLEET VERDICT: FAIL" "$OUT" "the fleet verdict must fail"
  pass "a stale home is reported as stale"
}

test_diverged_home_is_reported_as_diverged() {
  local home
  make_fixture diverged
  advance_primary
  home=$(add_home diverged diverged)
  register_home diverged "$home"
  run_tool
  expect_code 1 "$RC" "a diverged home must fail the report"
  assert_grep "sync: diverged - 1 commit(s) only on this home, 1 commit(s) only on primary main" "$OUT" \
    "the diverged sync state must be reported"
  assert_grep "commits-ahead-of-primary-main: 1" "$OUT" "the ahead count must be reported"
  assert_grep "diverged from primary main" "$OUT" "the per-home verdict must name the divergence"
  pass "a diverged home is reported as diverged"
}

test_dirty_home_is_reported_as_dirty() {
  local home
  make_fixture dirty
  advance_primary
  home=$(add_home dirty dirty)
  git -C "$home" pull -q --ff-only origin main
  register_home dirty "$home"
  run_tool
  expect_code 1 "$RC" "a dirty home must fail the report"
  assert_grep "dirty: yes -" "$OUT" "the dirty worktree must be reported"
  assert_grep "dirty worktree" "$OUT" "the per-home verdict must name the dirty worktree"
  pass "a dirty home is reported as dirty"
}

test_home_without_override_reports_the_parent_contamination() {
  local home
  make_fixture contamination
  advance_primary
  home=$(add_home bare bare)
  git -C "$home" pull -q --ff-only origin main
  register_home bare "$home"
  run_tool
  expect_code 1 "$RC" "a home without a domain identity file must fail the report"
  assert_grep "domain-identity: absent - this home owns no domain identity file" "$OUT" \
    "the missing domain identity file must be reported"
  assert_grep "inherited-context: $HOSTS/AGENTS.md" "$OUT" \
    "the inherited parent context file must be named"
  assert_grep "a tool note, not a domain identity file" "$OUT" \
    "the inherited file must be reported as a note and not as a domain identity"
  assert_grep "no domain identity file" "$OUT" "the per-home verdict must name the missing identity"
  pass "a home without an override reports the parent contamination"
}

test_home_with_a_correct_override_is_domain_scoped() {
  local home
  make_fixture scoped
  advance_primary
  home=$(add_home scoped scoped)
  git -C "$home" pull -q --ff-only origin main
  register_home scoped "$home"
  run_tool
  expect_code 0 "$RC" "a domain-scoped home in sync with the primary must pass"
  assert_grep "domain-identity: present - the identity marker names scoped" "$OUT" \
    "the domain identity file must be recognised"
  assert_grep "context-file-in-home-dir: AGENTS.override.md" "$OUT" \
    "the override must be the context file that Pi loads from that directory"
  pass "a home with a correct override is domain-scoped"
}

test_home_with_a_foreign_marker_fails() {
  local home
  make_fixture foreign
  advance_primary
  home=$(add_home foreign scoped)
  write_override foreign "$home" "somebody-else"
  git -C "$home" pull -q --ff-only origin main
  register_home foreign "$home"
  run_tool
  expect_code 1 "$RC" "a domain identity file for another id must fail the report"
  assert_grep "the domain identity file names somebody-else, expected foreign" "$OUT" \
    "the marker mismatch must be reported"
  pass "a home with a foreign identity marker fails"
}

test_claude_md_shape_is_reported() {
  local symlink_home stub_home
  make_fixture claude
  advance_primary
  symlink_home=$(add_home symlink bare)
  stub_home=$(add_home stub bare)
  git -C "$symlink_home" pull -q --ff-only origin main
  git -C "$stub_home" pull -q --ff-only origin main
  ln -s AGENTS.md "$symlink_home/CLAUDE.md"
  printf '<!-- Points Claude at AGENTS.md via import; edit AGENTS.md, not this file. -->\n@AGENTS.md\n' \
    > "$stub_home/CLAUDE.md"
  register_home symlink "$symlink_home"
  register_home stub "$stub_home"
  run_tool
  assert_grep "claude-md: symlink -> AGENTS.md" "$OUT" "a symlinked CLAUDE.md must be reported as a symlink"
  assert_grep "claude-md: import stub" "$OUT" "an import stub CLAUDE.md must be reported as a stub"
  pass "the CLAUDE.md shape is reported"
}

test_read_only_run_writes_nothing() {
  local home
  make_fixture readonly
  advance_primary
  home=$(add_home readonly bare)
  git -C "$home" pull -q --ff-only origin main
  register_home readonly "$home"
  run_tool
  assert_absent "$home/AGENTS.override.md" "a read-only run must not write a domain identity file"
  assert_present "$HOSTS/AGENTS.md" "a read-only run must not touch the parent note"
  if [ -n "$(git -C "$PRIMARY" status --porcelain)" ]; then
    fail "a read-only run must leave the fixture primary clean"
  fi
  pass "a read-only run writes nothing"
}

test_apply_writes_the_identity_file() {
  local home
  make_fixture apply
  advance_primary
  home=$(add_home apply bare)
  git -C "$home" pull -q --ff-only origin main
  register_home apply "$home"
  run_tool --apply
  assert_present "$home/AGENTS.override.md" "--apply must write the domain identity file"
  assert_grep "DOMAIN-IDENTITY: apply" "$home/AGENTS.override.md" "the written file must carry the identity marker"
  assert_grep "This home is not the primary firstmate home." "$home/AGENTS.override.md" \
    "the written file must state that the home is not the primary"
  assert_grep "data/secondmates.md are authoritative for the fleet" "$home/AGENTS.override.md" \
    "the written file must name the primary sources of truth"
  assert_grep "Its charter is $home/data/charter.md." "$home/AGENTS.override.md" \
    "the written file must name the charter path"
  pass "--apply writes the domain identity file"
}

test_apply_is_idempotent() {
  local home first second
  make_fixture idempotent
  advance_primary
  home=$(add_home idempotent bare)
  git -C "$home" pull -q --ff-only origin main
  register_home idempotent "$home"
  run_tool --apply
  first=$(sha256sum "$home/AGENTS.override.md" | cut -d' ' -f1)
  run_tool --apply
  second=$(sha256sum "$home/AGENTS.override.md" | cut -d' ' -f1)
  expect_code "$first" "$second" "a second --apply must produce byte identical bytes"
  assert_grep "apply: unchanged" "$OUT" "a second --apply must report the file as unchanged"
  pass "--apply is idempotent"
}

test_apply_refuses_to_overwrite_without_force() {
  local home before after
  make_fixture overwrite
  advance_primary
  home=$(add_home overwrite bare)
  git -C "$home" pull -q --ff-only origin main
  register_home overwrite "$home"
  printf '# a different identity file\nDOMAIN-IDENTITY: overwrite\n' > "$home/AGENTS.override.md"
  before=$(sha256sum "$home/AGENTS.override.md" | cut -d' ' -f1)
  run_tool --apply
  expect_code 1 "$RC" "an overwrite without --force must fail"
  after=$(sha256sum "$home/AGENTS.override.md" | cut -d' ' -f1)
  expect_code "$before" "$after" "an overwrite without --force must not change the file"
  assert_grep "refused - re-run with --force to overwrite" "$OUT" "the refusal must be printed"
  assert_grep "current $home/AGENTS.override.md" "$OUT" "the diff of the refused overwrite must be printed"
  run_tool --apply --force
  expect_code 0 "$RC" "--force must allow the overwrite"
  assert_grep "apply: wrote $home/AGENTS.override.md" "$OUT" "--force must write the file"
  pass "--apply refuses an overwrite without --force"
}

test_apply_refuses_a_diverged_home() {
  local home
  make_fixture divergedapply
  advance_primary
  home=$(add_home divergedapply diverged)
  register_home divergedapply "$home"
  run_tool --apply
  expect_code 1 "$RC" "an apply into a diverged home must fail"
  assert_absent "$home/AGENTS.override.md" "an apply into a diverged home must not write the file"
  assert_grep "refusing to write into a home that is not clean and current" "$OUT" \
    "the refusal reason must be printed"
  assert_grep "apply: sync: diverged" "$OUT" "the diverged state must be printed with the refusal"
  pass "--apply refuses a diverged home"
}

test_apply_refuses_a_dirty_home() {
  local home
  make_fixture dirtyapply
  advance_primary
  home=$(add_home dirtyapply dirty)
  git -C "$home" pull -q --ff-only origin main
  register_home dirtyapply "$home"
  run_tool --apply
  expect_code 1 "$RC" "an apply into a dirty home must fail"
  assert_absent "$home/AGENTS.override.md" "an apply into a dirty home must not write the file"
  assert_grep "apply: dirty: yes" "$OUT" "the dirty state must be printed with the refusal"
  pass "--apply refuses a dirty home"
}

test_usage_errors_exit_two() {
  make_fixture usage
  run_tool --force
  expect_code 2 "$RC" "--force without --apply must be a usage error"
  run_tool --nonsense
  expect_code 2 "$RC" "an unknown argument must be a usage error"
  run_tool --home
  expect_code 2 "$RC" "--home without an id must be a usage error"
  run_tool --home no-such-home
  expect_code 2 "$RC" "an unknown home id must be a usage error"
  pass "a usage error exits 2"
}

test_help_exits_zero() {
  run_tool --help
  expect_code 0 "$RC" "--help must exit zero"
  assert_grep "fm-domain-identity.sh" "$OUT" "--help must print the usage"
  pass "--help exits 0"
}

test_the_git_guard_allows_read_only_subcommands_only() {
  local guard line count start end
  guard=$(grep -n '^DI_GIT_READONLY=' "$TOOL" | cut -d= -f2-)
  for forbidden in fetch pull checkout merge reset stash clean gc commit push rebase cherry-pick; do
    case " $guard " in
      *" $forbidden "*) fail "the git guard must not allow the subcommand $forbidden" ;;
    esac
  done
  count=$(grep -cE '(^|[[:space:];|&(])git[[:space:]]+-[A-Za-z]' "$TOOL" || true)
  expect_code 1 "$count" "the tool must hold exactly one git invocation"
  line=$(grep -nE '(^|[[:space:];|&(])git[[:space:]]+-[A-Za-z]' "$TOOL" | cut -d: -f1)
  start=$(grep -n '^di_git() {' "$TOOL" | cut -d: -f1)
  end=$(awk -v s="$start" 'NR > s && /^}$/ { print NR; exit }' "$TOOL")
  if [ "$line" -lt "$start" ] || [ "$line" -gt "$end" ]; then
    fail "the only git invocation must sit inside the read-only guard"
  fi
  pass "the git guard allows read-only subcommands only"
}

test_the_census_reports_slot_fingerprints() {
  local slot fingerprint
  make_fixture census
  slot="$POOL/1/primary-home"
  mkdir -p "$slot/bin"
  printf '# slot AGENTS.md\n' > "$slot/AGENTS.md"
  printf '#!/usr/bin/env bash\n' > "$slot/bin/placeholder.sh"
  fingerprint=$(sha256sum "$slot/AGENTS.md" | cut -c1-12)
  run_tool
  assert_grep "census: AGENTS.md fingerprint per firstmate-home slot" "$OUT" "the census must be printed"
  assert_grep "$fingerprint" "$OUT" "the slot fingerprint must be in the census"
  assert_grep "primary-fixture/1/primary-home" "$OUT" "the slot path must be in the census"
  pass "the census reports the slot fingerprints"
}

test_a_seeded_home_outside_the_registered_set_is_reported() {
  local slot
  make_fixture seeded
  slot="$POOL/2/seeded-home"
  mkdir -p "$slot/bin"
  printf '# slot AGENTS.md\n' > "$slot/AGENTS.md"
  printf '#!/usr/bin/env bash\n' > "$slot/bin/placeholder.sh"
  printf 'orphan-domain\n' > "$slot/.fm-secondmate-home"
  run_tool
  assert_grep "seeded homes outside the registered set" "$OUT" "a seeded home outside the registered set must be reported"
  assert_grep "orphan-domain" "$OUT" "the unregistered seeded home must be named"
  pass "a seeded home outside the registered set is reported"
}

run_tests() {
  test_empty_fleet_attests_nothing
  test_healthy_home_passes
  test_stale_home_is_reported_as_stale
  test_diverged_home_is_reported_as_diverged
  test_dirty_home_is_reported_as_dirty
  test_home_without_override_reports_the_parent_contamination
  test_home_with_a_correct_override_is_domain_scoped
  test_home_with_a_foreign_marker_fails
  test_claude_md_shape_is_reported
  test_read_only_run_writes_nothing
  test_apply_writes_the_identity_file
  test_apply_is_idempotent
  test_apply_refuses_to_overwrite_without_force
  test_apply_refuses_a_diverged_home
  test_apply_refuses_a_dirty_home
  test_usage_errors_exit_two
  test_help_exits_zero
  test_the_git_guard_allows_read_only_subcommands_only
  test_the_census_reports_slot_fingerprints
  test_a_seeded_home_outside_the_registered_set_is_reported
}

run_tests
