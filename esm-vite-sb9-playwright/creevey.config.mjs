import { PlaywrightWebdriver } from "creevey/playwright";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {import('creevey').CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  webdriver: PlaywrightWebdriver,
  // Uses Selenium Grid with Playwright WebDriver
  gridUrl: "http://localhost:4444/wd/hub",
  browsers: {
    chrome: {
      browserName: "chrome",
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
