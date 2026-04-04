import path from "path";
import { fileURLToPath } from "url";
import { SeleniumWebdriver } from "creevey/selenium";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {import('creevey').CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  webdriver: SeleniumWebdriver,
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
