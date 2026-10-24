#!/usr/bin/env bash
# Focused tests for the visible surface-name grammar and its enforcement.
#
# Covers the rule in docs/surface-naming-contract.md:
#   - the scope token and its segments
#   - the workspace label, summary and projection grammars
#   - the task tab label
#   - the legacy forms the matcher still accepts
#   - the enforcement check, including a DELIBERATELY misnamed snapshot
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

TMP_ROOT=$(fm_test_tmproot fm-surface-name)
FM_TEST_CLEANUP_DIRS+=("$TMP_ROOT")
trap fm_test_cleanup EXIT

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

# shellcheck source=bin/fm-surface-name-lib.sh
. "$ROOT/bin/fm-surface-name-lib.sh"

export FM_SURFACE_HOST=testhost

# --- the host token ----------------------------------------------------------

[ "$(fm_surface_name_host)" = "testhost" ] \
  || fail "FM_SURFACE_HOST must override the host token"
pass "fm_surface_name_host: an explicit override wins"

(
  unset FM_SURFACE_HOST
  out=$(fm_surface_name_host)
  case "$out" in
    hetz|controller|hd2|local) ;;
    *) exit 1 ;;
  esac
) || fail "an unrecognised host must resolve to a named surface or 'local', never a guess"
pass "fm_surface_name_host: an unrecognised host resolves to a known token"

# --- the home segment --------------------------------------------------------

PRIMARY_DIR="$TMP_ROOT/primary-home"
SECOND_DIR="$TMP_ROOT/secondmate-home"
mkdir -p "$PRIMARY_DIR" "$SECOND_DIR"
[ "$(fm_surface_name_home_scope "$PRIMARY_DIR")" = "primary" ] \
  || fail "a home with no secondmate marker must be 'primary'"
printf 'runner\n' > "$SECOND_DIR/.fm-secondmate-home"
[ "$(fm_surface_name_home_scope "$SECOND_DIR")" = "2ndmate-runner" ] \
  || fail "a home with a secondmate marker must be '2ndmate-<id>'"
pass "fm_surface_name_home_scope: the home segment comes from the home's own marker"

# --- the scope token ---------------------------------------------------------

[ "$(fm_surface_name_scope "$SECOND_DIR")" = "testhost/2ndmate-runner" ] \
  || fail "a secondmate scope must be '<host>/2ndmate-<id>'"
[ "$(fm_surface_name_scope "$PRIMARY_DIR")" = "testhost/primary" ] \
  || fail "a primary scope must be '<host>/primary'"
[ "$(fm_surface_name_scope "$PRIMARY_DIR" afk)" = "testhost/primary/afk" ] \
  || fail "a role scope must be '<host>/<home>/<role>'"
pass "fm_surface_name_scope: host, home and optional role"

fm_surface_name_scope_valid "testhost/primary" || fail "a two-segment scope must be valid"
fm_surface_name_scope_valid "testhost/primary/afk" || fail "a three-segment scope must be valid"
fm_surface_name_scope_valid "testhost/2ndmate-runner" || fail "a secondmate scope must be valid"
fm_surface_name_scope_valid "testhost" && fail "a scope without a home must be refused"
fm_surface_name_scope_valid "testhost/" && fail "a scope with an empty segment must be refused"
fm_surface_name_scope_valid "/primary" && fail "a scope with an empty host must be refused"
fm_surface_name_scope_valid "a/b/c/d" && fail "a scope with four segments must be refused"
fm_surface_name_scope_valid "testhost/rogue" && fail "an unknown home must be refused"
fm_surface_name_scope_valid "testhost/2ndmate-" && fail "an empty secondmate id must be refused"
fm_surface_name_scope_valid "TESTHOST/Primary" && fail "a scope with capitals must be refused"
pass "fm_surface_name_scope_valid: only host/home[/role] with lowercase tokens passes"

# --- the workspace label -----------------------------------------------------

[ "$(fm_surface_name_workspace_label "testhost/primary" "3 lanes")" = "testhost/primary · 3 lanes" ] \
  || fail "the workspace label must join scope and summary with one separator"
pass "fm_surface_name_workspace_label: scope, separator, summary"

[ "$(fm_surface_name_lane_summary 1 "my-lane")" = "my-lane" ] \
  || fail "a container with one lane must read AS that lane"
[ "$(fm_surface_name_lane_summary 4)" = "4 lanes" ] \
  || fail "a container with several lanes must read as a count"
[ "$(fm_surface_name_lane_summary 0)" = "no lanes" ] \
  || fail "a container with no lane must say so"
pass "fm_surface_name_lane_summary: one lane reads as the lane, more reads as a count"

[ "$(fm_surface_name_scope_of "testhost/primary · 3 lanes")" = "testhost/primary" ] \
  || fail "the scope of a labelled container must be the part before the separator"
[ "$(fm_surface_name_scope_of "testhost/primary")" = "testhost/primary" ] \
  || fail "the scope of an unlabelled container is the whole label"
pass "fm_surface_name_scope_of: the scope is the part before the first separator"

# --- conformance -------------------------------------------------------------

fm_surface_name_workspace_conforms "testhost/primary · 3 lanes" \
  || fail "a scoped, summarised container must conform"
fm_surface_name_workspace_conforms "testhost/primary" \
  || fail "a scope-only container must conform"
fm_surface_name_workspace_conforms "firstmate" \
  && fail "a legacy home label must NOT conform"
fm_surface_name_workspace_conforms "2ndmate-runner" \
  && fail "a legacy secondmate label must NOT conform"
fm_surface_name_workspace_conforms "firstmate-afk-daemon-1-2-3" \
  && fail "a legacy away-mode label must NOT conform"
fm_surface_name_workspace_conforms "" && fail "an empty label must NOT conform"
fm_surface_name_workspace_conforms "testhost" && fail "a scope-less label must NOT conform"
fm_surface_name_workspace_conforms "testhost/primary · " \
  && fail "an empty summary must NOT conform"
fm_surface_name_workspace_conforms "testhost/primary · arbitrary garbage" \
  && fail "an unconstrained workspace summary must NOT conform"
fm_surface_name_workspace_conforms "testhost/primary · 3 live lanes" \
  && fail "a non-contract workspace count must NOT conform"
fm_surface_name_workspace_conforms "testhost/primary · afk-daemon f962fcac" \
  || fail "an away-mode summary with an eight-character nonce must conform"
fm_surface_name_workspace_conforms "testhost/primary · afk-daemon too-short" \
  && fail "an away-mode summary with an invalid nonce must NOT conform"
pass "fm_surface_name_workspace_conforms: legacy and scope-less labels are violations"

fm_surface_name_projection_conforms "└ testhost/primary · my-lane · p:AbCdEfGhIjKlMnOpQrStUv" \
  || fail "a projection label must conform"
fm_surface_name_projection_conforms "└ my-lane · p:AbCdEfGhIjKlMnOpQrStUv" \
  && fail "a projection label without a scope must NOT conform"
fm_surface_name_projection_conforms "└ testhost/primary · my-lane · p:short" \
  && fail "a projection label with a short token must NOT conform"
fm_surface_name_projection_conforms "└ testhost/primary · my lane · p:AbCdEfGhIjKlMnOpQrStUv" \
  && fail "a projection label with an unconstrained lane must NOT conform"
fm_surface_name_projection_conforms "└ testhost/primary · my-lane · extra · p:AbCdEfGhIjKlMnOpQrStUv" \
  && fail "a projection label with an extra separator must NOT conform"
pass "fm_surface_name_projection_conforms: marker, scope, lane and a full token"

fm_surface_name_tab_conforms "fm-my-lane" || fail "a task tab label must conform"
fm_surface_name_tab_conforms "my-lane" && fail "a tab label without the fm- prefix must NOT conform"
fm_surface_name_tab_conforms "fm-" && fail "an empty lane id must NOT conform"
pass "fm_surface_name_tab_conforms: a task tab label is fm-<lane-id>"

[ "$(fm_surface_name_lane_of_tab "fm-my-lane")" = "my-lane" ] \
  || fail "the lane id must be recoverable from a task tab label"
pass "fm_surface_name_lane_of_tab: the lane id is the tab label without its prefix"

# --- legacy forms the matcher still accepts ---------------------------------

[ "$(fm_surface_name_legacy_scope "firstmate")" = "firstmate" ] \
  || fail "the legacy primary label must be recognised"
[ "$(fm_surface_name_legacy_scope "2ndmate-runner")" = "2ndmate-runner" ] \
  || fail "the legacy secondmate label must be recognised"
fm_surface_name_legacy_scope "2ndmate-" \
  && fail "an empty legacy secondmate id must be refused"
fm_surface_name_legacy_scope "testhost/primary" \
  && fail "a scope-form label is not a legacy label"
pass "fm_surface_name_legacy_scope: the legacy home labels are recognised"

[ "$(fm_surface_name_legacy_home_label "testhost/primary")" = "firstmate" ] \
  || fail "a primary scope must map back to the legacy primary label"
[ "$(fm_surface_name_legacy_home_label "testhost/2ndmate-runner")" = "2ndmate-runner" ] \
  || fail "a secondmate scope must map back to the legacy secondmate label"
fm_surface_name_legacy_home_label "testhost/2ndmate-" \
  && fail "a scope with an empty secondmate id must not map to a legacy label"
pass "fm_surface_name_legacy_home_label: a scope maps back to its legacy label"

# --- the census field discipline ---------------------------------------------

# shellcheck source=bin/fm-surface-census-lib.sh
. "$ROOT/bin/fm-surface-census-lib.sh"

# A tab is IFS WHITESPACE: a read with IFS=tab silently collapses consecutive
# separators, so one empty field shifts every column after it. The census
# therefore uses U+001F, and this pins that.
[ "$FM_SURFACE_CENSUS_FS" = "$(printf '\037')" ] \
  || fail "the census separator must be U+001F, not a whitespace character"
row=$(printf 'a\037\037c')
IFS=$'\037' read -r f1 f2 f3 <<< "$row"
[ "$f1" = a ] && [ -z "$f2" ] && [ "$f3" = c ] \
  || fail "an empty middle field must survive the census separator"
pass "fm-surface-census-lib.sh: the census separator preserves empty fields"

CENSUS_BIN="$TMP_ROOT/census-bin"
CENSUS_STATE="$TMP_ROOT/census-state"
mkdir -p "$CENSUS_BIN" "$CENSUS_STATE"
cat > "$CENSUS_BIN/herdr" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' '{"result":{"panes":[{"pane_id":"w1:p1","tab_id":"t1","workspace_id":"w1","agent":"codex","agent_status":"working"}]}}'
STUB
chmod +x "$CENSUS_BIN/herdr"
printf 'endpoint_task_id=codex-task\nwindow=default:w1:p1\nharness=codex\nmodel=MiniMax-M3.1-Flash\nkind=ship\nherdr_tab_id=t1\n' \
  > "$CENSUS_STATE/codex-task.meta"
printf 'endpoint_task_id=codex-task\nwindow=default:w1:p1\nharness=codex\nmodel=MiniMax-M3.1-Flash\nkind=ship\nherdr_tab_id=t1\n' \
  > "$CENSUS_STATE/lane-001.meta"
census_rows=$(PATH="$CENSUS_BIN:$PATH" fm_surface_census_lanes "$CENSUS_STATE" default)
[ "$(printf '%s\n' "$census_rows" | awk 'NF { n++ } END { print n + 0 }')" = 1 ] \
  || fail "slot and task metadata for one endpoint must produce one census row"
[ "$(printf '%s\n' "$census_rows" | awk -F"$FM_SURFACE_CENSUS_FS" 'NF { print $1 }')" = "codex-task" ] \
  || fail "the census must prefer the canonical task metadata row"
pass "fm-surface-census-lanes: endpoint identity is deduplicated"

# --- the view answers the Captain's question ---------------------------------

out=$(bash "$ROOT/bin/fm-surface-view.sh" --help 2>&1)
rc=$?
[ "$rc" -eq 0 ] || fail "the surface view must print its usage, got rc=$rc"
printf '%s' "$out" | grep -q "fm-surface-view.sh" \
  || fail "the surface view usage must name the command"
printf '%s' "$out" | grep -q "LIVE" \
  || fail "the surface view usage must name the states it distinguishes"
pass "fm-surface-view.sh: the view is runnable and names the states it distinguishes"

# --- the enforcement check on a snapshot --------------------------------------

SNAPSHOT="$TMP_ROOT/snapshot.tsv"
{
  printf 'workspace\tw1\ttesthost/primary · 3 lanes\n'
  printf 'workspace\tw2\tfirstmate\n'
  printf 'workspace\tw3\t2ndmate-runner\n'
  printf 'workspace\tw4\tfirstmate-afk-daemon-659043-363-1792753227\n'
  printf 'workspace\tw5\t└ my-lane · p:AbCdEfGhIjKlMnOpQrStUv\n'
  printf 'workspace\tw6\t└ testhost/primary · my-lane · p:AbCdEfGhIjKlMnOpQrStUv\n'
  printf 'workspace\tw7\t└ testhost/primary · my-lane · p:short\n'
  printf 'tab\tw1:t1\tfm-good-lane\n'
  printf 'tab\tw1:t2\tbad-lane-label\n'
} > "$SNAPSHOT"

out=$(bash "$ROOT/bin/fm-surface-name-check.sh" --from-file "$SNAPSHOT" 2>&1)
rc=$?
[ "$rc" -eq 1 ] || fail "a misnamed snapshot must fail the check, got rc=$rc"
printf '%s' "$out" | grep -q "workspace w2" || fail "the legacy primary label must be reported"
printf '%s' "$out" | grep -q "workspace w3" || fail "the legacy secondmate label must be reported"
printf '%s' "$out" | grep -q "workspace w4" || fail "the legacy away-mode label must be reported"
printf '%s' "$out" | grep -q "workspace w5" || fail "a scope-less projection label must be reported"
printf '%s' "$out" | grep -q "should read" || fail "every violation must carry the label it should read"
printf '%s' "$out" | grep -q "workspace w1" && fail "a conforming container must NOT be reported"
printf '%s' "$out" | grep -q "workspace w6" && fail "a conforming projection must NOT be reported"
printf '%s' "$out" | grep -q "workspace w7 should read" && fail "an invalid projection must not receive an invalid replacement"
pass "fm-surface-name-check.sh: a misnamed snapshot fails and names every violation"

out=$(bash "$ROOT/bin/fm-surface-name-check.sh" --from-file "$SNAPSHOT" 2>&1)
printf '%s' "$out" | grep -q "tab w1:t2" || fail "a tab that is not a task tab label must be reported"
printf '%s' "$out" | grep -q "tab w1:t1" && fail "a conforming task tab must NOT be reported"
pass "fm-surface-name-check.sh: a misnamed tab is reported and a good one is not"

CLEAN="$TMP_ROOT/clean.tsv"
{
  printf 'workspace\tw1\ttesthost/primary · 3 lanes\n'
  printf 'workspace\tw6\t└ testhost/primary · my-lane · p:AbCdEfGhIjKlMnOpQrStUv\n'
  printf 'tab\tw1:t1\tfm-good-lane\n'
} > "$CLEAN"
out=$(bash "$ROOT/bin/fm-surface-name-check.sh" --from-file "$CLEAN" 2>&1)
rc=$?
[ "$rc" -eq 0 ] || fail "a conforming snapshot must pass the check, got rc=$rc: $out"
printf '%s' "$out" | grep -q "OK" || fail "a clean snapshot must report OK"
pass "fm-surface-name-check.sh: a conforming snapshot passes"

SCOPE_MAP="$TMP_ROOT/scope-map.tsv"
printf 'w8\ttesthost/rogue\n' > "$SCOPE_MAP"
MAP_SNAPSHOT="$TMP_ROOT/map-snapshot.tsv"
printf 'workspace\tw8\tfirstmate\n' > "$MAP_SNAPSHOT"
out=$(bash "$ROOT/bin/fm-surface-name-check.sh" --from-file "$MAP_SNAPSHOT" --scope-map "$SCOPE_MAP" 2>&1)
rc=$?
[ "$rc" -eq 1 ] || fail "a legacy label with an invalid scope-map value must remain a violation"
printf '%s' "$out" | grep -q "testhost/rogue" && fail "an invalid scope-map value must not be used in a replacement"
pass "fm-surface-name-check.sh: scope-map values use the constrained scope grammar"

out=$(bash "$ROOT/bin/fm-surface-name-check.sh" --from-file /nonexistent/snapshot.tsv 2>&1)
rc=$?
[ "$rc" -eq 2 ] || fail "an unreadable snapshot must be a usage error, got rc=$rc"
pass "fm-surface-name-check.sh: an unreadable snapshot is a usage error"

pass "fm-surface-name: the visible surface-name grammar and its enforcement hold"
