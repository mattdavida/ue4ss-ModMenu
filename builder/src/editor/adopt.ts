import {
  DOCUMENT_VERSION,
  DOCK_SIDES,
  THEMES,
  emptyDocument,
  validateDocument,
} from "../schema";
import type { DockSide, InitSpec, Issue, MenuDocument, ThemeName } from "../schema";
import { ensureIds } from "./model";

export type AdoptOk = {
  ok: true;
  document: MenuDocument;
  issues: Issue[];
};

export type AdoptFail = {
  ok: false;
  reason: string;
};

export type AdoptResult = AdoptOk | AdoptFail;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function adoptInit(raw: Record<string, unknown>): InitSpec {
  const fallback = emptyDocument().init;
  const dock =
    typeof raw.dock === "string" && DOCK_SIDES.has(raw.dock) ? (raw.dock as DockSide) : fallback.dock;
  const theme =
    typeof raw.theme === "string" && THEMES.has(raw.theme) ? (raw.theme as ThemeName) : fallback.theme;
  const init: InitSpec = {
    title: typeof raw.title === "string" && raw.title !== "" ? raw.title : fallback.title,
    instanceId:
      typeof raw.instanceId === "string" && raw.instanceId !== "" ? raw.instanceId : fallback.instanceId,
    keyHint: typeof raw.keyHint === "string" && raw.keyHint !== "" ? raw.keyHint : fallback.keyHint,
    dock,
    theme,
  };
  if (Array.isArray(raw.tabs)) {
    const tabs = raw.tabs.filter((tab): tab is string => typeof tab === "string");
    if (tabs.length > 0) {
      init.tabs = tabs;
    }
  }
  return init;
}

function itemsAreRecords(items: unknown): boolean {
  if (!Array.isArray(items)) {
    return false;
  }
  for (const item of items) {
    if (!isRecord(item)) {
      return false;
    }
    if ((item.type === "row" || item.type === "fold") && item.items !== undefined) {
      if (!itemsAreRecords(item.items)) {
        return false;
      }
    }
  }
  return true;
}

function adoptSections(raw: unknown): { ok: true; sections: MenuDocument["sections"] } | AdoptFail {
  if (!Array.isArray(raw)) {
    return { ok: false, reason: "document needs a sections array" };
  }
  const sections: MenuDocument["sections"] = [];
  for (const section of raw) {
    if (!isRecord(section)) {
      return { ok: false, reason: "each section must be an object" };
    }
    const items = section.items === undefined ? [] : section.items;
    if (!itemsAreRecords(items)) {
      return { ok: false, reason: "section items must be objects" };
    }
    if (section.items === undefined) {
      section.items = [];
    }
    sections.push(section as MenuDocument["sections"][number]);
  }
  return { ok: true, sections };
}

/** Parse builder JSON. Soft-adopts v1 documents; fills missing ids. */
export function adoptJson(text: string): AdoptResult {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { ok: false, reason: "not valid JSON" };
  }
  if (!isRecord(parsed)) {
    return { ok: false, reason: "JSON must be an object" };
  }
  if (parsed.version !== DOCUMENT_VERSION) {
    return { ok: false, reason: `unsupported version (need ${DOCUMENT_VERSION})` };
  }
  if (!isRecord(parsed.init)) {
    return { ok: false, reason: "document needs an init object" };
  }
  const sections = adoptSections(parsed.sections);
  if (!sections.ok) {
    return sections;
  }
  const document = ensureIds({
    version: DOCUMENT_VERSION,
    init: adoptInit(parsed.init),
    sections: sections.sections,
  });
  return {
    ok: true,
    document,
    issues: validateDocument(document),
  };
}
