import { Key } from 'selenium-webdriver'
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
      await context.webdriver
        .actions({
          bridge: true,
        })
        .sendKeys(Key.TAB)
        .perform();

      await context.matchImage(await context.takeScreenshot());
    });
  });
});
