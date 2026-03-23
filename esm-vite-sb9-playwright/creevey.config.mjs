import { CreeveyConfig, PlaywrightWebdriver } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  webdriver: PlaywrightWebdriver,
  // Uses Selenium Grid with Playwright WebDriver
  gridUrl: "http://localhost:4444/wd/hub",
  browsers: {
    chromium: {
      browserName: "chromium",
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
