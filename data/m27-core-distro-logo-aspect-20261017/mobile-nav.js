const { chromium } = require('/opt/deepseek-harness/benchmarks/node_modules/playwright');
const OUT = '/home/hd2admin/kun-agent-workspace/data/m27-core-distro-logo-aspect-20261017';

async function main() {
  const browser = await chromium.launch({
    headless: true,
    executablePath: '/usr/bin/google-chrome',
    args: ['--no-sentinel', '--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
  });
  const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await ctx.newPage();
  await page.goto('https://staging.core-distro.com', { waitUntil: 'networkidle', timeout: 30000 });

  // Find all mobile navigation elements
  const mobileNavInfo = await page.evaluate(() => {
    const results = [];
    // Find any visible nav/header elements
    document.querySelectorAll('header, nav, [class*="header"], [class*="navbar"], [class*="nav"]').forEach(el => {
      const rect = el.getBoundingClientRect();
      const style = getComputedStyle(el);
      if (style.display !== 'none' && rect.width > 0) {
        const imgs = el.querySelectorAll('img');
        imgs.forEach(img => {
          const r = img.getBoundingClientRect();
          const s = getComputedStyle(img);
          results.push({
            container: `${el.tagName}.${el.className}`,
            containerDisplay: style.display,
            containerRect: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
            imgSrc: img.currentSrc || img.src,
            imgClass: img.className,
            imgNatural: `${img.naturalWidth}x${img.naturalHeight}`,
            imgRendered: `${Math.round(r.width)}x${Math.round(r.height)}`,
            imgCSS: {
              width: s.width, height: s.height,
              objectFit: s.objectFit, aspectRatio: s.aspectRatio,
            }
          });
        });
      }
    });
    return results;
  });

  console.log('=== VISIBLE NAV WITH IMAGES (MOBILE) ===');
  console.log(JSON.stringify(mobileNavInfo, null, 2));

  // Check for mobile menu overlay - look for elements that appear on mobile nav open
  // The hamburger menu icon is present; let's click it and check the overlay
  const menuBtn = await page.$('svg.lucide-menu, button[class*="menu"], [class*="hamburger"]');
  if (menuBtn) {
    console.log('\nFound menu button, clicking...');
    await menuBtn.click();
    await page.waitForTimeout(1000);

    // Check what's visible after opening mobile menu
    const mobileMenuContent = await page.evaluate(() => {
      const results = [];
      document.querySelectorAll('[class*="menu"], [class*="drawer"], [class*="overlay"], [class*="mobile-nav"], [role="dialog"]').forEach(el => {
        const rect = el.getBoundingClientRect();
        const style = getComputedStyle(el);
        if (style.display !== 'none' && rect.width > 0 && rect.height > 0) {
          results.push({
            tag: el.tagName,
            className: el.className,
            display: style.display,
            rect: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
            imgs: Array.from(el.querySelectorAll('img')).map(img => ({
              src: img.currentSrc || img.src,
              className: img.className,
              natural: `${img.naturalWidth}x${img.naturalHeight}`,
              rendered: `${Math.round(img.getBoundingClientRect().width)}x${Math.round(img.getBoundingClientRect().height)}`,
              computed: {
                width: getComputedStyle(img).width,
                height: getComputedStyle(img).height,
                objectFit: getComputedStyle(img).objectFit,
              }
            }))
          });
        }
      });
      return results;
    });
    console.log('\n=== MOBILE MENU OPENED - CONTENT ===');
    console.log(JSON.stringify(mobileMenuContent, null, 2));
  } else {
    console.log('\nNo hamburger button found, trying alternative selectors...');
    // Try clicking the header
    const headerClick = await page.evaluate(() => {
      // Look for the mobile header nav
      const header = document.querySelector('header');
      if (header) {
        const imgs = header.querySelectorAll('img');
        return Array.from(imgs).map(img => ({
          src: img.currentSrc || img.src,
          natural: `${img.naturalWidth}x${img.naturalHeight}`,
          rendered: `${Math.round(img.getBoundingClientRect().width)}x${Math.round(img.getBoundingClientRect().height)}`,
          computed: {
            width: getComputedStyle(img).width,
            height: getComputedStyle(img).height,
            objectFit: getComputedStyle(img).objectFit,
          }
        }));
      }
      return [];
    });
    console.log('Header imgs:', JSON.stringify(headerClick, null, 2));
  }

  // Screenshot of mobile menu
  await page.screenshot({ path: `${OUT}/screenshot-mobile-menu-open.png`, fullPage: false });
  console.log('Mobile menu screenshot saved');

  await browser.close();
}

main().catch(err => {
  console.error('ERROR:', err.message);
  process.exit(1);
});
