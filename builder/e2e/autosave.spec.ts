import { expect, test } from "@playwright/test";
import { STORAGE_KEY, gotoFresh, previewTitle } from "./helpers";

test("edit a title, reload, it is still there", async ({ page }) => {
  await gotoFresh(page);
  await page.locator(".ed-tree-label").filter({ has: page.locator(".ed-tree-hint", { hasText: "init" }) }).click();
  await page.getByLabel("Title").fill("Autosave Menu");
  await expect(previewTitle(page)).toHaveText("Autosave Menu");

  await expect
    .poll(async () => page.evaluate((key) => localStorage.getItem(key), STORAGE_KEY), { timeout: 2000 })
    .toContain("Autosave Menu");

  await page.reload();
  await expect(previewTitle(page)).toHaveText("Autosave Menu");
});
