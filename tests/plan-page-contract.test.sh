#!/usr/bin/env bash
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PLAN_HTML="$ROOT/data/hetz-plan/plan.html"
STATE_SH="$ROOT/data/hetz-plan/state.sh"
ITEMS_JSON="$ROOT/data/hetz-plan/items.json"
SKILL_MD="$ROOT/.agents/skills/plan-page/SKILL.md"

# Test 1: items.json items must have explicit boolean 'completed' field
test_items_completed_field() {
  local count_missing
  count_missing=$(python3 -c "
import json
items = json.load(open('$ITEMS_JSON'))
missing = [it for it in items if not isinstance(it.get('completed'), bool)]
print(len(missing))
")
  if [ "$count_missing" -eq 0 ]; then
    pass "all items have explicit boolean completed field"
  else
    fail "items missing explicit boolean completed field: $count_missing"
  fi
}

# Test 2: plan.html must render checkboxes for items and calculate pct from the same truth
test_plan_html_checkboxes() {
  local has_checkboxes has_skill_reminder
  has_checkboxes=$(python3 -c "
with open('$PLAN_HTML') as f:
    html = f.read()
print(1 if 'checkbox' in html.lower() and ('item-check' in html or 'data-item-id' in html or 'type=\"checkbox\"' in html or 'type=\'checkbox\'' in html) else 0)
")
  if [ "$has_checkboxes" -eq 1 ]; then
    pass "plan.html contains item checkboxes"
  else
    fail "plan.html missing item checkboxes"
  fi

  has_skill_reminder=$(python3 -c "
with open('$PLAN_HTML') as f:
    html = f.read()
print(1 if 'plan-page' in html and 'standing reminder' in html.lower() else 0)
")
  if [ "$has_skill_reminder" -eq 1 ]; then
    pass "plan.html contains standing reminder block at bottom"
  else
    fail "plan.html missing standing reminder block"
  fi
}

# Test 3: state.sh must derive done and pct from completed items,
# and plan.html must not contain hardcoded completion count or percentage.
test_state_sh_derivation() {
  local derives_done
  derives_done=$(python3 -c "
with open('$STATE_SH') as f:
    src = f.read()
print(1 if 'completed' in src and 'done=0' not in src else 0)
")
  if [ "$derives_done" -ne 1 ]; then
    fail "state.sh does not derive done/pct from item completed state"
    return
  fi

  local no_hardcoded
  no_hardcoded=$(python3 - "$PLAN_HTML" <<'PY'
import sys, re
with open(sys.argv[1]) as f:
    html = f.read()

has_data_pct = bool(re.search(r'data-pct\s*=\s*["\']\s*\d+', html))
has_hardcoded_pct = bool(re.search(r'id=["\'](?:g|p)pct["\'][^>]*>\s*\d+(?:\.\d+)?%', html))
has_hardcoded_pnum = bool(re.search(r'id=["\']pnum["\'][^>]*>\s*\d+%', html))
has_hardcoded_done = bool(re.search(r'id=["\']pdone["\'][^>]*>\s*\d+\s*/\s*\d+', html))

if has_data_pct or has_hardcoded_pct or has_hardcoded_pnum or has_hardcoded_done:
    print(0)
else:
    print(1)
PY
)
  if [ "$no_hardcoded" -eq 1 ]; then
    pass "state.sh derives done/pct and plan.html contains no hardcoded completion count or pct"
  else
    fail "plan.html contains hardcoded completion count or percentage"
  fi
}

# Test 4: Stale state detection in JS / HTML:
# A stale state.json must produce a visible stale state, not a confident-looking percentage.
test_stale_state_detection() {
  local has_stale_detection
  has_stale_detection=$(python3 -c "
with open('$PLAN_HTML') as f:
    html = f.read()
import re
has_gen_age = bool(re.search(r'Date\.parse\s*\(\s*s\.generated|new\s+Date\s*\(\s*s\.generated|\.generated.*Date\.now', html))
has_stale_flag = bool(re.search(r'stale.*snapshot|data is old|state stale|state\.json.*stale|s\.pct.*stale', html, re.I))
print(1 if (has_gen_age and has_stale_flag) else 0)
")
  if [ "$has_stale_detection" -eq 1 ]; then
    pass "plan.html detects state.json age and visibly flags stale state"
  else
    fail "plan.html does not evaluate state.json age or flag stale data"
  fi
}

# Test 5: The plan-page skill exists with required metadata and sections
test_skill_doc() {
  if [ ! -f "$SKILL_MD" ]; then
    fail "skill file $SKILL_MD does not exist"
    return
  fi
  local has_meta has_sections
  has_meta=$(python3 -c "
with open('$SKILL_MD') as f:
    txt = f.read()
print(1 if 'metadata.internal=true' in txt or 'internal: true' in txt else 0)
")
  if [ "$has_meta" -eq 1 ]; then
    pass "plan-page skill has internal metadata"
  else
    fail "plan-page skill missing internal metadata"
  fi

  has_sections=$(python3 -c "
with open('$SKILL_MD') as f:
    txt = f.read().lower()
reqs = ['routing law', 'run mechanics', 'tracks', 'reviewer', 'quota discipline', 'captain', 'window boundary', 'live status pill', 'completed checkboxes', 'durable refresh', 'stale']
missing = [r for r in reqs if r not in txt]
if missing:
    print('missing: ' + ', '.join(missing))
else:
    print('ok')
")
  if [ "$has_sections" = "ok" ]; then
    pass "plan-page skill contains all required sections"
  else
    fail "plan-page skill missing sections: $has_sections"
  fi
}

# Test 6: Durable refresher:
# Verify that state.sh refresh can execute cleanly and output valid complete schema
test_durable_refresh() {
  local tmp_state
  tmp_state=$(bash "$STATE_SH" 2>/dev/null)
  local valid_json
  valid_json=$(python3 -c "
import json, sys
try:
    d = json.loads('''$tmp_state''')
    print(1 if 'pct' in d and 'items' in d and 'generated' in d and 'done' in d else 0)
except Exception:
    print(0)
")
  if [ "$valid_json" -eq 1 ]; then
    pass "state.sh executes cleanly and outputs valid complete schema"
  else
    fail "state.sh execution failed or emitted invalid schema"
  fi
}

# Test 7: A host-owned trigger must exist outside any agent session.
# Assert that something OUTSIDE any agent session owns the refresh: a crontab
# entry or a systemd timer (including .timer + its .service) that invokes
# data/hetz-plan/state.sh.
test_host_trigger() {
  local has_trigger
  has_trigger=$(python3 -c "
import subprocess, os, glob

target = 'data/hetz-plan/state.sh'
found = False

# 1. Check crontab
try:
    cron_out = subprocess.check_output(['crontab', '-l'], stderr=subprocess.DEVNULL, text=True)
    for line in cron_out.splitlines():
        line = line.strip()
        if line and not line.startswith('#') and target in line:
            found = True
            break
except Exception:
    pass

# 2. Check /etc/cron*
if not found:
    cron_paths = ['/etc/crontab'] + glob.glob('/etc/cron.*/*') + glob.glob('/etc/cron.d/*')
    for cp in cron_paths:
        if os.path.isfile(cp):
            try:
                with open(cp, errors='ignore') as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith('#') and target in line:
                            found = True
                            break
            except Exception:
                pass
        if found:
            break

# 3. Check systemd timers and services
if not found:
    try:
        timer_out = subprocess.check_output(['systemctl', 'list-timers', '--all', '--no-legend'], stderr=subprocess.DEVNULL, text=True)
        if target in timer_out:
            found = True
    except Exception:
        pass

if not found:
    unit_paths = glob.glob('/etc/systemd/system/*.service') + glob.glob('/etc/systemd/system/*.timer') + glob.glob('/lib/systemd/system/*.timer')
    for up in unit_paths:
        if os.path.isfile(up):
            try:
                with open(up, errors='ignore') as f:
                    content = f.read()
                    if target in content:
                        found = True
                        break
            except Exception:
                pass

print(1 if found else 0)
")

  if [ "$has_trigger" -eq 1 ]; then
    pass "host-owned trigger exists outside agent sessions"
  else
    fail "no host-owned trigger (crontab or systemd timer) found invoking data/hetz-plan/state.sh"
  fi
}

# Test 8: Atomic write for state.json
# Assert data/hetz-plan/state.sh (or whatever produces it) writes state.json
# via write-to-temp-then-mv in the SAME directory, so a reader never sees a
# half-written file. Grep for the temp+rename idiom. A plain '> state.json'
# redirect with no temp file must FAIL.
test_atomic_write() {
  local is_atomic
  is_atomic=$(python3 - "$STATE_SH" <<'PY'
import sys, re

with open(sys.argv[1]) as f:
    src = f.read()

writes_state = 'state.json' in src
plain_redirect = bool(re.search(r'>\s*["\']?(?:\$D/)?state\.json["\']?\s*(?:$|\n|\||;)', src))
has_temp = bool(re.search(r'state\.json\.tmp|\.tmp|\$D/.*tmp', src, re.I))
has_mv = bool(re.search(r'mv\s+(?:-[a-zA-Z]+\s+)*["\']?[^"\n\';]*tmp[^"\n\';]*["\']?\s+["\']?(?:\$D/)?(?:state\.json|\$TARGET)["\']?', src, re.I))

valid = writes_state and has_temp and has_mv and (not plain_redirect)
print(1 if valid else 0)
PY
)

  if [ "$is_atomic" -eq 1 ]; then
    pass "state.sh writes state.json via write-to-temp-then-mv in same directory"
  else
    fail "state.sh does not write state.json atomically (missing temp+mv idiom or plain redirect)"
  fi
}

case "${1:-all}" in
  1|items) test_items_completed_field ;;
  2|html) test_plan_html_checkboxes ;;
  3|statesh) test_state_sh_derivation ;;
  4|stale) test_stale_state_detection ;;
  5|skill) test_skill_doc ;;
  6|durable) test_durable_refresh ;;
  7|trigger) test_host_trigger ;;
  8|atomic) test_atomic_write ;;
  all)
    test_items_completed_field
    test_plan_html_checkboxes
    test_state_sh_derivation
    test_stale_state_detection
    test_skill_doc
    test_durable_refresh
    test_host_trigger
    test_atomic_write
    ;;
  *) echo "Unknown test: $1" >&2; exit 2 ;;
esac
