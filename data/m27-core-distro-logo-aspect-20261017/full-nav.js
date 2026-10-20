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

  // Get all button elements
  const buttons = await page.$$('button');
  console.log(`Found ${buttons.length} buttons`);
  for (const btn of buttons) {
    const cls = await btn.getAttribute('class');
    const aria = await btn.getAttribute('aria-expanded');
    console.log(`  button: class="${cls}" aria-expanded="${aria}"`);
  }

  // Find and click the hamburger
  const menuBtn = await page.$('button[aria-expanded]');
  if (menuBtn) {
    console.log('\nClicking hamburger button...');
    await menuBtn.click();
    await page.waitForTimeout(2000);

    // Screenshot after click
    await page.screenshot({ path: `${OUT}/screenshot-mobile-menu-open3.png`, fullPage: false });

    // Check for new elements that appeared
    const allElements = await page.evaluate(() => {
      const results = [];
      document.querySelectorAll('*').forEach(el => {
        const cls = typeof el.className === 'string' ? el.className : '';
        const style = getComputedStyle(el);
        const rect = el.getBoundingClientRect();
        if (style.display !== 'none' && rect.width > 50 && rect.height > 50) {
          const imgs = Array.from(el.querySelectorAll('img')).map(img => ({
            src: img.currentSrc || img.src,
            natural: `${img.naturalWidth}x${img.naturalHeight}`,
            rendered: `${Math.round(img.getBoundingClientRect().width)}x${Math.round(img.getBoundingClientRect().height)}`,
            computed: {
              width: getComputedStyle(img).width,
              height: getComputedStyle(img).height,
              objectFit: getComputedStyle(img).objectFit,
            }
          }));
          if (imgs.length > 0) {
            results.push({
              tag: el.tagName,
              className: cls,
              rect: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
              display: style.display,
              imgs
            });
          }
        }
      });
      return results;
    });
    console.log('\n=== ELEMENTS WITH IMAGES AFTER MENU OPEN ===');
    console.log(JSON.stringify(allElements, null, 2));

    // Also look at the full DOM after menu open for any new nav/drawer
    const navDrawerHTML = await page.evaluate(() => {
      const all = [];
      document.querySelectorAll('*').forEach(el => {
        const cls = typeof el.className === 'string' ? el.className : '';
        if (
          cls.includes('menu') ||
          cls.includes('drawer') ||
          cls.includes('mobile') ||
          cls.includes('sidebar') ||
          cls.includes('overlay')
        ) {
          const rect = el.getBoundingClientRect();
          const style = getComputedStyle(el);
          if (style.display !== 'none' && rect.width > 0) {
            all.push({
              tag: el.tagName,
              className: cls,
              rect: `${Math.round(rect.width)}x${Math.round(rect.height)}`,
              display: style.display,
            });
          }
        }
      });
      return all;
    });
    console.log('\n=== MENU/DRAWER/MOBILE CLASSES AFTER OPEN ===');
    console.log(JSON.stringify(navDrawerHTML, null, 2));
  }

  await browser.close();
}

main().catch(err => {
  console.error('ERROR:', err.message);
  process.exit(1);
});
