#!/usr/bin/env node
/**
 * Playwright Storybook Verification Script
 * Uses Playwright to verify Storybook in a real browser
 * 
 * Requirements:
 * - playwright must be installed in the project
 * - For Docker-based Playwright: Docker must be running
 * - For local Playwright: Browser binaries must be installed
 */

import { createRequire } from 'module';
const require = createRequire(import.meta.url);

import { execSync } from 'child_process';
import { existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Configuration
const STORYBOOK_PORT = process.env.STORYBOOK_PORT || 6006;
const STORYBOOK_URL = process.env.STORYBOOK_URL || `http://localhost:${STORYBOOK_PORT}`;
const TIMEOUT = 30000;

// Colors for output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[0;31m',
  green: '\x1b[0;32m',
  yellow: '\x1b[1;33m',
  blue: '\x1b[0;34m',
};

const log = {
  info: (msg) => console.log(`${colors.blue}[INFO]${colors.reset} ${msg}`),
  success: (msg) => console.log(`${colors.green}[SUCCESS]${colors.reset} ${msg}`),
  warn: (msg) => console.log(`${colors.yellow}[WARN]${colors.reset} ${msg}`),
  error: (msg) => console.error(`${colors.red}[ERROR]${colors.reset} ${msg}`),
};

/**
 * Check if Playwright is available in current project
 */
function checkPlaywrightAvailable() {
  try {
    // Check from current working directory (should be project directory)
    const projectRequire = createRequire(join(process.cwd(), 'package.json'));
    // Try playwright first, then playwright-core
    try {
      projectRequire.resolve('playwright');
      return true;
    } catch (e) {
      projectRequire.resolve('playwright-core');
      return true;
    }
  } catch (e) {
    return false;
  }
}

/**
 * Check if Docker is available
 */
function checkDockerAvailable() {
  try {
    execSync('docker ps', { stdio: 'ignore' });
    return true;
  } catch (e) {
    return false;
  }
}

/**
 * Check if Playwright browsers are installed
 * Tries to launch chromium to verify
 */
async function checkPlaywrightBrowsers() {
  try {
    const projectRequire = createRequire(join(process.cwd(), 'package.json'));
    let playwrightPath;
    try {
      playwrightPath = projectRequire.resolve('playwright');
    } catch (e) {
      playwrightPath = projectRequire.resolve('playwright-core');
    }
    const playwrightModule = await import(playwrightPath);
    const chromium = playwrightModule.chromium || playwrightModule.default?.chromium;
    if (!chromium) {
      return false;
    }
    // Try to launch - this will fail if browsers aren't installed
    const browser = await chromium.launch({ headless: true, timeout: 10000 });
    await browser.close();
    return true;
  } catch (e) {
    return false;
  }
}

/**
 * Verify Storybook using Playwright
 */
async function verifyStorybook() {
  log.info(`Starting Playwright verification for ${STORYBOOK_URL}`);

  // Check if Playwright is installed
  if (!checkPlaywrightAvailable()) {
    log.error('Playwright is not installed in this project');
    log.error('Install with: npm install -D playwright');
    log.error('Then install browsers: npx playwright install chromium');
    process.exit(1);
  }

  // Get the path to playwright from the project
  const projectRequire = createRequire(join(process.cwd(), 'package.json'));
  let playwrightPath;
  try {
    playwrightPath = projectRequire.resolve('playwright');
  } catch (e) {
    playwrightPath = projectRequire.resolve('playwright-core');
  }

  log.info(`Loading Playwright from: ${playwrightPath}`);

  // Dynamic import of Playwright from project
  let chromium;
  try {
    const playwrightModule = await import(playwrightPath);
    // Handle both direct exports and default exports
    chromium = playwrightModule.chromium || playwrightModule.default?.chromium;
    if (!chromium) {
      throw new Error('Chromium browser not found in Playwright module');
    }
    log.success('Playwright module loaded successfully');
  } catch (e) {
    log.error(`Failed to import Playwright: ${e.message}`);
    throw e;
  }

  // Check if browsers are installed
  const browsersInstalled = await checkPlaywrightBrowsers();
  if (!browsersInstalled) {
    log.error('Playwright browsers are not installed');
    log.error('Install with: npx playwright install chromium');
    process.exit(1);
  }

  let browser;
  const consoleErrors = [];
  const consoleWarnings = [];
  const pageErrors = [];

  try {
    // Launch browser
    log.info('Launching Chromium browser with Playwright...');
    browser = await chromium.launch({
      headless: true,
    });

    const context = await browser.newContext({
      viewport: { width: 1280, height: 720 },
    });

    const page = await context.newPage();

    // Capture console messages
    page.on('console', (msg) => {
      const type = msg.type();
      const text = msg.text();

      if (type === 'error') {
        consoleErrors.push({ text });
        log.error(`Console error: ${text}`);
      } else if (type === 'warning') {
        consoleWarnings.push({ text });
        log.warn(`Console warning: ${text}`);
      }
    });

    // Capture page errors
    page.on('pageerror', (error) => {
      pageErrors.push(error.message);
      log.error(`Page error: ${error.message}`);
    });

    // Capture request failures
    page.on('requestfailed', (request) => {
      const failure = request.failure();
      if (failure) {
        log.error(`Request failed: ${request.url()} - ${failure.errorText}`);
      }
    });

    // Navigate to Storybook
    log.info('Navigating to Storybook...');
    const response = await page.goto(STORYBOOK_URL, {
      waitUntil: 'networkidle',
      timeout: TIMEOUT,
    });

    if (!response) {
      throw new Error('Failed to get response from Storybook URL');
    }

    if (!response.ok()) {
      throw new Error(`HTTP error ${response.status()}: ${response.statusText()}`);
    }

    log.success(`Page loaded successfully (HTTP ${response.status()})`);

    // Wait for Storybook to initialize
    log.info('Waiting for Storybook to initialize...');
    await page.waitForTimeout(3000);

    // Check 1: Verify page title
    log.info('Checking page title...');
    const title = await page.title();
    log.info(`Page title: ${title}`);
    
    if (title.toLowerCase().includes('storybook') || title.toLowerCase().includes('story book')) {
      log.success('✓ Page title contains "Storybook"');
    } else {
      log.warn('⚠ Page title does not contain "Storybook"');
    }

    // Check 2: Verify Storybook global variables
    log.info('Checking Storybook global variables...');
    const globalsCheck = await page.evaluate(() => {
      return {
        hasWindow: typeof window !== 'undefined',
        hasDocument: typeof document !== 'undefined',
        hasStorybookAPI: typeof window.__STORYBOOK_CLIENT_API__ !== 'undefined',
        hasStorybookPreview: typeof window.__STORYBOOK_PREVIEW__ !== 'undefined',
        hasStorybookAddons: typeof window.__STORYBOOK_ADDONS__ !== 'undefined',
        hasStorybookChannel: typeof window.__STORYBOOK_ADDONS_CHANNEL__ !== 'undefined',
      };
    });

    log.info('Global variables check:');
    Object.entries(globalsCheck).forEach(([key, value]) => {
      const status = value ? '✓' : '✗';
      const color = value ? colors.green : colors.yellow;
      console.log(`  ${color}${status}${colors.reset} ${key}: ${value}`);
    });

    // Check 3: Verify Storybook root element exists
    log.info('Checking Storybook DOM elements...');
    const domCheck = await page.evaluate(() => {
      const selectors = [
        '#storybook-root',
        '#root',
        '[data-testid="storybook-root"]',
        '.sb-show-main',
        '#storybook-preview-iframe',
      ];

      const results = {};
      selectors.forEach((selector) => {
        const element = document.querySelector(selector);
        results[selector] = element !== null;
      });

      return results;
    });

    log.info('DOM elements check:');
    Object.entries(domCheck).forEach(([selector, exists]) => {
      const status = exists ? '✓' : '✗';
      const color = exists ? colors.green : colors.yellow;
      console.log(`  ${color}${status}${colors.reset} ${selector}: ${exists}`);
    });

    // Check 4: Verify stories are loaded
    log.info('Checking if stories are loaded...');
    const storiesCheck = await page.evaluate(() => {
      const api = window.__STORYBOOK_CLIENT_API__;
      if (!api) {
        return { hasAPI: false, storyCount: 0 };
      }

      const stories = api.raw?.() || api.storyStore?.extract?.() || [];
      const storyCount = Array.isArray(stories) ? stories.length : Object.keys(stories).length;

      return {
        hasAPI: true,
        storyCount,
        stories: storyCount > 0 ? stories.slice(0, 3).map((s) => s.title || s.name || s.id) : [],
      };
    });

    if (storiesCheck.hasAPI) {
      log.success(`✓ Storybook API accessible, found ${storiesCheck.storyCount} stories`);
      if (storiesCheck.stories.length > 0) {
        log.info('Sample stories:');
        storiesCheck.stories.forEach((story) => {
          console.log(`  - ${story}`);
        });
      }
    } else {
      log.warn('⚠ Storybook API not accessible - may be loading or initialization issue');
    }

    // Check 5: Take screenshot for visual confirmation
    log.info('Taking screenshot...');
    const screenshotPath = join(process.cwd(), `storybook-verify-${Date.now()}.png`);
    await page.screenshot({ path: screenshotPath, fullPage: false });
    log.success(`Screenshot saved to: ${screenshotPath}`);

    // Final validation
    log.info('');
    log.info('========================================');
    log.info('VALIDATION SUMMARY');
    log.info('========================================');
    log.info(`Console Errors: ${consoleErrors.length}`);
    log.info(`Console Warnings: ${consoleWarnings.length}`);
    log.info(`Page Errors: ${pageErrors.length}`);
    log.info(`HTTP Status: ${response.status()}`);
    log.info(`Storybook API Available: ${storiesCheck.hasAPI}`);
    log.info(`Stories Loaded: ${storiesCheck.storyCount}`);
    log.info('');

    const hasCriticalErrors = consoleErrors.length > 0 || pageErrors.length > 0;

    if (hasCriticalErrors) {
      log.error('✗ VALIDATION FAILED: Critical errors detected');

      if (consoleErrors.length > 0) {
        log.error('\nConsole Errors:');
        consoleErrors.forEach((err) => {
          console.error(`  - ${err.text}`);
        });
      }

      if (pageErrors.length > 0) {
        log.error('\nPage Errors:');
        pageErrors.forEach((err) => {
          console.error(`  - ${err}`);
        });
      }

      return false;
    }

    if (!storiesCheck.hasAPI) {
      log.warn('⚠ Storybook API not detected - may still be loading');
    }

    log.success('✓ VALIDATION PASSED: Storybook loaded successfully with Playwright');
    return true;

  } catch (error) {
    log.error(`Verification failed: ${error.message}`);
    if (error.stack) {
      log.error(error.stack.split('\n').slice(0, 3).join('\n'));
    }
    return false;

  } finally {
    if (browser) {
      log.info('Closing browser...');
      await browser.close().catch(() => {});
    }
  }
}

// Run verification
verifyStorybook()
  .then((success) => {
    process.exit(success ? 0 : 1);
  })
  .catch((error) => {
    log.error(`Unexpected error: ${error.message}`);
    process.exit(1);
  });
