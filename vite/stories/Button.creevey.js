import { kind, story, test } from "creevey";

kind("Button", () => {
  story("Primary", ({ setStoryParameters }) => {
    setStoryParameters({
      captureElement: "body",
    });

    test("idle", async function () {
      await this.expect(await this.takeScreenshot()).to.matchImage("idle");
    });

    test("focus", async function () {
      await this.browser
        .actions({
          bridge: true,
        })
        .sendKeys(this.keys.TAB)
        .perform();

      await this.expect(await this.takeScreenshot()).to.matchImage("focus");
    });
  });
});
