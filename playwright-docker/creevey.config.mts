import path from "path";
import { fileURLToPath } from "url";
import { CreeveyConfig } from "creevey";
import { PlaywrightWebdriver } from 'creevey/playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const config: CreeveyConfig = {
  testsDir: path.join(__dirname, "stories"),
  useDocker: process.env.DOCKER !== 'true',
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
