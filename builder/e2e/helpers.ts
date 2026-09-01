import { expect, type Page } from "@playwright/test";

export const STORAGE_KEY = "modmenu-builder:doc:v1";

export function preview(page: Page) {
  return page.getByRole("region", { name: "Menu preview" });
}

export function previewTitle(page: Page) {
  return preview(page).locator(".mm-title");
}

export async function gotoFresh(page: Page) {
  await page.goto("/");
  await page.evaluate((key) => {
    localStorage.removeItem(key);
  }, STORAGE_KEY);
  await page.reload();
  await expect(previewTitle(page)).toHaveText("My Mod Menu");
}

export async function confirmDialog(page: Page, action: string) {
  const dialog = page.getByRole("dialog");
  await expect(dialog).toBeVisible();
  await dialog.getByRole("button", { name: action, exact: true }).click();
  await expect(dialog).toBeHidden();
}

export async function cancelDialog(page: Page) {
  const dialog = page.getByRole("dialog");
  await expect(dialog).toBeVisible();
  await dialog.getByRole("button", { name: "Cancel" }).click();
  await expect(dialog).toBeHidden();
}

export async function chooseJson(page: Page, file: { name: string; mimeType: string; buffer: Buffer }) {
  const [chooser] = await Promise.all([
    page.waitForEvent("filechooser"),
    confirmDialog(page, "Choose file"),
  ]);
  await chooser.setFiles(file);
}
