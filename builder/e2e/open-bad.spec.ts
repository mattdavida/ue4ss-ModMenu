import { expect, test } from "@playwright/test";
import { chooseJson, confirmDialog, gotoFresh, previewTitle } from "./helpers";

test("bad Open keeps the current menu and shows a bar error", async ({ page }) => {
  await gotoFresh(page);
  await page.getByRole("button", { name: "Example" }).click();
  await confirmDialog(page, "Load example");
  await expect(previewTitle(page)).toHaveText("ModMenu Host");

  await page.getByRole("button", { name: "Open" }).click();
  await chooseJson(page, {
    name: "empty.json",
    mimeType: "application/json",
    buffer: Buffer.from("{}"),
  });
  await expect(page.getByRole("alert")).toContainText(/version/i);
  await expect(previewTitle(page)).toHaveText("ModMenu Host");

  await page.getByRole("button", { name: "Open" }).click();
  await chooseJson(page, {
    name: "host.lua",
    mimeType: "text/plain",
    buffer: Buffer.from("Init({ title = 'nope' })"),
  });
  await expect(page.getByRole("alert")).toHaveText("not valid JSON");
  await expect(previewTitle(page)).toHaveText("ModMenu Host");
});
