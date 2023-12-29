const path = require("path");
const { hybridStoriesProvider } = require("creevey");

const config = {
  storybookUrl: `http://localhost:6006`,
  storybookDir: path.join(__dirname, ".storybook"),
  reportDir: path.join(__dirname, "report"),
  screenDir: path.join(__dirname, "images"),
  gridUrl: "https://frontinfra:frontinfra@grid.testkontur.ru/wd/hub",
  diffOptions: { threshold: 0, includeAA: false },
  storiesProvider: hybridStoriesProvider,
  testsDir: path.join(__dirname, "stories"),
  browsers: {
    chrome: {
      browserName: "chrome",
      viewport: { width: 1024, height: 720 },
      platformName: "linux",
      name: "infrafront/chrome8px",
      browserVersion: "100.0",
      version: "100.0",
    },
  },
};

module.exports = config;
