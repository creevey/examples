#!/usr/bin/env node
/**
 * Selenium WebDriver Storybook Verification Script
 * Uses selenium-webdriver to verify Storybook in a real browser
 * 
 * Requirements:
 * - selenium-webdriver must be installed in the project
 * - Selenium Grid must be running (or local browser drivers)
 */

import { createRequire } from 'module';
const require = createRequire(import.meta.url);

import { execSync, spawn } from 'child_process';
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
 * Check if Selenium WebDriver is available in current project
 */
function checkSeleniumAvailable() {
  try {
    // Check from current working directory (should be project directory)
    const projectRequire = createRequire(join(process.cwd(), 'package.json'));
    projectRequire.resolve('selenium-webdriver');
    return true;
  } catch (e) {
    return false;
  }
}

/**
 * Check if Selenium Grid is running
 */
async function checkSeleniumGrid() {
  try {
    const response = await fetch('http://localhost:4444/wd/hub/status');
    const data = await response.json();
    return data.value?.ready === true;
  } catch (e) {
    return false;
  }
}

/**
 * Verify Storybook using Selenium WebDriver
 */
async function verifyStorybook() {
  log.info(`Starting Selenium verification for ${STORYBOOK_URL}`);

  // Check if selenium-webdriver is installed
  if (!checkSeleniumAvailable()) {
    log.error('selenium-webdriver is not installed in this project');
    log.error('Install with: npm install -D selenium-webdriver');
    process.exit(1);
  }

  // Get the path to selenium-webdriver from the project
  const projectRequire = createRequire(join(process.cwd(), 'package.json'));
  const seleniumPath = projectRequire.resolve('selenium-webdriver');
  const chromePath = projectRequire.resolve('selenium-webdriver/chrome.js');

  // Dynamic import of selenium-webdriver from project
  const { Builder, By, until } = await import(seleniumPath);
  const chrome = await import(chromePath);

  // Check if Selenium Grid is available
  const gridAvailable = await checkSeleniumGrid();
  
  let driver;
  const consoleErrors = [];
  const pageErrors = [];

  try {
    // Build WebDriver
    log.info('Initializing Selenium WebDriver...');
    
    if (gridAvailable) {
      log.info('Connecting to Selenium Grid at http://localhost:4444/wd/hub');
      driver = await new Builder()
        .forBrowser('chrome')
        .usingServer('http://localhost:4444/wd/hub')
        .build();
    } else {
      log.info('Selenium Grid not available, using local Chrome');
      log.warn('Note: This requires Chrome to be installed locally');
      
      const options = new chrome.Options();
      options.addArguments('--headless');
      options.addArguments('--no-sandbox');
      options.addArguments('--disable-dev-shm-usage');
      
      driver = await new Builder()
        .forBrowser('chrome')
        .setChromeOptions(options)
        .build();
    }

    // Setup console error collection
    await driver.manage().logs().get('browser').catch(() => []);

    // Navigate to Storybook
    log.info('Navigating to Storybook...');
    await driver.get(STORYBOOK_URL);

    // Wait for page to load
    log.info('Waiting for Storybook to load...');
    await driver.wait(until.elementLocated(By.css('body')), TIMEOUT);

    // Wait a bit for JavaScript to execute
    await new Promise(resolve => setTimeout(resolve, 3000));

    log.success('Page loaded successfully');

    // Check 1: Verify page title
    log.info('Checking page title...');
    const title = await driver.getTitle();
    log.info(`Page title: ${title}`);
    
    if (title.toLowerCase().includes('storybook') || title.toLowerCase().includes('story book')) {
      log.success('✓ Page title contains "Storybook"');
    } else {
      log.warn('⚠ Page title does not contain "Storybook"');
    }

    // Check 2: Verify Storybook global variables
    log.info('Checking Storybook global variables...');
    const globalsCheck = await driver.executeScript(() => {
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

    // Check 3: Verify DOM elements
    log.info('Checking Storybook DOM elements...');
    const domCheck = await driver.executeScript(() => {
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

    // Check 4: Get browser logs for errors
    log.info('Checking browser console for errors...');
    try {
      const logs = await driver.manage().logs().get('browser');
      logs.forEach((entry) => {
        if (entry.level.name === 'SEVERE') {
          consoleErrors.push(entry.message);
          log.error(`Console error: ${entry.message}`);
        }
      });
    } catch (e) {
      log.warn('Could not retrieve browser logs');
    }

    // Check 5: Verify page source contains Storybook indicators
    log.info('Verifying page content...');
    const pageSource = await driver.getPageSource();
    const hasStorybookMarkers = 
      pageSource.includes('storybook') ||
      pageSource.includes('sb-') ||
      pageSource.includes('__STORYBOOK');

    if (hasStorybookMarkers) {
      log.success('✓ Storybook markers found in page source');
    } else {
      log.warn('⚠ Storybook markers not found in page source');
    }

    // Final validation
    log.info('');
    log.info('========================================');
    log.info('VALIDATION SUMMARY');
    log.info('========================================');
    log.info(`Console Errors: ${consoleErrors.length}`);
    log.info(`Page Errors: ${pageErrors.length}`);
    log.info(`Page Loaded: true`);
    log.info(`Page Title: ${title}`);
    log.info('');

    const hasCriticalErrors = consoleErrors.length > 0;
    const storybookMarkersFound = hasStorybookMarkers;

    if (hasCriticalErrors) {
      log.error('✗ VALIDATION FAILED: Console errors detected');
      return false;
    }

    if (!storybookMarkersFound) {
      log.error('✗ VALIDATION FAILED: Storybook markers not found');
      return false;
    }

    log.success('✓ VALIDATION PASSED: Storybook loaded successfully with Selenium');
    return true;

  } catch (error) {
    log.error(`Verification failed: ${error.message}`);
    if (error.stack) {
      log.error(error.stack.split('\n').slice(0, 3).join('\n'));
    }
    return false;

  } finally {
    if (driver) {
      log.info('Closing WebDriver...');
      await driver.quit().catch(() => {});
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
