import {
  BUTTON_VARIANTS,
  DOCK_SIDES,
  DOCUMENT_VERSION,
  FOLD_CHILD_TYPES,
  ITEM_TYPES,
  ROW_CHILD_TYPES,
  THEMES,
} from "./types";
import type {
  ButtonItem,
  ConfirmSpec,
  DropdownOption,
  FoldItem,
  InitSpec,
  Issue,
  Item,
  MenuDocument,
  NumberItem,
  RowItem,
  Section,
  TextInputItem,
} from "./types";

function issue(path: string, message: string): Issue {
  return { path, message };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function requireId(path: string, id: unknown, issues: Issue[]) {
  if (typeof id !== "string" || id === "") {
    issues.push(issue(path, "requires .id"));
  }
}

function requireLabel(path: string, label: unknown, issues: Issue[]) {
  if (typeof label !== "string") {
    issues.push(issue(path, "requires .label"));
  }
}

function checkPositive(path: string, field: string, value: unknown, issues: Issue[]) {
  if (value === undefined) {
    return;
  }
  if (typeof value !== "number" || value < 1) {
    issues.push(issue(path, `${field} must be a positive number`));
  }
}

function checkDebounce(path: string, value: unknown, issues: Issue[]) {
  if (value === undefined) {
    return;
  }
  if (typeof value !== "number" || value < 0) {
    issues.push(issue(path, "debounceMs must be a number >= 0"));
  }
}

function checkVariant(path: string, field: string, value: unknown, issues: Issue[]) {
  if (value === undefined) {
    return;
  }
  if (typeof value !== "string" || !BUTTON_VARIANTS.has(value)) {
    issues.push(issue(path, `${field} must be default|primary|secondary|success|danger|warning|info`));
  }
}

function walkIds(items: unknown[], ids: Map<string, string>, path: string, issues: Issue[]) {
  if (!Array.isArray(items)) {
    return;
  }
  for (let i = 0; i < items.length; i += 1) {
    const item = items[i];
    const itemPath = `${path}[${i}]`;
    if (!isRecord(item)) {
      continue;
    }
    if (typeof item.id === "string" && item.id !== "") {
      const prev = ids.get(item.id);
      if (prev) {
        issues.push(issue(itemPath, `duplicate id '${item.id}' (also ${prev})`));
      } else {
        ids.set(item.id, itemPath);
      }
    }
    if ((item.type === "row" || item.type === "fold") && Array.isArray(item.items)) {
      walkIds(item.items, ids, `${itemPath}.items`, issues);
    }
  }
}

function validateConfirm(path: string, confirm: ConfirmSpec, issues: Issue[]) {
  if (!isRecord(confirm)) {
    issues.push(issue(path, "confirm must be a table"));
    return;
  }
  for (const key of ["title", "message", "confirmLabel", "cancelLabel"] as const) {
    if (confirm[key] !== undefined && typeof confirm[key] !== "string") {
      issues.push(issue(path, `confirm.${key} must be a string`));
    }
  }
  checkVariant(path, "confirm.variant", confirm.variant, issues);
}

function validateDropdownOptions(path: string, options: unknown, issues: Issue[]) {
  if (!Array.isArray(options) || options.length === 0) {
    issues.push(issue(path, "dropdown requires non-empty .options array"));
    return;
  }
  for (let i = 0; i < options.length; i += 1) {
    const opt = options[i] as DropdownOption;
    if (typeof opt === "string") {
      continue;
    }
    if (!isRecord(opt)) {
      issues.push(issue(`${path}.options[${i}]`, "option must be a string or { label, value }"));
      continue;
    }
    if (opt.label === undefined && opt.value === undefined) {
      issues.push(issue(`${path}.options[${i}]`, "dropdown option needs .label or .value"));
    }
  }
}

function validateNumber(path: string, item: NumberItem, issues: Issue[]) {
  requireId(path, item.id, issues);
  requireLabel(path, item.label, issues);
  if (item.min !== undefined && typeof item.min !== "number") {
    issues.push(issue(path, "min must be a number"));
  }
  if (item.max !== undefined && typeof item.max !== "number") {
    issues.push(issue(path, "max must be a number"));
  }
  if (typeof item.min === "number" && typeof item.max === "number" && item.min > item.max) {
    issues.push(issue(path, "min must be <= max"));
  }
  if (item.default !== undefined && typeof item.default !== "number") {
    issues.push(issue(path, "default must be numeric"));
  }
  checkPositive(path, "fieldWidth", item.fieldWidth, issues);
  checkPositive(path, "labelWidth", item.labelWidth, issues);
  checkDebounce(path, item.debounceMs, issues);
}

function validateTextInput(path: string, item: TextInputItem, issues: Issue[]) {
  requireId(path, item.id, issues);
  requireLabel(path, item.label, issues);
  checkPositive(path, "fieldWidth", item.fieldWidth, issues);
  checkPositive(path, "labelWidth", item.labelWidth, issues);
  checkPositive(path, "maxLength", item.maxLength, issues);
  checkDebounce(path, item.debounceMs, issues);
}

function validateButton(path: string, item: ButtonItem, issues: Issue[]) {
  requireId(path, item.id, issues);
  requireLabel(path, item.label, issues);
  if (item.enabled !== undefined && typeof item.enabled !== "boolean") {
    issues.push(issue(path, "enabled must be a boolean"));
  }
  if (item.active !== undefined && typeof item.active !== "boolean") {
    issues.push(issue(path, "active must be a boolean"));
  }
  checkVariant(path, "variant", item.variant, issues);
  if (item.confirm !== undefined) {
    validateConfirm(path, item.confirm, issues);
  }
}

function validateItem(path: string, item: unknown, issues: Issue[]) {
  if (!isRecord(item)) {
    issues.push(issue(path, "must be a table"));
    return;
  }
  const typeName = item.type;
  if (typeof typeName !== "string" || !ITEM_TYPES.has(typeName)) {
    issues.push(issue(path, `unsupported type '${String(typeName)}'`));
    return;
  }

  if (typeName === "separator") {
    return;
  }
  if (typeName === "label") {
    requireLabel(path, item.label, issues);
    return;
  }
  if (typeName === "button") {
    validateButton(path, item as ButtonItem, issues);
    return;
  }
  if (typeName === "checkbox") {
    requireId(path, item.id, issues);
    requireLabel(path, item.label, issues);
    if (item.default !== undefined && typeof item.default !== "boolean") {
      issues.push(issue(path, "default must be a boolean"));
    }
    return;
  }
  if (typeName === "dropdown") {
    requireId(path, item.id, issues);
    requireLabel(path, item.label, issues);
    validateDropdownOptions(path, item.options, issues);
    checkPositive(path, "maxVisible", item.maxVisible, issues);
    return;
  }
  if (typeName === "number") {
    validateNumber(path, item as NumberItem, issues);
    return;
  }
  if (typeName === "textinput") {
    validateTextInput(path, item as TextInputItem, issues);
    return;
  }
  if (typeName === "row") {
    validateRow(path, item as RowItem, issues);
    return;
  }
  if (typeName === "fold") {
    validateFold(path, item as FoldItem, issues);
  }
}

function validateRow(path: string, item: RowItem, issues: Issue[]) {
  if (!Array.isArray(item.items) || item.items.length === 0) {
    issues.push(issue(path, "row requires non-empty .items array"));
    return;
  }
  for (let i = 0; i < item.items.length; i += 1) {
    const child = item.items[i];
    const childPath = `${path}.items[${i}]`;
    if (!isRecord(child)) {
      issues.push(issue(childPath, "must be a table"));
      continue;
    }
    const t = child.type;
    if (typeof t !== "string" || !ROW_CHILD_TYPES.has(t as never)) {
      issues.push(issue(childPath, `unsupported row child type '${String(t)}' (button|checkbox|label|number|textinput)`));
      continue;
    }
    validateItem(childPath, child, issues);
  }
}

function validateFold(path: string, item: FoldItem, issues: Issue[]) {
  requireId(path, item.id, issues);
  requireLabel(path, item.label, issues);
  if (item.collapsed !== undefined && typeof item.collapsed !== "boolean") {
    issues.push(issue(path, "collapsed must be a boolean"));
  }
  if (!Array.isArray(item.items) || item.items.length === 0) {
    issues.push(issue(path, "fold requires non-empty .items array"));
    return;
  }
  for (let i = 0; i < item.items.length; i += 1) {
    const child = item.items[i];
    const childPath = `${path}.items[${i}]`;
    if (!isRecord(child)) {
      issues.push(issue(childPath, "must be a table"));
      continue;
    }
    const t = child.type;
    if (typeof t !== "string" || !FOLD_CHILD_TYPES.has(t as never)) {
      issues.push(issue(childPath, `unsupported fold child type '${String(t)}'`));
      continue;
    }
    validateItem(childPath, child, issues);
  }
}

function validateInit(init: unknown, issues: Issue[]): string[] | undefined {
  if (!isRecord(init)) {
    issues.push(issue("init", "must be a table"));
    return undefined;
  }
  const spec = init as InitSpec;
  if (typeof spec.title !== "string" || spec.title === "") {
    issues.push(issue("init.title", "requires a non-empty string"));
  }
  if (typeof spec.instanceId !== "string" || spec.instanceId === "") {
    issues.push(issue("init.instanceId", "requires a non-empty string"));
  }
  if (typeof spec.keyHint !== "string" || spec.keyHint === "") {
    issues.push(issue("init.keyHint", "requires a non-empty string"));
  }
  if (typeof spec.dock !== "string" || !DOCK_SIDES.has(spec.dock)) {
    issues.push(issue("init.dock", 'must be "left" | "right" | "top" | "bottom"'));
  }
  if (typeof spec.theme !== "string" || !THEMES.has(spec.theme)) {
    issues.push(issue("init.theme", 'must be "light" | "dark"'));
  }
  if (spec.tabs === undefined) {
    return undefined;
  }
  if (!Array.isArray(spec.tabs)) {
    issues.push(issue("init.tabs", "must be an array of strings"));
    return undefined;
  }
  const seen: Record<string, true> = {};
  const out: string[] = [];
  for (let i = 0; i < spec.tabs.length; i += 1) {
    const name = spec.tabs[i];
    if (typeof name !== "string" || name === "") {
      issues.push(issue(`init.tabs[${i}]`, "must be a non-empty string"));
      continue;
    }
    if (seen[name]) {
      issues.push(issue(`init.tabs[${i}]`, `duplicate tab ${name}`));
      continue;
    }
    seen[name] = true;
    out.push(name);
  }
  return out.length > 0 ? out : undefined;
}

function validateSection(index: number, section: unknown, tabs: string[] | undefined, issues: Issue[]) {
  const path = `sections[${index}]`;
  if (!isRecord(section)) {
    issues.push(issue(path, "must be a table"));
    return;
  }
  const spec = section as Section;
  const id = spec.id;
  if (typeof id !== "string" || id === "") {
    issues.push(issue(path, "section requires .id"));
  }
  const sectionPath = typeof id === "string" && id !== "" ? `Register(${id})` : path;
  if (spec.collapsible !== undefined && typeof spec.collapsible !== "boolean") {
    issues.push(issue(sectionPath, "collapsible must be a boolean"));
  }
  if (spec.collapsed !== undefined && typeof spec.collapsed !== "boolean") {
    issues.push(issue(sectionPath, "collapsed must be a boolean"));
  }
  if (spec.collapsed === true && spec.collapsible !== true) {
    issues.push(issue(sectionPath, "collapsed=true requires collapsible=true"));
  }
  if (spec.tab !== undefined && spec.tab !== "") {
    if (typeof spec.tab !== "string") {
      issues.push(issue(sectionPath, "tab must be a string"));
    } else if (tabs && !tabs.includes(spec.tab)) {
      issues.push(issue(sectionPath, `tab ${spec.tab} is not in Init({ tabs = ... })`));
    }
  }
  if (!Array.isArray(spec.items)) {
    issues.push(issue(sectionPath, "requires .items array"));
    return;
  }
  for (let i = 0; i < spec.items.length; i += 1) {
    validateItem(`${sectionPath} items[${i}]`, spec.items[i], issues);
  }
  walkIds(spec.items, new Map(), `${sectionPath} items`, issues);
}

export function validateDocument(doc: unknown): Issue[] {
  const issues: Issue[] = [];
  if (!isRecord(doc)) {
    return [issue("", "document must be a table")];
  }
  if (doc.version !== DOCUMENT_VERSION) {
    issues.push(issue("version", `must be ${DOCUMENT_VERSION}`));
  }
  const tabs = validateInit(doc.init, issues);
  if (!Array.isArray(doc.sections)) {
    issues.push(issue("sections", "requires an array"));
    return issues;
  }
  const seenIds: Record<string, true> = {};
  for (let i = 0; i < doc.sections.length; i += 1) {
    const section = doc.sections[i];
    if (isRecord(section) && typeof section.id === "string" && section.id !== "") {
      if (seenIds[section.id]) {
        issues.push(issue(`sections[${i}]`, `duplicate section id '${section.id}'`));
      }
      seenIds[section.id] = true;
    }
    validateSection(i, section, tabs, issues);
  }
  return issues;
}

export function isValidDocument(doc: unknown): doc is MenuDocument {
  return validateDocument(doc).length === 0;
}

function countInItems(items: Item[]): number {
  let n = 0;
  for (const item of items) {
    n += 1;
    if (item.type === "row" || item.type === "fold") {
      n += countInItems(item.items);
    }
  }
  return n;
}

export function countItems(doc: MenuDocument): number {
  let n = 0;
  for (const section of doc.sections) {
    n += countInItems(section.items);
  }
  return n;
}
