import { describe, expect, it } from "vitest";
import { emptyDocument } from "./defaults";
import { hostFixture } from "./fixture";
import { countItems, validateDocument } from "./validate";
import type { Item, MenuDocument } from "./types";

function clone(): MenuDocument {
  return structuredClone(hostFixture);
}

function messages(doc: unknown) {
  return validateDocument(doc).map((issue) => `${issue.path}: ${issue.message}`);
}

describe("validateDocument", () => {
  it("accepts the ModMenuHost fixture", () => {
    expect(validateDocument(hostFixture)).toEqual([]);
    expect(countItems(hostFixture)).toBeGreaterThan(20);
  });

  it("accepts an empty new menu", () => {
    expect(validateDocument(emptyDocument())).toEqual([]);
  });

  it("rejects a dropdown inside a row", () => {
    const doc = clone();
    const row = doc.sections[1].items[3];
    if (row.type !== "row") {
      throw new Error("expected Toggles row");
    }
    (row.items as unknown as Item[]).push({
      type: "dropdown",
      id: "bad",
      label: "Bad",
      options: ["A"],
    });
    expect(messages(doc).some((m) => m.includes("unsupported row child type 'dropdown'"))).toBe(true);
  });

  it("rejects a fold inside a fold", () => {
    const doc = clone();
    const fold = doc.sections[3].items.find((item) => item.type === "fold");
    if (!fold || fold.type !== "fold") {
      throw new Error("expected Give fold");
    }
    (fold.items as unknown as Item[]).push({
      type: "fold",
      id: "nested",
      label: "Nested",
      items: [{ type: "label", label: "nope" }],
    });
    expect(messages(doc).some((m) => m.includes("unsupported fold child type 'fold'"))).toBe(true);
  });

  it("rejects duplicate item ids in a section (including fold children)", () => {
    const doc = clone();
    const give = doc.sections[3];
    give.items.push({ type: "button", id: "giveAllBtn", label: "Dup" });
    expect(messages(doc).some((m) => m.includes("duplicate id 'giveAllBtn'"))).toBe(true);
  });

  it("rejects a tab that is not in Init.tabs", () => {
    const doc = clone();
    doc.sections[0].tab = "Missing";
    expect(messages(doc).some((m) => m.includes("tab Missing is not in Init"))).toBe(true);
  });

  it("rejects collapsed=true without collapsible", () => {
    const doc = clone();
    doc.sections[0].collapsed = true;
    expect(messages(doc).some((m) => m.includes("collapsed=true requires collapsible=true"))).toBe(true);
  });

  it("rejects empty dropdown options", () => {
    const doc = clone();
    const dropdown = doc.sections[1].items[2];
    if (dropdown.type !== "dropdown") {
      throw new Error("expected difficulty dropdown");
    }
    dropdown.options = [];
    expect(messages(doc).some((m) => m.includes("non-empty .options array"))).toBe(true);
  });

  it("rejects duplicate tab names", () => {
    const doc = clone();
    doc.init.tabs = ["Cheats", "Cheats"];
    expect(messages(doc).some((m) => m.includes("duplicate tab Cheats"))).toBe(true);
  });

  it("rejects duplicate section ids", () => {
    const doc = clone();
    doc.sections[1].id = "Status";
    expect(messages(doc).some((m) => m.includes("duplicate section id 'Status'"))).toBe(true);
  });

  it("rejects min > max", () => {
    const doc = clone();
    const row = doc.sections[1].items[3];
    if (row.type !== "row" || row.items[0].type !== "number") {
      throw new Error("expected heal number");
    }
    row.items[0].min = 10;
    row.items[0].max = 1;
    expect(messages(doc).some((m) => m.includes("min must be <= max"))).toBe(true);
  });
});
