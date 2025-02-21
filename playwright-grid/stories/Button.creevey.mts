import { kind, story, test } from "creevey";

kind("Button", () => {
  story("Primary", ({ setStoryParameters }) => {
    setStoryParameters({
      captureElement: "body",
    });

    test("idle", async context => {
      await context.matchImage(await context.takeScreenshot());
    });

    test("focus", async context => {
      await context.webdriver.keyboard.press('Tab')

      await context.matchImage(await context.takeScreenshot());
    });
  });
});
