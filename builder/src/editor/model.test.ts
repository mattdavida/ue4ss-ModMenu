import { describe, expect, it } from "vitest";
import { emptyDocument } from "../schema";
import {
  addItem,
  addSection,
  addTab,
  addTarget,
  canAccept,
  ensureIds,
  getItem,
  idBase,
  idCollision,
  patchItem,
  removeNode,
  renameTab,
  slugId,
  uniqueItemId,
} from "./model";

function itemId(doc: ReturnType<typeof emptyDocument>, sel: Extract<Parameters<typeof getItem>[1], { kind: "item" }>) {
  const item = getItem(doc, sel);
  return item && "id" in item ? item.id : undefined;
}

describe("editor model", () => {
  it("slugifies labels", () => {
    expect(slugId("God mode (mock)", "x")).toBe("godModeMock");
    expect(slugId("   ", "fallback")).toBe("fallback");
  });

  it("rejects dropdown in a row and fold in a fold", () => {
    expect(canAccept("row", "dropdown")).toBe(false);
    expect(canAccept("fold", "fold")).toBe(false);
    expect(canAccept("fold", "row")).toBe(true);
    expect(canAccept("row", "button")).toBe(true);
  });

  it("adds a dropdown after a selected row, not inside it", () => {
    const seeded = addItem(emptyDocument(), { kind: "section", index: 0 }, "row");
    expect(seeded).not.toBeNull();
    if (!seeded) {
      return;
    }
    expect(addTarget(seeded.doc, seeded.selection, "dropdown")).toEqual({
      sectionIndex: 0,
      containerPath: [],
      parent: "section",
      insertAt: seeded.selection.kind === "item" ? seeded.selection.path[0] + 1 : -1,
    });
    expect(addTarget(seeded.doc, seeded.selection, "button")?.parent).toBe("row");
  });

  it("adds a fold after a selected fold, not inside it", () => {
    const seeded = addItem(emptyDocument(), { kind: "section", index: 0 }, "fold");
    expect(seeded).not.toBeNull();
    if (!seeded) {
      return;
    }
    expect(addTarget(seeded.doc, seeded.selection, "fold")?.parent).toBe("section");
    expect(addTarget(seeded.doc, seeded.selection, "checkbox")?.parent).toBe("fold");
  });

  it("uniqueItemId avoids collisions", () => {
    const section = emptyDocument().sections[0];
    section.items.push({ type: "button", id: "doThing", label: "A" });
    expect(uniqueItemId(section, "doThing")).toBe("doThing2");
  });

  it("renameTab updates section.tab", () => {
    let doc = emptyDocument();
    const tabbed = addTab(doc);
    doc = tabbed.doc;
    const sectioned = addSection(doc, tabbed.selection);
    doc = sectioned.doc;
    doc = renameTab(doc, 0, "Cheats");
    expect(doc.init.tabs).toEqual(["Cheats"]);
    expect(doc.sections[1].tab).toBe("Cheats");
  });

  it("remove tab clears section.tab and drops empty tabs list", () => {
    let doc = addTab(emptyDocument()).doc;
    doc.sections[0].tab = "Tab";
    const result = removeNode(doc, { kind: "tab", index: 0 });
    expect(result.doc.init.tabs).toBeUndefined();
    expect(result.doc.sections[0].tab).toBeUndefined();
  });

  it("builds ids from section and label", () => {
    const section = emptyDocument().sections[0];
    expect(idBase(section, "button", "Do thing")).toBe("main_doThing");
    expect(idBase(section, "checkbox", "")).toBe("main_checkbox");
  });

  it("ensureIds fills missing widget ids", () => {
    const doc = emptyDocument();
    doc.sections[0].items.push({ type: "button", id: "", label: "Heal" });
    const filled = ensureIds(doc);
    const button = filled.sections[0].items.find((item) => item.type === "button");
    expect(button && "id" in button && button.id).toBe("main_heal");
  });

  it("empty id patch regenerates; custom id is kept when the label changes", () => {
    let doc = emptyDocument();
    const added = addItem(doc, { kind: "section", index: 0 }, "button");
    expect(added).not.toBeNull();
    if (!added || added.selection.kind !== "item") {
      return;
    }
    doc = added.doc;
    expect(itemId(doc, added.selection)).toBe("main_doThing");
    doc = patchItem(doc, added.selection, { id: "" });
    expect(itemId(doc, added.selection)).toBe("main_doThing");
    doc = patchItem(doc, added.selection, { id: "myHeal" });
    doc = patchItem(doc, added.selection, { label: "Heal player" });
    expect(itemId(doc, added.selection)).toBe("myHeal");
    doc = patchItem(doc, added.selection, { id: "main_doThing" });
    doc = patchItem(doc, added.selection, { label: "Do thing" });
    doc = patchItem(doc, added.selection, { label: "Revive" });
    expect(itemId(doc, added.selection)).toBe("main_revive");
  });

  it("idCollision ignores the item being edited", () => {
    const section = emptyDocument().sections[0];
    section.items = [
      { type: "button", id: "heal", label: "Heal" },
      { type: "button", id: "apply", label: "Apply" },
    ];
    expect(idCollision(section, "heal", [0])).toBe(false);
    expect(idCollision(section, "heal", [1])).toBe(true);
  });
});
