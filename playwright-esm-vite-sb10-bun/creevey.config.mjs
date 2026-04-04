import { PlaywrightWebdriver } from "creevey/playwright";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {import('creevey').CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  // Disable Docker in CI environments (GitHub Actions uses Playwright container with pre-installed browsers)
  useDocker: !process.env.CI,
  webdriver: PlaywrightWebdriver,
  browsers: {
    chromium: {
      browserName: "chromium",
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
