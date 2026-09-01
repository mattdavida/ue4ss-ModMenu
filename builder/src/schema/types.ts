export const DOCUMENT_VERSION = 1 as const;

export type ThemeName = "light" | "dark";
export type DockSide = "left" | "right" | "top" | "bottom";

export type ButtonVariant =
  | "default"
  | "primary"
  | "secondary"
  | "success"
  | "danger"
  | "warning"
  | "info"
  | "accent";

export type DropdownOption = string | { label?: string; value?: string };

export type ItemType =
  | "separator"
  | "label"
  | "button"
  | "checkbox"
  | "dropdown"
  | "number"
  | "textinput"
  | "row"
  | "fold";

export type ConfirmSpec = {
  title?: string;
  message?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  variant?: ButtonVariant;
};

export type SeparatorItem = { type: "separator" };

export type LabelItem = { type: "label"; id?: string; label: string };

export type ButtonItem = {
  type: "button";
  id: string;
  label: string;
  variant?: ButtonVariant;
  enabled?: boolean;
  active?: boolean;
  confirm?: ConfirmSpec;
};

export type CheckboxItem = {
  type: "checkbox";
  id: string;
  label: string;
  default?: boolean;
};

export type DropdownItem = {
  type: "dropdown";
  id: string;
  label: string;
  options: DropdownOption[];
  default?: string | null;
  searchable?: boolean;
  placeholder?: string;
  maxVisible?: number;
  listMaxHeight?: number;
  allowEmpty?: boolean;
};

export type NumberItem = {
  type: "number";
  id: string;
  label: string;
  default?: number;
  min?: number;
  max?: number;
  integer?: boolean;
  placeholder?: string;
  fieldWidth?: number;
  labelWidth?: number;
  debounceMs?: number;
};

export type TextInputItem = {
  type: "textinput";
  id: string;
  label: string;
  default?: string;
  placeholder?: string;
  maxLength?: number;
  fieldWidth?: number;
  labelWidth?: number;
  debounceMs?: number;
};

export type RowChild = ButtonItem | CheckboxItem | LabelItem | NumberItem | TextInputItem;

export type RowItem = { type: "row"; items: RowChild[] };

export type FoldChild =
  | ButtonItem
  | CheckboxItem
  | DropdownItem
  | LabelItem
  | NumberItem
  | RowItem
  | SeparatorItem
  | TextInputItem;

export type FoldItem = {
  type: "fold";
  id: string;
  label: string;
  collapsed?: boolean;
  items: FoldChild[];
};

export type Item = SeparatorItem | LabelItem | ButtonItem | CheckboxItem | DropdownItem | NumberItem | TextInputItem | RowItem | FoldItem;

export type Section = {
  id: string;
  title?: string;
  tab?: string;
  collapsible?: boolean;
  collapsed?: boolean;
  items: Item[];
};

export type InitSpec = {
  title: string;
  instanceId: string;
  keyHint: string;
  dock: DockSide;
  theme: ThemeName;
  tabs?: string[];
};

export type MenuDocument = {
  version: typeof DOCUMENT_VERSION;
  init: InitSpec;
  sections: Section[];
};

export type Issue = {
  path: string;
  message: string;
};

export const ROW_CHILD_TYPES: ReadonlySet<ItemType> = new Set([
  "button",
  "checkbox",
  "label",
  "number",
  "textinput",
]);

export const FOLD_CHILD_TYPES: ReadonlySet<ItemType> = new Set([
  "button",
  "checkbox",
  "dropdown",
  "label",
  "number",
  "row",
  "separator",
  "textinput",
]);

export const BUTTON_VARIANTS: ReadonlySet<string> = new Set([
  "default",
  "primary",
  "secondary",
  "success",
  "danger",
  "warning",
  "info",
  "accent",
]);

export const DOCK_SIDES: ReadonlySet<string> = new Set(["left", "right", "top", "bottom"]);
export const THEMES: ReadonlySet<string> = new Set(["light", "dark"]);
export const ITEM_TYPES: ReadonlySet<string> = new Set([
  "separator",
  "label",
  "button",
  "checkbox",
  "dropdown",
  "number",
  "textinput",
  "row",
  "fold",
]);
