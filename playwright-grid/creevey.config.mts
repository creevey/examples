import path from "path";
import { fileURLToPath } from "url";
import { CreeveyConfig } from "creevey";
import { PlaywrightWebdriver } from 'creevey/playwright';

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const config: CreeveyConfig = {
  resolveStorybookUrl: () =>
    fetch("https://fake.testkontur.ru/ip")
      .then((res) => res.text())
      .then((data) => `http://${data}:6006`),
  testsDir: path.join(__dirname, "stories"),
  webdriver: PlaywrightWebdriver,
  gridUrl: "https://grid.skbkontur.ru/common/wd/hub",
  browsers: {
    chrome: {
      browserName: "chrome",
      seleniumCapabilities: {
        browserVersion: "127.0",
        platformName: "linux",
        "se:teamname": "front_infra",
      },
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
