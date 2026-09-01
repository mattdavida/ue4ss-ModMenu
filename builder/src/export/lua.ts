import type {
  ButtonItem,
  ConfirmSpec,
  DropdownItem,
  DropdownOption,
  FoldItem,
  Item,
  MenuDocument,
  NumberItem,
  Section,
  TextInputItem,
} from "../schema";
import { ensureIds } from "../editor/model";

function luaString(value: string): string {
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\r/g, "\\r").replace(/\n/g, "\\n")}"`;
}

function indent(level: number): string {
  return "    ".repeat(level);
}

function keyExpr(hint: string): string | null {
  if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(hint)) {
    return `Key.${hint}`;
  }
  return null;
}

function emitOptions(options: DropdownOption[], level: number): string {
  const pad = indent(level);
  const inner = indent(level + 1);
  const rows = options.map((opt) => {
    if (typeof opt === "string") {
      return `${inner}${luaString(opt)},`;
    }
    const label = opt.label;
    const value = opt.value;
    if (label !== undefined && value !== undefined && label !== value) {
      return `${inner}{ label = ${luaString(label)}, value = ${luaString(value)} },`;
    }
    return `${inner}${luaString(label ?? value ?? "")},`;
  });
  return `{\n${rows.join("\n")}\n${pad}}`;
}

function emitConfirm(confirm: ConfirmSpec, level: number): string {
  const pad = indent(level);
  const inner = indent(level + 1);
  const lines = [`${pad}confirm = {`];
  if (confirm.title !== undefined) {
    lines.push(`${inner}title = ${luaString(confirm.title)},`);
  }
  if (confirm.message !== undefined) {
    lines.push(`${inner}message = ${luaString(confirm.message)},`);
  }
  if (confirm.confirmLabel !== undefined) {
    lines.push(`${inner}confirmLabel = ${luaString(confirm.confirmLabel)},`);
  }
  if (confirm.cancelLabel !== undefined) {
    lines.push(`${inner}cancelLabel = ${luaString(confirm.cancelLabel)},`);
  }
  if (confirm.variant !== undefined) {
    lines.push(`${inner}variant = ${luaString(confirm.variant)},`);
  }
  lines.push(`${pad}},`);
  return lines.join("\n");
}

function stubOnChange(sectionId: string, itemId: string, arg: string): string[] {
  return [
    `onChange = function(${arg})`,
    `    -- TODO: game call`,
    `    -- local value = ModMenu.Get(${luaString(sectionId)}, ${luaString(itemId)})`,
    `end,`,
  ];
}

function stubOnClick(sectionId: string, itemId: string): string[] {
  return [
    `onClick = function()`,
    `    -- TODO: game call`,
    `    -- ModMenu.Get(${luaString(sectionId)}, ${luaString(itemId)})`,
    `end,`,
  ];
}

function emitFieldLines(lines: string[], pad: string, fields: Array<[string, string | undefined]>) {
  for (const [key, value] of fields) {
    if (value !== undefined) {
      lines.push(`${pad}${key} = ${value},`);
    }
  }
}

function emitItem(item: Item, sectionId: string, level: number): string {
  const pad = indent(level);
  const inner = indent(level + 1);
  if (item.type === "separator") {
    return `${pad}{ type = "separator" },`;
  }
  if (item.type === "row") {
    const children = item.items.map((child) => emitItem(child, sectionId, level + 2)).join("\n");
    return `${pad}{\n${inner}type = "row",\n${inner}items = {\n${children}\n${inner}},\n${pad}},`;
  }
  if (item.type === "fold") {
    const fold = item as FoldItem;
    const children = fold.items.map((child) => emitItem(child, sectionId, level + 2)).join("\n");
    const lines = [
      `${pad}{`,
      `${inner}type = "fold",`,
      `${inner}id = ${luaString(fold.id)},`,
      `${inner}label = ${luaString(fold.label)},`,
    ];
    if (fold.collapsed !== undefined) {
      lines.push(`${inner}collapsed = ${fold.collapsed ? "true" : "false"},`);
    }
    lines.push(`${inner}items = {`, children, `${inner}},`, `${pad}},`);
    return lines.join("\n");
  }

  const lines = [`${pad}{`, `${inner}type = ${luaString(item.type)},`];
  if ("id" in item && item.id) {
    lines.push(`${inner}id = ${luaString(item.id)},`);
  }
  if ("label" in item) {
    lines.push(`${inner}label = ${luaString(item.label)},`);
  }

  if (item.type === "button") {
    const button = item as ButtonItem;
    emitFieldLines(lines, inner, [
      ["variant", button.variant && button.variant !== "default" ? luaString(button.variant) : undefined],
      ["enabled", button.enabled === false ? "false" : undefined],
      ["active", button.active === true ? "true" : undefined],
    ]);
    if (button.confirm) {
      lines.push(emitConfirm(button.confirm, level + 1));
    }
    for (const stub of stubOnClick(sectionId, button.id)) {
      lines.push(`${inner}${stub}`);
    }
  } else if (item.type === "checkbox") {
    if (item.default !== undefined) {
      lines.push(`${inner}default = ${item.default ? "true" : "false"},`);
    }
    for (const stub of stubOnChange(sectionId, item.id, "on")) {
      lines.push(`${inner}${stub}`);
    }
  } else if (item.type === "dropdown") {
    const drop = item as DropdownItem;
    lines.push(`${inner}options = ${emitOptions(drop.options, level + 1)},`);
    if (drop.default !== undefined && drop.default !== null) {
      lines.push(`${inner}default = ${luaString(drop.default)},`);
    }
    emitFieldLines(lines, inner, [
      ["searchable", drop.searchable === true ? "true" : undefined],
      ["placeholder", drop.placeholder ? luaString(drop.placeholder) : undefined],
      ["maxVisible", drop.maxVisible !== undefined ? String(drop.maxVisible) : undefined],
      ["listMaxHeight", drop.listMaxHeight !== undefined ? String(drop.listMaxHeight) : undefined],
      ["allowEmpty", drop.allowEmpty === true ? "true" : undefined],
    ]);
    for (const stub of stubOnChange(sectionId, drop.id, "value")) {
      lines.push(`${inner}${stub}`);
    }
  } else if (item.type === "number") {
    const num = item as NumberItem;
    emitFieldLines(lines, inner, [
      ["default", num.default !== undefined ? String(num.default) : undefined],
      ["min", num.min !== undefined ? String(num.min) : undefined],
      ["max", num.max !== undefined ? String(num.max) : undefined],
      ["integer", num.integer === true ? "true" : undefined],
      ["placeholder", num.placeholder ? luaString(num.placeholder) : undefined],
      ["fieldWidth", num.fieldWidth !== undefined ? String(num.fieldWidth) : undefined],
      ["labelWidth", num.labelWidth !== undefined ? String(num.labelWidth) : undefined],
    ]);
    for (const stub of stubOnChange(sectionId, num.id, "n")) {
      lines.push(`${inner}${stub}`);
    }
  } else if (item.type === "textinput") {
    const text = item as TextInputItem;
    emitFieldLines(lines, inner, [
      ["default", text.default !== undefined ? luaString(text.default) : undefined],
      ["placeholder", text.placeholder ? luaString(text.placeholder) : undefined],
      ["maxLength", text.maxLength !== undefined ? String(text.maxLength) : undefined],
      ["fieldWidth", text.fieldWidth !== undefined ? String(text.fieldWidth) : undefined],
      ["labelWidth", text.labelWidth !== undefined ? String(text.labelWidth) : undefined],
    ]);
    for (const stub of stubOnChange(sectionId, text.id, "text")) {
      lines.push(`${inner}${stub}`);
    }
  }

  lines.push(`${pad}},`);
  return lines.join("\n");
}

function emitSection(section: Section): string {
  const items = section.items.map((item) => emitItem(item, section.id, 2)).join("\n");
  const lines = [
    `ModMenu.Register({`,
    `    id = ${luaString(section.id)},`,
  ];
  if (section.title !== undefined) {
    lines.push(`    title = ${luaString(section.title)},`);
  }
  if (section.tab) {
    lines.push(`    tab = ${luaString(section.tab)},`);
  }
  if (section.collapsible === true) {
    lines.push(`    collapsible = true,`);
  }
  if (section.collapsed === true) {
    lines.push(`    collapsed = true,`);
  }
  lines.push(`    items = {`, items, `    },`, `})`, ``);
  return lines.join("\n");
}

export function hostFolderName(doc: MenuDocument): string {
  const raw = doc.init.instanceId || doc.init.title || "MyMod";
  const cleaned = raw.replace(/[^A-Za-z0-9_-]+/g, "");
  return cleaned || "MyMod";
}

function bannerRow(text: string, width: number): string {
  const inner = width - 4;
  const clipped = text.length > inner ? text.slice(0, inner) : text;
  return `|  ${clipped.padEnd(inner)}|`;
}

function emitLoadBanner(doc: MenuDocument): string[] {
  const init = doc.init;
  const rows = [`${init.title} Loaded`, `${init.keyHint} = toggle menu`];
  if (init.tabs && init.tabs.length > 0) {
    rows.push(`Tabs: ${init.tabs.join(" / ")}`);
  }
  rows.push(`Dock: ${init.dock}`);
  const width = Math.max(32, ...rows.map((row) => row.length + 4));
  const rule = "-".repeat(width);
  return [rule, ...rows.map((row) => bannerRow(row, width)), rule].map((line) => `print(${luaString(line)})`);
}

export function printLua(document: MenuDocument): string {
  const doc = ensureIds(document);
  const init = doc.init;
  const key = keyExpr(init.keyHint);
  const lines = [
    `--[[`,
    `  Generated by ModMenu Builder.`,
    ``,
    `  Extract the zip into ue4ss/Mods/.`,
    `  Creates ${hostFolderName(doc)}/ (this menu) and shared/ModMenu/ (runtime).`,
    `  Extracting again overwrites shared/ModMenu with the runtime this builder shipped.`,
    ``,
    `  Replace TODO stubs with your game calls.`,
    `  Live lists / chrome: README Dynamic UI (SetOptions, OnOpen, SetButton*).`,
    `]]`,
    ``,
    `local ModMenu = require("ModMenu.ModMenu")`,
    ``,
    `ModMenu.Init({`,
    `    title = ${luaString(init.title)},`,
    `    instanceId = ${luaString(init.instanceId)},`,
  ];
  if (key) {
    lines.push(`    key = ${key},`);
  } else {
    lines.push(`    -- TODO: set key / keyName by hand (keyHint is not a plain Key name)`);
  }
  lines.push(`    keyHint = ${luaString(init.keyHint)},`);
  lines.push(`    dock = ${luaString(init.dock)},`);
  lines.push(`    theme = ${luaString(init.theme)},`);
  if (init.tabs && init.tabs.length > 0) {
    const tabs = init.tabs.map((name) => luaString(name)).join(", ");
    lines.push(`    tabs = { ${tabs} },`);
  }
  lines.push(`})`, ``, ...emitLoadBanner(doc), ``);
  for (const section of doc.sections) {
    lines.push(emitSection(section));
  }
  return lines.join("\n").replace(/\n+$/, "\n");
}
