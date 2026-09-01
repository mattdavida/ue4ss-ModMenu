import { expect, test } from "@playwright/test";
import { cancelDialog, confirmDialog, gotoFresh, preview, previewTitle } from "./helpers";

test("Example cancel keeps the current menu; OK replaces it", async ({ page }) => {
  await gotoFresh(page);
  await page.getByRole("button", { name: "Example" }).click();
  await cancelDialog(page);
  await expect(previewTitle(page)).toHaveText("My Mod Menu");

  await page.getByRole("button", { name: "Example" }).click();
  await confirmDialog(page, "Load example");
  await expect(previewTitle(page)).toHaveText("ModMenu Host");
  await expect(preview(page).getByRole("button", { name: "Cheats" })).toBeVisible();

  await page.getByRole("button", { name: "New" }).click();
  await cancelDialog(page);
  await expect(previewTitle(page)).toHaveText("ModMenu Host");

  await page.getByRole("button", { name: "New" }).click();
  await confirmDialog(page, "New menu");
  await expect(previewTitle(page)).toHaveText("My Mod Menu");
});
