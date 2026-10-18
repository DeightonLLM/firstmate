/**
 * Widget Disambiguation Test for staging.core-distro.com
 * Uses npx playwright to test multiple independent signals for widget presence
 */

import { chromium } from 'playwright';

const STAGING_URL = 'https://staging.core-distro.com';
const VIEWPORTS = [
  { name: 'mobile', width: 390, height: 844 },
  { name: 'desktop', width: 1440, height: 900 }
];

const NETWORK_IDLE_TIMEOUT = 10000; // 10 seconds
const WIDGET_WAIT_TIMEOUT = 15000; // 15 seconds

const results = {
  timestamp: new Date().toISOString(),
  viewportResults: [],
  rawLog: []
};

function log(...args) {
  const msg = args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
  results.rawLog.push(msg);
  console.log(msg);
}

async function runTest() {
  for (const vp of VIEWPORTS) {
    log(`\n=== Testing viewport: ${vp.name} (${vp.width}x${vp.height}) ===`);
    
    const browser = await chromium.launch({ headless: true });
    const context = await browser.newContext({
      viewport: { width: vp.width, height: vp.height },
      userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
    });
    
    const page = await context.newPage();
    
    // Track all network requests
    const embedRequests = [];
    const non2xxResponses = [];
    const consoleErrors = [];
    
    page.on('request', request => {
      const url = request.url();
      const patterns = ['embed', 'llm', 'anythingllm', 'chat'];
      if (patterns.some(p => url.toLowerCase().includes(p))) {
        embedRequests.push({
          url,
          method: request.method(),
          headers: request.headers()
        });
        log(`[NETWORK] ${request.method()} ${url}`);
      }
    });
    
    page.on('response', response => {
      const url = response.url();
      const status = response.status();
      if (status >= 300 || status < 200) {
        non2xxResponses.push({ url, status, statusText: response.statusText() });
        log(`[NON-2XX] ${status} ${response.statusText()} ${url}`);
      }
    });
    
    page.on('console', msg => {
      if (msg.type() === 'error') {
        consoleErrors.push({ text: msg.text(), location: msg.location() });
        log(`[CONSOLE ERROR] ${msg.text()}`);
      }
    });

    // Step 1: Fetch raw HTML
    log(`\n--- Step 1: Fetching raw HTML from ${STAGING_URL} ---`);
    let rawHtml = '';
    let httpStatus = null;
    try {
      const htmlResponse = await page.goto(STAGING_URL, { 
        waitUntil: 'domcontentloaded',
        timeout: 30000 
      });
      httpStatus = htmlResponse.status();
      rawHtml = await page.content();
      log(`HTTP Status: ${httpStatus}`);
      log(`HTML length: ${rawHtml.length} chars`);
      
      // Check for widget script in HTML
      const hasWidgetScript = rawHtml.includes('anythingllm-chat-widget') || 
                             rawHtml.includes('llm.hd2.ai') ||
                             rawHtml.includes('ChatWidget');
      log(`Widget script in HTML: ${hasWidgetScript}`);
      
      // Extract script tags
      const scriptMatches = rawHtml.match(/<script[^>]*src="([^"]*)"[^>]*>/gi) || [];
      log(`Script tags found: ${scriptMatches.length}`);
      scriptMatches.forEach(s => {
        if (s.match(/embed|llm|chat/i)) {
          log(`  RELEVANT SCRIPT: ${s}`);
        }
      });
    } catch (err) {
      log(`ERROR fetching HTML: ${err.message}`);
    }

    // Step 2: Wait for network idle
    log(`\n--- Step 2: Waiting for network idle (timeout: ${NETWORK_IDLE_TIMEOUT}ms) ---`);
    const networkStart = Date.now();
    try {
      await page.waitForLoadState('networkidle', { timeout: NETWORK_IDLE_TIMEOUT });
      log(`Network idle reached after ${Date.now() - networkStart}ms`);
    } catch (err) {
      log(`Network idle timeout after ${Date.now() - networkStart}ms: ${err.message}`);
    }
    
    // Step 3: Check for widget via multiple signals
    log(`\n--- Step 3: Checking widget signals ---`);
    const signals = {
      scriptInHtml: rawHtml.includes('anythingllm-chat-widget') || rawHtml.includes('llm.hd2.ai'),
      askQuestionsButton: false,
      widgetIframe: false,
      widgetShadowRoot: false,
      widgetButton: false,
      chatContainer: false
    };
    
    // Signal 1: Check for ASK QUESTIONS button
    try {
      const askBtn = await page.locator('button:has-text("ASK QUESTIONS")').first();
      if (await askBtn.count() > 0) {
        signals.askQuestionsButton = true;
        log(`SIGNAL: ASK QUESTIONS button found`);
        await askBtn.click();
        log(`Clicked ASK QUESTIONS button`);
        
        // Wait for widget panel
        await page.waitForTimeout(2000);
        
        // Check for widget panel elements
        signals.widgetIframe = await page.locator('iframe[src*="embed"], iframe[src*="llm"]').count() > 0;
        signals.widgetShadowRoot = await page.evaluate(() => {
          // Check shadow roots
          const allElements = document.querySelectorAll('*');
          for (const el of allElements) {
            if (el.shadowRoot) return true;
          }
          return false;
        });
        
        // Check for floating button
        signals.widgetButton = await page.locator('[class*="floating"], [class*="widget"], [class*="chat"]').count() > 0;
        
        // Check for chat container
        signals.chatContainer = await page.locator('[class*="anythingllm"], [id*="anythingllm"], [class*="chat-panel"]').count() > 0;
        
        log(`After click - iframe: ${signals.widgetIframe}, shadowRoot: ${signals.widgetShadowRoot}`);
        log(`After click - widgetButton: ${signals.widgetButton}, chatContainer: ${signals.chatContainer}`);
      } else {
        log(`SIGNAL: ASK QUESTIONS button NOT found`);
      }
    } catch (err) {
      log(`SIGNAL check error: ${err.message}`);
    }

    // Step 4: Check for any visible chat widget elements
    log(`\n--- Step 4: Scanning for widget elements ---`);
    const widgetSelectors = [
      'iframe[src*="llm"]',
      'iframe[src*="embed"]', 
      'iframe[src*="anythingllm"]',
      '[class*="anythingllm"]',
      '[class*="chat-widget"]',
      '[class*="llm-widget"]',
      '[id*="anythingllm"]',
      'chat-widget',
      'anythingllm-chat-widget'
    ];
    
    for (const selector of widgetSelectors) {
      try {
        const count = await page.locator(selector).count();
        if (count > 0) {
          log(`FOUND selector "${selector}": ${count} elements`);
        }
      } catch (e) {}
    }

    // Store results for this viewport
    results.viewportResults.push({
      viewport: vp,
      httpStatus,
      htmlLength: rawHtml.length,
      signals,
      embedRequests,
      non2xxResponses,
      consoleErrors,
      waitDuration: {
        networkIdle: Date.now() - networkStart,
        networkIdleTimeout: NETWORK_IDLE_TIMEOUT
      }
    });

    await browser.close();
  }

  // Summary
  log(`\n=== SUMMARY ===`);
  for (const vr of results.viewportResults) {
    log(`\n${vr.viewport.name} (${vr.viewport.width}x${vr.viewport.height}):`);
    log(`  HTTP Status: ${vr.httpStatus}`);
    log(`  Widget signals:`);
    log(`    - Script in HTML: ${vr.signals.scriptInHtml}`);
    log(`    - ASK QUESTIONS button: ${vr.signals.askQuestionsButton}`);
    log(`    - Widget iframe: ${vr.signals.widgetIframe}`);
    log(`    - Shadow root: ${vr.signals.widgetShadowRoot}`);
    log(`    - Widget button: ${vr.signals.widgetButton}`);
    log(`    - Chat container: ${vr.signals.chatContainer}`);
    log(`  Network idle wait: ${vr.waitDuration.networkIdle}ms (timeout: ${vr.waitDuration.networkIdleTimeout}ms)`);
    log(`  Embed requests: ${vr.embedRequests.length}`);
    vr.embedRequests.forEach(r => log(`    - ${r.method} ${r.url}`));
    log(`  Non-2xx responses: ${vr.non2xxResponses.length}`);
    vr.non2xxResponses.forEach(r => log(`    - ${r.status} ${r.url}`));
    log(`  Console errors: ${vr.consoleErrors.length}`);
    vr.consoleErrors.forEach(e => log(`    - ${e.text}`));
  }

  return results;
}

runTest()
  .then(results => {
    console.log('\n\n=== RAW JSON OUTPUT ===');
    console.log(JSON.stringify(results, null, 2));
    process.exit(0);
  })
  .catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
