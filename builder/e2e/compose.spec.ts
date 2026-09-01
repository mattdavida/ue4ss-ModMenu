import { expect, test } from "@playwright/test";
import { gotoFresh, preview } from "./helpers";

test("add a button, rename it, see the label in the preview", async ({ page }) => {
  await gotoFresh(page);
  await page.getByTitle("Add Button").click();
  await page.getByLabel("Label").fill("Heal player");
  await expect(preview(page).getByRole("button", { name: "Heal player" })).toBeVisible();
});
