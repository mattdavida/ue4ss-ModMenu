import { expect, test } from "@playwright/test";
import { confirmDialog, gotoFresh, previewTitle } from "./helpers";

test("download JSON, New, Open brings the title back", async ({ page }, testInfo) => {
  await gotoFresh(page);
  await page.locator(".ed-tree-label").filter({ has: page.locator(".ed-tree-hint", { hasText: "init" }) }).click();
  await page.getByLabel("Title").fill("Round Trip Menu");
  await expect(previewTitle(page)).toHaveText("Round Trip Menu");

  const [download] = await Promise.all([
    page.waitForEvent("download"),
    page.getByRole("button", { name: "JSON" }).click(),
  ]);
  const saved = testInfo.outputPath("modmenu.json");
  await download.saveAs(saved);

  await page.getByRole("button", { name: "New" }).click();
  await confirmDialog(page, "New menu");
  await expect(previewTitle(page)).toHaveText("My Mod Menu");

  await page.getByRole("button", { name: "Open" }).click();
  const [chooser] = await Promise.all([
    page.waitForEvent("filechooser"),
    confirmDialog(page, "Choose file"),
  ]);
  await chooser.setFiles(saved);
  await expect(previewTitle(page)).toHaveText("Round Trip Menu");
});
