import { emptyDocument } from "../schema";
import type { MenuDocument } from "../schema";
import { adoptJson } from "./adopt";
import { ensureIds } from "./model";

export const STORAGE_KEY = "modmenu-builder:doc:v1";

export type StorageLike = {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
};

function browserStorage(): StorageLike | null {
  try {
    if (typeof localStorage === "undefined") {
      return null;
    }
    return localStorage;
  } catch {
    return null;
  }
}

export function loadStored(storage: StorageLike | null = browserStorage()): MenuDocument | null {
  if (!storage) {
    return null;
  }
  let text: string | null;
  try {
    text = storage.getItem(STORAGE_KEY);
  } catch {
    return null;
  }
  if (text === null || text === "") {
    return null;
  }
  const result = adoptJson(text);
  return result.ok ? result.document : null;
}

export function saveStored(doc: MenuDocument, storage: StorageLike | null = browserStorage()): void {
  if (!storage) {
    return;
  }
  try {
    storage.setItem(STORAGE_KEY, JSON.stringify(doc));
  } catch {
    // quota / disabled — keep editing
  }
}

export function bootDocument(storage: StorageLike | null = browserStorage()): MenuDocument {
  return loadStored(storage) ?? ensureIds(emptyDocument());
}
