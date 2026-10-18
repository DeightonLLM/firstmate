const { chromium } = require('/opt/deepseek-harness/benchmarks/node_modules/playwright');
const OUT = '/home/hd2admin/kun-agent-workspace/data/m27-core-distro-logo-aspect-20261017';

async function main() {
  const browser = await chromium.launch({
    headless: true,
    executablePath: '/usr/bin/google-chrome',
    args: ['--no-sentinel', '--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
  });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  await page.goto('https://staging.core-distro.com', { waitUntil: 'networkidle', timeout: 30000 });

  // Deep inspection: get full CSS computed styles and computed box for each logo instance
  const deep = await page.evaluate(() => {
    const results = [];
    document.querySelectorAll('img').forEach((img, idx) => {
      const src = img.currentSrc || img.src;
      if (src.includes('logo') || src.includes('core-distro-mark')) {
        const rect = img.getBoundingClientRect();
        const style = getComputedStyle(img);
        results.push({
          index: idx,
          src,
          alt: img.alt,
          className: img.className,
          naturalSize: `${img.naturalWidth}x${img.naturalHeight}`,
          naturalAspect: (img.naturalWidth / img.naturalHeight).toFixed(3),
          renderedBox: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
          offsetTop: Math.round(rect.top),
          offsetLeft: Math.round(rect.left),
          computedStyles: {
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
            flexShrink: style.flexShrink,
            flexGrow: style.flexGrow,
            paddingTop: style.paddingTop,
            paddingBottom: style.paddingBottom,
            paddingLeft: style.paddingLeft,
            paddingRight: style.paddingRight,
            marginTop: style.marginTop,
            marginBottom: style.marginBottom,
            borderTopWidth: style.borderTopWidth,
            borderBottomWidth: style.borderBottomWidth,
          },
          parentTag: img.parentElement.tagName,
          parentClass: img.parentElement.className,
          parentStyle: (() => {
            const s = getComputedStyle(img.parentElement);
            return {
              width: s.width, height: s.height,
              display: s.display, flexDirection: s.flexDirection,
              alignItems: s.alignItems, justifyContent: s.justifyContent,
              gap: s.gap, padding: s.padding,
            };
          })(),
          // Walk up 3 levels
          ancestors: (() => {
            const ancs = [];
            let el = img.parentElement?.parentElement;
            for (let d = 1; d <= 3 && el; d++) {
              const s = getComputedStyle(el);
              ancs.push({
                tag: el.tagName,
                className: el.className,
                id: el.id,
                width: s.width, height: s.height,
                display: s.display,
              });
              el = el.parentElement;
            }
            return ancs;
          })(),
        });
      }
    });
    return results;
  });

  console.log('=== DEEP LOGO INSPECTION (1440x900) ===');
  deep.forEach((d, i) => {
    console.log(`\n--- Logo Instance ${i} ---`);
    console.log(`  src: ${d.src}`);
    console.log(`  alt: "${d.alt}"`);
    console.log(`  className: "${d.className}"`);
    console.log(`  Natural size: ${d.naturalSize}  aspect ratio: ${d.naturalAspect}:1`);
    console.log(`  Rendered box: ${d.renderedBox}  position: top=${d.offsetTop} left=${d.offsetLeft}`);
    console.log(`  Computed CSS:`);
    Object.entries(d.computedStyles).forEach(([k, v]) => {
      if (v && v !== 'auto' && v !== 'normal' && v !== 'none') console.log(`    ${k}: ${v}`);
    });
    console.log(`  Parent (${d.parentTag}): class="${d.parentClass}"`);
    console.log(`  Parent styles:`, d.parentStyle);
    console.log(`  Ancestors:`, d.ancestors);
  });

  // Mobile: deep inspect
  await page.setViewportSize({ width: 390, height: 844 });
  await page.waitForTimeout(1500);

  const mobileDeep = await page.evaluate(() => {
    const results = [];
    document.querySelectorAll('img').forEach((img, idx) => {
      const src = img.currentSrc || img.src;
      if (src.includes('logo') || src.includes('core-distro-mark')) {
        const rect = img.getBoundingClientRect();
        const style = getComputedStyle(img);
        results.push({
          index: idx,
          src,
          className: img.className,
          naturalSize: `${img.naturalWidth}x${img.naturalHeight}`,
          renderedBox: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
          computedStyles: {
            width: style.width, height: style.height,
            maxWidth: style.maxWidth, maxHeight: style.maxHeight,
            objectFit: style.objectFit, objectPosition: style.objectPosition,
            aspectRatio: style.aspectRatio, flexShrink: style.flexShrink,
          },
          parentTag: img.parentElement.tagName,
          parentClass: img.parentElement.className,
          parentStyle: (() => {
            const s = getComputedStyle(img.parentElement);
            return { width: s.width, height: s.height, display: s.display, flexDirection: s.flexDirection };
          })(),
        });
      }
    });
    return results;
  });

  console.log('\n=== MOBILE DEEP INSPECTION (390x844) ===');
  mobileDeep.forEach((d, i) => {
    console.log(`\n--- Mobile Logo Instance ${i} ---`);
    console.log(`  src: ${d.src}`);
    console.log(`  className: "${d.className}"`);
    console.log(`  Natural size: ${d.naturalSize}`);
    console.log(`  Rendered box: ${d.renderedBox}`);
    Object.entries(d.computedStyles).forEach(([k, v]) => {
      if (v && v !== 'auto' && v !== 'normal' && v !== 'none') console.log(`  ${k}: ${v}`);
    });
    console.log(`  Parent: ${d.parentTag} "${d.parentClass}"`);
    console.log(`  Parent styles:`, d.parentStyle);
  });

  // Check if there's a mobile hamburger menu with a different logo
  const mobileMenu = await page.evaluate(() => {
    const results = [];
    // Check for hamburger/open mobile menu
    document.querySelectorAll('[class*="menu"], [class*="drawer"], [class*="sidebar"], [class*="mobile"]').forEach(el => {
      const style = getComputedStyle(el);
      const rect = el.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0 && style.display !== 'none') {
        const imgs = el.querySelectorAll('img');
        imgs.forEach(img => {
          const r = img.getBoundingClientRect();
          results.push({
            container: `${el.tagName}.${el.className}`,
            display: style.display,
            containerSize: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
            imgSrc: img.currentSrc || img.src,
            imgClass: img.className,
            imgNatural: `${img.naturalWidth}x${img.naturalHeight}`,
            imgRendered: `${Math.round(r.width)}x${Math.round(r.height)}`,
            imgObjectFit: getComputedStyle(img).objectFit,
            imgWidth: getComputedStyle(img).width,
            imgHeight: getComputedStyle(img).height,
          });
        });
      }
    });
    return results;
  });
  console.log('\n=== MOBILE MENU CONTAINERS WITH IMAGES ===');
  mobileMenu.forEach(m => console.log(JSON.stringify(m, null, 2)));

  // Check for any mobile nav overlay/modal
  const mobileNav = await page.evaluate(() => {
    const navs = document.querySelectorAll('nav, [role="navigation"], [class*="nav"]');
    return Array.from(navs).map(nav => {
      const rect = nav.getBoundingClientRect();
      const style = getComputedStyle(nav);
      return {
        tag: nav.tagName,
        className: nav.className,
        display: style.display,
        rect: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
        hasLogo: !!nav.querySelector('img[src*="logo"], img[src*="core-distro"]'),
      };
    });
  });
  console.log('\n=== ALL NAVS ON MOBILE ===');
  console.log(JSON.stringify(mobileNav, null, 2));

  await browser.close();
  console.log('\n=== DONE ===');
}

main().catch(err => {
  console.error('ERROR:', err.message);
  process.exit(1);
});
