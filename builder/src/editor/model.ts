import {
  FOLD_CHILD_TYPES,
  ROW_CHILD_TYPES,
} from "../schema";
import type {
  DockSide,
  Item,
  ItemType,
  MenuDocument,
  Section,
  ThemeName,
} from "../schema";

export type AcceptParent = "section" | "fold" | "row";

export type NodeRef =
  | { kind: "init" }
  | { kind: "tab"; index: number }
  | { kind: "section"; index: number }
  | { kind: "item"; sectionIndex: number; path: number[] };

export type AddTarget = {
  sectionIndex: number;
  containerPath: number[];
  parent: AcceptParent;
  insertAt: number;
};

export function draft<T>(value: T, fn: (next: T) => void): T {
  const next = structuredClone(value);
  fn(next);
  return next;
}

export function sameRef(a: NodeRef | null, b: NodeRef | null): boolean {
  if (a === null || b === null || a.kind !== b.kind) {
    return false;
  }
  if (a.kind === "init") {
    return true;
  }
  if (a.kind === "tab" && b.kind === "tab") {
    return a.index === b.index;
  }
  if (a.kind === "section" && b.kind === "section") {
    return a.index === b.index;
  }
  if (a.kind === "item" && b.kind === "item") {
    return a.sectionIndex === b.sectionIndex && a.path.join(".") === b.path.join(".");
  }
  return false;
}

export function slugId(label: string, fallback: string): string {
  const parts = label
    .replace(/[^A-Za-z0-9]+/g, " ")
    .trim()
    .split(/\s+/)
    .filter((part) => part.length > 0);
  if (parts.length === 0) {
    return fallback;
  }
  const head = parts[0].charAt(0).toLowerCase() + parts[0].slice(1);
  const rest = parts
    .slice(1)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
    .join("");
  const id = (head + rest).replace(/[^A-Za-z0-9_]/g, "");
  return id || fallback;
}

function walkIds(items: Item[], into: Set<string>) {
  for (const item of items) {
    if ("id" in item && typeof item.id === "string" && item.id !== "") {
      into.add(item.id);
    }
    if (item.type === "row" || item.type === "fold") {
      walkIds(item.items, into);
    }
  }
}

export function collectItemIds(section: Section): Set<string> {
  const ids = new Set<string>();
  walkIds(section.items, ids);
  return ids;
}

export function uniqueName(used: Set<string>, base: string): string {
  const root = base || "item";
  if (!used.has(root)) {
    return root;
  }
  let n = 2;
  while (used.has(root + n)) {
    n += 1;
  }
  return root + n;
}

export function uniqueItemId(section: Section, base: string): string {
  return uniqueName(collectItemIds(section), base);
}

function itemLabelOf(item: Item): string | undefined {
  return "label" in item ? item.label : undefined;
}

/** `SectionId_labelSlug` — fallback is the widget type when the label is empty. */
export function idBase(section: Section, type: ItemType, label?: string): string {
  const sectionPart = slugId(section.id || section.title || "section", "section");
  const namePart = slugId(label ?? "", type);
  return `${sectionPart}_${namePart}`;
}

export function suggestItemId(section: Section, type: ItemType, label: string | undefined, exceptId?: string): string {
  const used = collectItemIds(section);
  if (exceptId) {
    used.delete(exceptId);
  }
  return uniqueName(used, idBase(section, type, label));
}

export function isGeneratedId(id: string, section: Section, type: ItemType, label?: string): boolean {
  if (id === "") {
    return true;
  }
  const base = idBase(section, type, label);
  if (id === base) {
    return true;
  }
  return id.startsWith(base) && /^[0-9]+$/.test(id.slice(base.length));
}

function assignItemId(section: Section, item: Item, prev?: Item) {
  if (item.type === "separator" || item.type === "row") {
    return;
  }
  const label = itemLabelOf(item);
  const prevLabel = prev ? itemLabelOf(prev) : undefined;
  const current = "id" in item ? item.id : undefined;
  const prevId = prev && "id" in prev ? prev.id : undefined;
  const empty = current === undefined || current === "";
  const stillAuto = prev !== undefined && prevLabel !== label && current === prevId && isGeneratedId(current ?? "", section, item.type, prevLabel);
  if (empty || stillAuto) {
    item.id = suggestItemId(section, item.type, label, empty ? undefined : current);
  }
}

function fillMissingItemIds(section: Section) {
  const used = collectItemIds(section);
  const visit = (items: Item[]) => {
    for (const item of items) {
      if (item.type === "separator") {
        continue;
      }
      if (item.type === "row") {
        visit(item.items);
        continue;
      }
      if (!item.id) {
        item.id = uniqueName(used, idBase(section, item.type, itemLabelOf(item)));
        used.add(item.id);
      }
      if (item.type === "fold") {
        visit(item.items);
      }
    }
  };
  visit(section.items);
}

export function ensureIds(doc: MenuDocument): MenuDocument {
  return draft(doc, (copy) => {
    const used = new Set<string>();
    for (const section of copy.sections) {
      if (!section.id) {
        section.id = uniqueName(used, slugId(section.title || "", "Section"));
      }
      used.add(section.id);
      fillMissingItemIds(section);
    }
  });
}

export function uniqueSectionId(doc: MenuDocument, base: string): string {
  const used = new Set(doc.sections.map((section) => section.id));
  return uniqueName(used, base);
}

export function canAccept(parent: AcceptParent, type: ItemType): boolean {
  if (parent === "section") {
    return true;
  }
  if (parent === "row") {
    return ROW_CHILD_TYPES.has(type);
  }
  return FOLD_CHILD_TYPES.has(type);
}

export function locate(section: Section, path: number[]): { items: Item[]; index: number; item?: Item } {
  if (path.length === 0) {
    return { items: section.items, index: -1 };
  }
  let items: Item[] = section.items;
  for (let depth = 0; depth < path.length - 1; depth += 1) {
    const node = items[path[depth]];
    if (!node || (node.type !== "row" && node.type !== "fold")) {
      return { items, index: path[depth], item: node };
    }
    items = node.items as Item[];
  }
  const index = path[path.length - 1];
  return { items, index, item: items[index] };
}

function parentOfItem(section: Section, path: number[]): AcceptParent {
  if (path.length <= 1) {
    return "section";
  }
  const parent = locate(section, path.slice(0, -1)).item;
  if (parent?.type === "row") {
    return "row";
  }
  if (parent?.type === "fold") {
    return "fold";
  }
  return "section";
}

export function addTarget(doc: MenuDocument, sel: NodeRef | null, type: ItemType): AddTarget | null {
  if (doc.sections.length === 0) {
    return null;
  }
  if (sel === null || sel.kind === "init" || sel.kind === "tab") {
    if (!canAccept("section", type)) {
      return null;
    }
    const sectionIndex = 0;
    return {
      sectionIndex,
      containerPath: [],
      parent: "section",
      insertAt: doc.sections[sectionIndex].items.length,
    };
  }
  if (sel.kind === "section") {
    if (!canAccept("section", type)) {
      return null;
    }
    return {
      sectionIndex: sel.index,
      containerPath: [],
      parent: "section",
      insertAt: doc.sections[sel.index].items.length,
    };
  }
  const section = doc.sections[sel.sectionIndex];
  if (!section) {
    return null;
  }
  const { item } = locate(section, sel.path);
  if (item?.type === "fold" && canAccept("fold", type)) {
    return {
      sectionIndex: sel.sectionIndex,
      containerPath: sel.path,
      parent: "fold",
      insertAt: item.items.length,
    };
  }
  if (item?.type === "row" && canAccept("row", type)) {
    return {
      sectionIndex: sel.sectionIndex,
      containerPath: sel.path,
      parent: "row",
      insertAt: item.items.length,
    };
  }
  const parent = parentOfItem(section, sel.path);
  if (!canAccept(parent, type)) {
    return null;
  }
  return {
    sectionIndex: sel.sectionIndex,
    containerPath: sel.path.slice(0, -1),
    parent,
    insertAt: sel.path[sel.path.length - 1] + 1,
  };
}

export function createItem(type: ItemType, section: Section): Item {
  const used = collectItemIds(section);
  const take = (itemType: ItemType, label: string) => {
    const id = uniqueName(used, idBase(section, itemType, label));
    used.add(id);
    return id;
  };
  if (type === "separator") {
    return { type: "separator" };
  }
  if (type === "label") {
    const label = "Hint text";
    return { type: "label", id: take("label", label), label };
  }
  if (type === "button") {
    const label = "Do thing";
    return { type: "button", id: take("button", label), label };
  }
  if (type === "checkbox") {
    const label = "Enabled";
    return { type: "checkbox", id: take("checkbox", label), label, default: false };
  }
  if (type === "dropdown") {
    const label = "Choice";
    return { type: "dropdown", id: take("dropdown", label), label, options: ["A", "B"], default: "A" };
  }
  if (type === "number") {
    const label = "Count";
    return { type: "number", id: take("number", label), label, default: 1, min: 1, integer: true };
  }
  if (type === "textinput") {
    const label = "Name";
    return { type: "textinput", id: take("textinput", label), label, default: "", placeholder: "Enter name..." };
  }
  if (type === "row") {
    return {
      type: "row",
      items: [
        { type: "number", id: take("number", "Amt"), label: "Amt", default: 1, min: 1, integer: true, labelWidth: 36 },
        { type: "button", id: take("button", "Apply"), label: "Apply" },
      ],
    };
  }
  const foldLabel = "More";
  return {
    type: "fold",
    id: take("fold", foldLabel),
    label: foldLabel,
    collapsed: true,
    items: [{ type: "label", id: take("label", "Fold contents"), label: "Fold contents" }],
  };
}

export function addItem(doc: MenuDocument, sel: NodeRef | null, type: ItemType): { doc: MenuDocument; selection: NodeRef } | null {
  const target = addTarget(doc, sel, type);
  if (!target) {
    return null;
  }
  let selection: NodeRef = { kind: "init" };
  const next = draft(doc, (copy) => {
    const section = copy.sections[target.sectionIndex];
    const item = createItem(type, section);
    const { items } = locate(section, target.containerPath);
    items.splice(target.insertAt, 0, item);
    selection = {
      kind: "item",
      sectionIndex: target.sectionIndex,
      path: [...target.containerPath, target.insertAt],
    };
  });
  return { doc: next, selection };
}

export function addSection(doc: MenuDocument, sel: NodeRef | null): { doc: MenuDocument; selection: NodeRef } {
  let selection: NodeRef = { kind: "init" };
  const next = draft(doc, (copy) => {
    const id = uniqueSectionId(copy, "Section");
    const section: Section = { id, title: id, items: [] };
    if (sel?.kind === "tab") {
      const name = copy.init.tabs?.[sel.index];
      if (name) {
        section.tab = name;
      }
    } else if (copy.init.tabs && copy.init.tabs.length > 0) {
      section.tab = copy.init.tabs[0];
    }
    copy.sections.push(section);
    selection = { kind: "section", index: copy.sections.length - 1 };
  });
  return { doc: next, selection };
}

export function addTab(doc: MenuDocument): { doc: MenuDocument; selection: NodeRef } {
  let selection: NodeRef = { kind: "init" };
  const next = draft(doc, (copy) => {
    const used = new Set(copy.init.tabs ?? []);
    const name = uniqueName(used, "Tab");
    copy.init.tabs = [...(copy.init.tabs ?? []), name];
    selection = { kind: "tab", index: copy.init.tabs.length - 1 };
  });
  return { doc: next, selection };
}

export function renameTab(doc: MenuDocument, index: number, name: string): MenuDocument {
  const trimmed = name.trim();
  if (!trimmed) {
    return doc;
  }
  return draft(doc, (copy) => {
    const tabs = copy.init.tabs;
    if (!tabs || tabs[index] === undefined) {
      return;
    }
    const prev = tabs[index];
    if (tabs.some((tab, i) => i !== index && tab === trimmed)) {
      return;
    }
    tabs[index] = trimmed;
    for (const section of copy.sections) {
      if (section.tab === prev) {
        section.tab = trimmed;
      }
    }
  });
}

export function removeNode(doc: MenuDocument, sel: NodeRef): { doc: MenuDocument; selection: NodeRef } {
  if (sel.kind === "init") {
    return { doc, selection: sel };
  }
  let selection: NodeRef = { kind: "init" };
  const next = draft(doc, (copy) => {
    if (sel.kind === "tab") {
      const tabs = copy.init.tabs;
      if (!tabs) {
        return;
      }
      const name = tabs[sel.index];
      tabs.splice(sel.index, 1);
      for (const section of copy.sections) {
        if (section.tab === name) {
          delete section.tab;
        }
      }
      if (tabs.length === 0) {
        delete copy.init.tabs;
      }
      selection = { kind: "init" };
      return;
    }
    if (sel.kind === "section") {
      copy.sections.splice(sel.index, 1);
      selection = copy.sections.length > 0 ? { kind: "section", index: Math.min(sel.index, copy.sections.length - 1) } : { kind: "init" };
      return;
    }
    const section = copy.sections[sel.sectionIndex];
    if (!section) {
      return;
    }
    const { items, index } = locate(section, sel.path);
    if (index < 0) {
      return;
    }
    items.splice(index, 1);
    if (items.length === 0 && sel.path.length > 0) {
      selection = sel.path.length === 1 ? { kind: "section", index: sel.sectionIndex } : { kind: "item", sectionIndex: sel.sectionIndex, path: sel.path.slice(0, -1) };
      return;
    }
    const nextIndex = Math.min(index, items.length - 1);
    selection =
      nextIndex < 0
        ? { kind: "section", index: sel.sectionIndex }
        : { kind: "item", sectionIndex: sel.sectionIndex, path: [...sel.path.slice(0, -1), nextIndex] };
  });
  return { doc: next, selection };
}

export function moveNode(doc: MenuDocument, sel: NodeRef, delta: -1 | 1): MenuDocument {
  if (sel.kind === "init") {
    return doc;
  }
  return draft(doc, (copy) => {
    if (sel.kind === "tab") {
      const tabs = copy.init.tabs;
      if (!tabs) {
        return;
      }
      const to = sel.index + delta;
      if (to < 0 || to >= tabs.length) {
        return;
      }
      const [tab] = tabs.splice(sel.index, 1);
      tabs.splice(to, 0, tab);
      return;
    }
    if (sel.kind === "section") {
      const to = sel.index + delta;
      if (to < 0 || to >= copy.sections.length) {
        return;
      }
      const [section] = copy.sections.splice(sel.index, 1);
      copy.sections.splice(to, 0, section);
      return;
    }
    const section = copy.sections[sel.sectionIndex];
    if (!section) {
      return;
    }
    const { items, index } = locate(section, sel.path);
    const to = index + delta;
    if (index < 0 || to < 0 || to >= items.length) {
      return;
    }
    const [item] = items.splice(index, 1);
    items.splice(to, 0, item);
  });
}

export function movedRef(sel: NodeRef, delta: -1 | 1): NodeRef {
  if (sel.kind === "tab") {
    return { kind: "tab", index: sel.index + delta };
  }
  if (sel.kind === "section") {
    return { kind: "section", index: sel.index + delta };
  }
  if (sel.kind === "item") {
    const path = sel.path.slice();
    path[path.length - 1] += delta;
    return { kind: "item", sectionIndex: sel.sectionIndex, path };
  }
  return sel;
}

export function canMove(doc: MenuDocument, sel: NodeRef, delta: -1 | 1): boolean {
  if (sel.kind === "init") {
    return false;
  }
  if (sel.kind === "tab") {
    const tabs = doc.init.tabs;
    const to = sel.index + delta;
    return Boolean(tabs && to >= 0 && to < tabs.length);
  }
  if (sel.kind === "section") {
    const to = sel.index + delta;
    return to >= 0 && to < doc.sections.length;
  }
  const section = doc.sections[sel.sectionIndex];
  if (!section) {
    return false;
  }
  const { items, index } = locate(section, sel.path);
  const to = index + delta;
  return index >= 0 && to >= 0 && to < items.length;
}

export function getItem(doc: MenuDocument, sel: Extract<NodeRef, { kind: "item" }>): Item | undefined {
  const section = doc.sections[sel.sectionIndex];
  if (!section) {
    return undefined;
  }
  return locate(section, sel.path).item;
}

export function patchInit(
  doc: MenuDocument,
  patch: Partial<{ title: string; instanceId: string; keyHint: string; dock: DockSide; theme: ThemeName }>,
): MenuDocument {
  return draft(doc, (copy) => {
    Object.assign(copy.init, patch);
  });
}

export function patchSection(doc: MenuDocument, index: number, patch: Partial<Section>): MenuDocument {
  return draft(doc, (copy) => {
    const section = copy.sections[index];
    if (!section) {
      return;
    }
    Object.assign(section, patch);
    if (section.collapsed === true) {
      section.collapsible = true;
    }
    if (section.collapsible !== true) {
      delete section.collapsed;
    }
    if (patch.tab === "") {
      delete section.tab;
    }
    if (!section.id) {
      const used = new Set(copy.sections.filter((other) => other !== section).map((other) => other.id));
      section.id = uniqueName(used, slugId(section.title || "", "Section"));
    }
  });
}

export function patchItem(doc: MenuDocument, sel: Extract<NodeRef, { kind: "item" }>, patch: Record<string, unknown>): MenuDocument {
  return draft(doc, (copy) => {
    const section = copy.sections[sel.sectionIndex];
    if (!section) {
      return;
    }
    const { item } = locate(section, sel.path);
    if (!item) {
      return;
    }
    const prev = structuredClone(item);
    Object.assign(item, patch);
    if ("confirm" in patch && patch.confirm === null) {
      delete (item as { confirm?: unknown }).confirm;
    }
    assignItemId(section, item, prev);
  });
}

export function idCollision(section: Section, id: string, exceptPath: number[]): boolean {
  if (id === "") {
    return false;
  }
  const visit = (items: Item[], path: number[]): boolean => {
    for (let i = 0; i < items.length; i += 1) {
      const here = [...path, i];
      const item = items[i];
      const same = here.length === exceptPath.length && here.every((n, idx) => n === exceptPath[idx]);
      if (!same && "id" in item && item.id === id) {
        return true;
      }
      if (item.type === "row" || item.type === "fold") {
        if (visit(item.items as Item[], here)) {
          return true;
        }
      }
    }
    return false;
  };
  return visit(section.items, []);
}
