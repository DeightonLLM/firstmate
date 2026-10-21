#!/usr/bin/env bash
# fm-quota-board-browser.test.sh - browser gate for the HD2 quota + token band.
#
# Renders the board in headless Chromium and asserts, against the rendered DOM:
#   * the band is present and carries all seven accounts as distinct tiles;
#   * the legend is present;
#   * NO console error was raised (the band keeps its own error sink in
#     #qb-console-errors, which must stay empty);
#   * hovering an account opens the previous-days panel;
#   * the panel does not overflow the viewport, on a wide and on a narrow screen;
#   * a board whose snapshot payload was removed degrades to an explicit
#     "not collected yet" state instead of showing zeros.
#
# Screenshots are written next to this test as evidence.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
BOARD="${FM_QUOTA_BOARD_HTML:-$REPO_ROOT/unified-board.html}"
EVIDENCE_DIR="${FM_QUOTA_BOARD_EVIDENCE:-$REPO_ROOT/data/hd2-takeover/evidence}"
CHROME="${CHROME_BIN:-/root/.cache/ms-playwright/chromium-1248/chrome-linux64/chrome}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/qm-board-gate.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

ok() { printf '  PASS %s\n' "$1"; PASS=$((PASS + 1)); }
no() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL + 1)); }

if [ ! -x "$CHROME" ]; then
  printf 'gate: SKIP no chromium binary at %s\n' "$CHROME"
  exit 0
fi
if [ ! -f "$BOARD" ]; then
  printf 'gate: FAIL board not found: %s\n' "$BOARD"
  exit 1
fi

mkdir -p "$EVIDENCE_DIR"

# ---------------------------------------------------------------- harness ----
# The harness is the board with ONE additive observer script appended. It
# touches no band code: it only scrolls to a tile, dispatches a hover, measures
# the panel and writes a machine-readable verdict into the DOM.
write_harness() {
  local target="$1" account="$2"
  python3 - "$BOARD" "$target" "$account" <<'PY'
import pathlib, sys
board, target, account = sys.argv[1], sys.argv[2], sys.argv[3]
html = pathlib.Path(board).read_text(encoding='utf-8')
harness = """
<script>
(function () {
  function ready(fn) { if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', fn); } else { fn(); } }
  ready(function () {
    setTimeout(function () {
      var out = { band: false, tiles: 0, accounts: [], legendItems: 0, consoleErrors: '',
                  popoverVisible: false, popoverHasDays: false, popoverOverflow: false,
                  emptyState: false, aggValue: '', popWidth: 0, popHeight: 0, dayRows: 0 };
      function finish() {
        var result = document.createElement('div');
        result.id = 'qb-gate-result';
        result.setAttribute('data-console-errors', out.consoleErrors === '' ? '0' : out.consoleErrors);
        result.setAttribute('data-tiles', out.tiles);
        result.setAttribute('data-accounts', out.accounts.join(','));
        result.setAttribute('data-legend-items', out.legendItems);
        result.setAttribute('data-popover-visible', out.popoverVisible ? 'true' : 'false');
        result.setAttribute('data-popover-has-days', out.popoverHasDays ? 'true' : 'false');
        result.setAttribute('data-popover-overflow', out.popoverOverflow ? 'true' : 'false');
        result.setAttribute('data-empty-state', out.emptyState ? 'true' : 'false');
        result.setAttribute('data-agg-value', out.aggValue);
        result.setAttribute('data-band', out.band ? 'true' : 'false');
        result.setAttribute('data-day-rows', out.dayRows);
        result.textContent = JSON.stringify(out);
        document.body.appendChild(result);
      }
      var target = null;
      try {
        out.band = !!document.getElementById('quota-band');
        var tiles = document.querySelectorAll('#qb-tiles .qb-tile');
        out.tiles = tiles.length;
        for (var i = 0; i < tiles.length; i += 1) { out.accounts.push(tiles[i].getAttribute('data-account')); }
        out.legendItems = document.querySelectorAll('#qb-legend .qb-legend-item').length;
        var sink = document.getElementById('qb-console-errors');
        out.consoleErrors = sink ? (sink.textContent || '').trim() : '';
        var agg = document.getElementById('qb-agg-value');
        out.aggValue = agg ? (agg.textContent || '').trim() : '';
        var empty = document.getElementById('qb-empty');
        out.emptyState = !!empty && empty.offsetParent !== null;
        for (var j = 0; j < tiles.length; j += 1) {
          if (tiles[j].getAttribute('data-account') === '__ACCOUNT__') { target = tiles[j]; }
        }
      } catch (err) {
        var failed = document.createElement('div');
        failed.id = 'qb-gate-result';
        failed.setAttribute('data-verdict', 'FAIL');
        failed.textContent = 'harness error: ' + err.message;
        document.body.appendChild(failed);
        return;
      }
      if (!target) { finish(); return; }
      /* Scroll to the tile in two steps, then hover in a later tick: a user
         scrolls to the tile before hovering it, and the panel must be placed
         against the tile's settled position. */
      window.scrollTo(0, 0);
      setTimeout(function () {
        var offset = target.getBoundingClientRect().top + window.pageYOffset;
        window.scrollTo(0, Math.max(0, Math.round(offset - 100)));
        setTimeout(function () {
          target.dispatchEvent(new MouseEvent('mouseenter'));
          target.dispatchEvent(new Event('focus'));
          var pop = document.getElementById('qb-pop');
          if (pop && !pop.hidden) {
            out.popoverVisible = true;
            out.popoverHasDays = (pop.textContent || '').indexOf('Previous days') >= 0;
            out.dayRows = pop.querySelectorAll('.qb-day').length;
            var rect = pop.getBoundingClientRect();
            out.popWidth = Math.round(rect.width);
            out.popHeight = Math.round(rect.height);
            out.popoverOverflow = rect.left < -1 || rect.top < -1
              || rect.right > window.innerWidth + 1 || rect.bottom > window.innerHeight + 1;
          }
          finish();
        }, 150);
      }, 150);
    }, 250);
  });
})();
</script>
"""
harness = harness.replace('__ACCOUNT__', account)
marker = '</body>'
if marker not in html:
    print('harness: FAIL board has no </body>', file=sys.stderr)
    raise SystemExit(2)
html = html.replace(marker, harness + marker, 1)
pathlib.Path(target).write_text(html, encoding='utf-8')
PY
}

render() {
  local page="$1" width="$2" height="$3"
  timeout 120 "$CHROME" --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
    --window-size="$width,$height" --virtual-time-budget=4000 --dump-dom "file://$page" 2>"$WORK/chrome.err"
}

screenshot() {
  local page="$1" out="$2" width="$3" height="$4"
  timeout 120 "$CHROME" --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
    --window-size="$width,$height" --virtual-time-budget=4000 \
    --screenshot="$out" "file://$page" >/dev/null 2>"$WORK/shot.err"
}

attr() {
  python3 - "$1" "$2" <<'PY'
import re, sys, pathlib
path, name = sys.argv[1], sys.argv[2]
try:
    html = pathlib.Path(path).read_text(encoding='utf-8', errors='replace')
except OSError:
    print('MISSING')
    raise SystemExit(0)
match = re.search(r'id="qb-gate-result"[^>]*>', html)
if not match:
    print('MISSING')
    raise SystemExit(0)
tag = match.group(0)
value = re.search(r'%s="([^"]*)"' % re.escape(name), tag)
print(value.group(1) if value else '')
PY
}

printf 'gate: board %s\n' "$BOARD"

# ------------------------------------------------------- case 1: wide ------
printf 'case: wide render (1600x1200)\n'
write_harness "$WORK/harness-wide.html" codex-home
render "$WORK/harness-wide.html" 1600 1200 > "$WORK/dom-wide.html"

DOM="$WORK/dom-wide.html"
[ -s "$DOM" ] && ok "chromium dumped a DOM" || no "chromium dumped a DOM"
[ "$(attr "$DOM" data-band)" = "true" ] && ok "the quota band is present" || no "the quota band is present"
[ "$(attr "$DOM" data-tiles)" = "7" ] && ok "seven account tiles rendered" || no "seven account tiles rendered (got $(attr "$DOM" data-tiles))"

ACCOUNTS="$(attr "$DOM" data-accounts)"
EXPECTED="agy-claude-gpt agy-gemini codex-home glm minimax-account-1 minimax-account-2 openai-codex"
SORTED="$(printf '%s' "$ACCOUNTS" | tr ',' ' ' | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')"
[ "$SORTED" = "$EXPECTED" ] && ok "all seven accounts are distinct" || no "all seven accounts are distinct (got $SORTED)"

LEGEND="$(attr "$DOM" data-legend-items)"
case "$LEGEND" in
  ''|*[!0-9]*) no "the legend is present" ;;
  *) [ "$LEGEND" -ge 8 ] && ok "the legend is present ($LEGEND items)" || no "the legend is present (got $LEGEND)" ;;
esac
[ "$(attr "$DOM" data-console-errors)" = "0" ] && ok "zero console errors" || no "zero console errors (got $(attr "$DOM" data-console-errors))"
[ "$(attr "$DOM" data-popover-visible)" = "true" ] && ok "hover opens the panel" || no "hover opens the panel"
[ "$(attr "$DOM" data-popover-has-days)" = "true" ] && ok "the panel shows the previous days" || no "the panel shows the previous days"
[ "$(attr "$DOM" data-day-rows)" -ge 2 ] 2>/dev/null && ok "the panel lists a per-day series" || no "the panel lists a per-day series"
[ "$(attr "$DOM" data-popover-overflow)" = "false" ] && ok "the panel does not overflow the viewport" || no "the panel does not overflow the viewport"

screenshot "$WORK/harness-wide.html" "$EVIDENCE_DIR/quota-band-hover-20261021.png" 1600 1200
[ -s "$EVIDENCE_DIR/quota-band-hover-20261021.png" ] && ok "hover screenshot saved" || no "hover screenshot saved"

# ------------------------------------------------------ case 2: narrow ----
printf 'case: narrow render (420x900)\n'
write_harness "$WORK/harness-narrow.html" codex-home
render "$WORK/harness-narrow.html" 420 900 > "$WORK/dom-narrow.html"
DOM_N="$WORK/dom-narrow.html"
[ "$(attr "$DOM_N" data-console-errors)" = "0" ] && ok "zero console errors on a narrow screen" || no "zero console errors on a narrow screen"
[ "$(attr "$DOM_N" data-popover-visible)" = "true" ] && ok "hover opens the panel on a narrow screen" || no "hover opens the panel on a narrow screen"
[ "$(attr "$DOM_N" data-popover-overflow)" = "false" ] && ok "the panel does not overflow a narrow viewport" || no "the panel does not overflow a narrow viewport"
screenshot "$WORK/harness-narrow.html" "$EVIDENCE_DIR/quota-band-hover-narrow-20261021.png" 420 900
[ -s "$EVIDENCE_DIR/quota-band-hover-narrow-20261021.png" ] && ok "narrow screenshot saved" || no "narrow screenshot saved"

# --------------------------------------------- case 3: no snapshot --------
printf 'case: missing snapshot degrades gracefully\n'
python3 - "$BOARD" "$WORK/harness-nosnap.html" <<'PY'
import pathlib, re, sys
board, target = sys.argv[1], sys.argv[2]
html = pathlib.Path(board).read_text(encoding='utf-8')
html = re.sub(r'(<script id="quota-board-snapshot" type="application/json">).*?(</script>)',
               r'\1\2', html, flags=re.S)
harness = """
<script>
setTimeout(function () {
  var result = document.createElement('div');
  result.id = 'qb-gate-result';
  var tiles = document.querySelectorAll('#qb-tiles .qb-tile');
  var empty = document.getElementById('qb-empty');
  var agg = document.getElementById('qb-agg-value');
  var sink = document.getElementById('qb-console-errors');
  var errs = sink && (sink.textContent || '').trim() ? (sink.textContent || '').trim() : '0';
  result.setAttribute('data-tiles', tiles.length);
  result.setAttribute('data-empty-state', empty && empty.offsetParent !== null ? 'true' : 'false');
  result.setAttribute('data-agg-value', agg ? (agg.textContent || '').trim() : '');
  result.setAttribute('data-console-errors', errs);
  result.setAttribute('data-unknown-not-zero', (agg && (agg.textContent || '').trim() === 'unknown') ? 'true' : 'false');
  result.textContent = 'no-snapshot case';
  document.body.appendChild(result);
}, 250);
</script>
"""
html = html.replace('</body>', harness + '</body>', 1)
pathlib.Path(target).write_text(html, encoding='utf-8')
PY
render "$WORK/harness-nosnap.html" 1600 1200 > "$WORK/dom-nosnap.html"
DOM_NS="$WORK/dom-nosnap.html"
[ "$(attr "$DOM_NS" data-console-errors)" = "0" ] && ok "no console error without a snapshot" || no "no console error without a snapshot"
[ "$(attr "$DOM_NS" data-empty-state)" = "true" ] && ok "the band shows a not-collected state" || no "the band shows a not-collected state"
[ "$(attr "$DOM_NS" data-unknown-not-zero)" = "true" ] && ok "the headline says unknown, not zero" || no "the headline says unknown, not zero"
screenshot "$WORK/harness-nosnap.html" "$EVIDENCE_DIR/quota-band-nosnapshot-20261021.png" 1600 1200

# -------------------------------------------------- case 4: plain shot ----
printf 'case: plain board screenshot\n'
screenshot "$BOARD" "$EVIDENCE_DIR/quota-band-20261021.png" 1600 1200
[ -s "$EVIDENCE_DIR/quota-band-20261021.png" ] && ok "board screenshot saved" || no "board screenshot saved"

printf 'gate: %s pass=%s fail=%s\n' "$([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL)" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
