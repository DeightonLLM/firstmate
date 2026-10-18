#!/usr/bin/env node
/**
 * Source-level RED/GREEN checks for Lighthouse-confirmed staging findings.
 *
 * Reads local staging theme/build sources only. No HTTP, database, container,
 * browser, production, form, CRM, or chatbot calls are made.
 * This test does not assert a WCAG claim or an indexable staging policy.
 */
import process from 'node:process';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = (rel) => readFileSync(path.join(ROOT, rel), 'utf8');
const failures = [];
const passes = [];
function check(id, ok, detail) {
  (ok ? passes : failures).push({ id, detail });
  process.stdout.write(`${ok ? 'PASS' : 'FAIL'} ${id}: ${detail}\n`);
}
function hasNestedInteractive(markup) {
  const stack = [];
  const tags = /<\/?([a-z][a-z0-9:-]*)\b[^>]*>/gi;
  let match;
  while ((match = tags.exec(markup))) {
    const token = match[0];
    const name = match[1].toLowerCase();
    if (token.startsWith('</')) {
      const index = stack.lastIndexOf(name);
      if (index >= 0) stack.length = index;
      continue;
    }
    if (name === 'button' && stack.includes('a')) return true;
    if (!/\/\s*>$/.test(token) && !['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'].includes(name)) stack.push(name);
  }
  return false;
}
function hasSkippedHeading(markup) {
  const levels = [...markup.matchAll(/<h([1-6])\b/gi)].map((m) => Number(m[1]));
  return levels.some((level, i) => i > 0 && level > levels[i - 1] + 1);
}
function unbalancedTags(markup) {
  const voids = new Set(['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr']);
  const counts = new Map();
  for (const match of markup.matchAll(/<\/?([a-z][a-z0-9:-]*)\b[^>]*>/gi)) {
    const token = match[0];
    const name = match[1].toLowerCase();
    if (voids.has(name) || /\/>$/.test(token)) continue;
    const count = counts.get(name) || { open: 0, close: 0 };
    if (token.startsWith('</')) count.close++;
    else count.open++;
    counts.set(name, count);
  }
  return [...counts].filter(([, count]) => count.open !== count.close).map(([tag]) => tag);
}

const homepage = read('theme/public-homepage-body.html');
const footer = read('theme/partials/cd-page-footer.php');
const functions = read('theme/functions.php');
const compat = read('theme/assets/stage-compat.css');

check(
  'HOME_METRIC_CONTRAST_SOURCE',
  !homepage.includes('color:oklch(0.60 0.04 148)'),
  'homepage metric labels no longer use the Lighthouse-failing green',
);
check(
  'HOME_FOOTER_HEADING_LEVEL',
  !/<h4\b/i.test(homepage.slice(homepage.lastIndexOf('<footer'))),
  'homepage footer headings do not skip from the page heading outline to h4',
);
check(
  'SHARED_FOOTER_HEADING_LEVEL',
  !/<h4\b/i.test(footer),
  'shared page footer uses sequential section headings',
);

for (const slug of ['products', 'about', 'compliance', 'contact', 'resources', 'blog', 'faq', 'glass-vials', 'rubber-stoppers', 'aluminum-seals', 'register']) {
  const rel = `build/pages/${slug}.html`;
  const markup = read(rel);
  check(`NO_NESTED_INTERACTIVE_${slug.toUpperCase()}`, !hasNestedInteractive(markup), `${rel} contains no <a><button> nesting`);
  check(`BALANCED_TAGS_${slug.toUpperCase()}`, unbalancedTags(markup).length === 0, `${rel} has matching non-void opening/closing tags`);
  if (['contact', 'blog', 'resources'].includes(slug)) {
    check(`HEADING_ORDER_${slug.toUpperCase()}`, !hasSkippedHeading(markup), `${rel} has no skipped heading level`);
  }
}

const products = read('build/pages/products.html');
check(
  'PRODUCTS_VIDEO_LOCAL_ASSETS',
  !products.includes('/automation-machine-video_93d11a5b.mp4') && !products.includes('poster="/images/automation-machine-v2.webp"'),
  'products content does not request the unavailable MP4 or root-relative poster',
);
check(
  'PRODUCTS_CARD_CONTRAST',
  /cd-route-products[\s\S]*\.cd-card[\s\S]*\.font-display[\s\S]*!important/.test(compat),
  'product card labels receive a light foreground on their dark surface',
);
const routeFixes = path.join(ROOT, 'theme', 'stage-content-fixes.php');
check(
  'RENDER_FIX_HELPER',
  existsSync(routeFixes) && /function\s+core_distro_stage_lighthouse_content_fixes\b/.test(existsSync(routeFixes) ? read('theme/stage-content-fixes.php') : ''),
  'a tested render-time helper exists for existing private staging page records',
);
check(
  'RENDER_FIX_HOOK',
  /core_distro_stage_lighthouse_content_fixes/.test(functions),
  'the private staging theme applies the content fixes without writing page records',
);
check(
  'ASTRA_SCROLL_FLAG',
  /astra_theme_js_localize/.test(functions) && /is_scroll_to_top/.test(read('theme/stage-content-fixes.php')),
  'Astra scroll-to-top localization is disabled where its markup is intentionally absent',
);
check(
  'ROUTE_CONTRAST_OVERRIDES',
  /cd-route-products[\s\S]*cd-card[\s\S]*!important/.test(compat)
    && /cd-route-blog/.test(compat)
    && /cd-route-register/.test(compat)
    && /cd-route-contact/.test(compat),
  'contrast fixes are scoped to the affected staging routes',
);

process.stdout.write(`\nSUMMARY passed=${passes.length} failed=${failures.length}\n`);
process.exitCode = failures.length ? 1 : 0;
