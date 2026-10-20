const { chromium } = require('/opt/deepseek-harness/benchmarks/node_modules/playwright');
const path = require('path');
const fs = require('fs');

const OUT = '/home/hd2admin/kun-agent-workspace/data/m27-core-distro-logo-aspect-20261017';

async function main() {
  const browser = await chromium.launch({
    headless: true,
    executablePath: '/usr/bin/google-chrome',
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
  });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();

  const consoleErrors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });
  page.on('pageerror', err => consoleErrors.push('PAGEERROR: ' + err.message));

  console.log('=== NAVIGATING TO STAGING ===');
  try {
    await page.goto('https://staging.core-distro.com', { waitUntil: 'networkidle', timeout: 30000 });
  } catch(e) {
    console.log('Navigation error (try with domcontentloaded):', e.message);
    await page.goto('https://staging.core-distro.com', { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(3000);
  }
  console.log('Title:', await page.title());
  const url = page.url();
  console.log('Final URL:', url);

  // ─── STEP 1: All img elements on page ────────────────────────────────────
  const allImgs = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('img')).map(img => {
      const rect = img.getBoundingClientRect();
      const style = getComputedStyle(img);
      return {
        src: img.currentSrc || img.src,
        alt: img.alt,
        className: img.className,
        id: img.id,
        naturalWidth: img.naturalWidth,
        naturalHeight: img.naturalHeight,
        renderedW: Math.round(rect.width),
        renderedH: Math.round(rect.height),
        computedWidth: style.width,
        computedHeight: style.height,
        maxWidth: style.maxWidth,
        maxHeight: style.maxHeight,
        objectFit: style.objectFit,
        objectPosition: style.objectPosition,
        aspectRatio: style.aspectRatio,
        position: style.position,
        parent: img.parentElement ? (img.parentElement.tagName + (img.parentElement.id ? '#'+img.parentElement.id : '') + '.' + img.parentElement.className.split(' ').join('.')) : '',
        isVisible: rect.width > 0 && rect.height > 0,
      };
    });
  });

  console.log('\n=== ALL IMAGES ON PAGE ===');
  allImgs.forEach((img, i) => {
    console.log(`\n[${i}] src: ${img.src}`);
    console.log(`    alt: "${img.alt}"  class: "${img.className}"  id: "${img.id}"`);
    console.log(`    naturalSize: ${img.naturalWidth}x${img.naturalHeight}`);
    console.log(`    renderedBox: ${img.renderedW}x${img.renderedH}  visible: ${img.isVisible}`);
    console.log(`    CSS: width=${img.computedWidth}  height=${img.computedHeight}`);
    console.log(`    maxWidth=${img.maxWidth}  maxHeight=${img.maxHeight}`);
    console.log(`    object-fit=${img.objectFit}  object-position=${img.objectPosition}`);
    console.log(`    aspect-ratio=${img.aspectRatio}`);
    console.log(`    parent: ${img.parent}`);
  });

  // ─── STEP 2: Logo-specific elements ─────────────────────────────────────
  const logoImgs = allImgs.filter(img => {
    const s = img.src.toLowerCase();
    const c = img.className.toLowerCase();
    const a = (img.alt || '').toLowerCase();
    return s.includes('logo') || c.includes('logo') || a.includes('logo');
  });

  console.log('\n=== LOGO IMAGES ===');
  console.log(JSON.stringify(logoImgs, null, 2));

  // ─── STEP 3: SVG logos ───────────────────────────────────────────────────
  const svgLogos = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('svg')).map(svg => {
      const rect = svg.getBoundingClientRect();
      const style = getComputedStyle(svg);
      const parent = svg.closest('nav,header,footer,[class*="logo"],[id*="logo"]');
      return {
        outerHTML: svg.outerHTML.substring(0, 300),
        className: svg.className,
        id: svg.id,
        renderedW: Math.round(rect.width),
        renderedH: Math.round(rect.height),
        visible: rect.width > 0 && rect.height > 0,
        computedWidth: style.width,
        computedHeight: style.height,
        parent: parent ? parent.tagName + '.' + parent.className : '',
      };
    }).filter(s => s.visible);
  });
  console.log('\n=== SVG ELEMENTS (visible) ===');
  console.log(JSON.stringify(svgLogos, null, 2));

  // ─── STEP 4: Full CSS cascade for logo imgs ──────────────────────────────
  const logoCSS = await page.evaluate(() => {
    const results = [];
    document.querySelectorAll('img').forEach(img => {
      const src = img.currentSrc || img.src;
      if (src.toLowerCase().includes('logo')) {
        const style = getComputedStyle(img);
        const rect = img.getBoundingClientRect();
        results.push({
          _logo: true,
          src,
          alt: img.alt,
          naturalSize: `${img.naturalWidth}x${img.naturalHeight}`,
          rendered: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
          CSS: {
            width: style.width,
            height: style.height,
            maxWidth: style.maxWidth,
            maxHeight: style.maxHeight,
            minWidth: style.minWidth,
            minHeight: style.minHeight,
            objectFit: style.objectFit,
            objectPosition: style.objectPosition,
            aspectRatio: style.aspectRatio,
            display: style.display,
            position: style.position,
            top: style.top,
            left: style.left,
          }
        });
        let el = img.parentElement;
        let depth = 1;
        while (el && depth <= 5) {
          const s = getComputedStyle(el);
          results.push({
            _depth: depth,
            tag: el.tagName,
            id: el.id,
            className: el.className,
            CSS: {
              width: s.width,
              height: s.height,
              maxWidth: s.maxWidth,
              maxHeight: s.maxHeight,
              objectFit: s.objectFit,
              aspectRatio: s.aspectRatio,
              display: s.display,
              position: s.position,
            }
          });
          el = el.parentElement;
          depth++;
        }
      }
    });
    return results;
  });
  console.log('\n=== FULL CSS CASCADE FOR LOGOS ===');
  console.log(JSON.stringify(logoCSS, null, 2));

  // ─── STEP 5: Meta / social preview images ────────────────────────────────
  const metaImgs = await page.evaluate(() => {
    const results = [];
    const selectors = [
      'meta[property="og:image"]',
      'meta[property="og:logo"]',
      'meta[name="twitter:image"]',
      'meta[name="twitter:card"]',
      'link[rel="icon"]',
      'link[rel="shortcut icon"]',
      'link[rel="apple-touch-icon"]',
      'meta[name="msapplication-TileImage"]',
    ];
    selectors.forEach(sel => {
      const el = document.querySelector(sel);
      if (el) results.push({ sel, content: el.content || el.href || '' });
    });
    return results;
  });
  console.log('\n=== META / OG IMAGES ===');
  metaImgs.forEach(m => console.log(`  ${m.sel}: ${m.content}`));

  // ─── STEP 6: Screenshot 1440x900 ────────────────────────────────────────
  await page.screenshot({ path: `${OUT}/screenshot-1440x900.png`, fullPage: false });
  console.log('\nScreenshot 1440x900 saved to', `${OUT}/screenshot-1440x900.png`);

  // ─── STEP 7: Mobile viewport ─────────────────────────────────────────────
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(2000);

  const mobileImgs = await page.evaluate(() => {
    return Array.from(document.querySelectorAll('img')).map(img => {
      const rect = img.getBoundingClientRect();
      const style = getComputedStyle(img);
      return {
        src: img.currentSrc || img.src,
        alt: img.alt,
        className: img.className,
        naturalWidth: img.naturalWidth,
        naturalHeight: img.naturalHeight,
        renderedW: Math.round(rect.width),
        renderedH: Math.round(rect.height),
        visible: rect.width > 0 && rect.height > 0,
        computedWidth: style.width,
        computedHeight: style.computedHeight,
        objectFit: style.objectFit,
        isLogo: (img.currentSrc || img.src).toLowerCase().includes('logo') ||
                img.className.toLowerCase().includes('logo') ||
                (img.alt || '').toLowerCase().includes('logo'),
      };
    }).filter(img => img.visible && (
      (img.currentSrc || img.src).toLowerCase().includes('logo') ||
      img.className.toLowerCase().includes('logo')
    ));
  });

  console.log('\n=== MOBILE LOGOS (390x844) ===');
  mobileImgs.forEach(img => {
    console.log(`  src: ${img.src}`);
    console.log(`  naturalSize: ${img.naturalWidth}x${img.naturalHeight}`);
    console.log(`  renderedBox: ${img.renderedW}x${img.renderedH}`);
    console.log(`  CSS: ${img.computedWidth} x ${img.computedHeight}`);
    console.log(`  object-fit: ${img.objectFit}`);
  });

  await page.screenshot({ path: `${OUT}/screenshot-390x844.png`, fullPage: false });
  console.log('Screenshot 390x844 saved to', `${OUT}/screenshot-390x844.png`);

  // ─── STEP 8: Navbar specific inspection ──────────────────────────────────
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.waitForTimeout(1000);

  const navbarLogo = await page.evaluate(() => {
    const results = [];
    // Find elements with "logo" in nav/header
    document.querySelectorAll('nav img, header img, [class*="nav"] img, [class*="header"] img').forEach(img => {
      const src = img.currentSrc || img.src;
      if (src.toLowerCase().includes('logo')) {
        const rect = img.getBoundingClientRect();
        const style = getComputedStyle(img);
        const parentRect = img.parentElement ? img.parentElement.getBoundingClientRect() : null;
        results.push({
          src,
          naturalSize: `${img.naturalWidth}x${img.naturalHeight}`,
          rendered: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
          CSS: { width: style.width, height: style.height, maxWidth: style.maxWidth, maxHeight: style.maxHeight, objectFit: style.objectFit, aspectRatio: style.aspectRatio },
          parentTag: img.parentElement.tagName,
          parentClass: img.parentElement.className,
          parentStyle: { width: getComputedStyle(img.parentElement).width, height: getComputedStyle(img.parentElement).height, display: getComputedStyle(img.parentElement).display },
          parentRendered: parentRect ? `${Math.round(parentRect.width)}x${Math.round(parentRect.height)}` : null,
        });
      }
    });
    return results;
  });
  console.log('\n=== NAVBAR LOGO INSPECTION ===');
  console.log(JSON.stringify(navbarLogo, null, 2));

  // Footer logo
  const footerLogo = await page.evaluate(() => {
    const results = [];
    document.querySelectorAll('footer img').forEach(img => {
      const src = img.currentSrc || img.src;
      if (src.toLowerCase().includes('logo')) {
        const rect = img.getBoundingClientRect();
        const style = getComputedStyle(img);
        results.push({
          src,
          naturalSize: `${img.naturalWidth}x${img.naturalHeight}`,
          rendered: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
          CSS: { width: style.width, height: style.height, maxWidth: style.maxWidth, maxHeight: style.maxHeight, objectFit: style.objectFit, aspectRatio: style.aspectRatio },
        });
      }
    });
    return results;
  });
  console.log('\n=== FOOTER LOGO INSPECTION ===');
  console.log(JSON.stringify(footerLogo, null, 2));

  // ─── Console errors ───────────────────────────────────────────────────────
  console.log('\n=== CONSOLE ERRORS ===');
  if (consoleErrors.length === 0) {
    console.log('None');
  } else {
    consoleErrors.forEach(e => console.log('ERROR:', e));
  }

  await browser.close();
  console.log('\n=== DONE ===');
}

main().catch(err => {
  console.error('SCRIPT ERROR:', err.message);
  console.error(err.stack);
  process.exit(1);
});
